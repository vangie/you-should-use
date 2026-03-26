# you-should-use - Alias reminders & modern command suggestions for Fish
# https://github.com/vangie/you-should-use
# MIT License

# ============================================================================
# Configuration (set these in config.fish BEFORE sourcing)
# ============================================================================

set -q YSU_REMINDER_ENABLED; or set -g YSU_REMINDER_ENABLED true
set -q YSU_SUGGEST_ENABLED; or set -g YSU_SUGGEST_ENABLED true
set -q YSU_PREFIX; or set -g YSU_PREFIX "💡"
set -q YSU_REMINDER_PREFIX; or set -g YSU_REMINDER_PREFIX ""
set -q YSU_SUGGEST_PREFIX; or set -g YSU_SUGGEST_PREFIX ""
set -q YSU_PROBABILITY; or set -g YSU_PROBABILITY 100
set -q YSU_COOLDOWN; or set -g YSU_COOLDOWN 0
set -q YSU_IGNORE_ALIASES; or set -g YSU_IGNORE_ALIASES
set -q YSU_IGNORE_COMMANDS; or set -g YSU_IGNORE_COMMANDS

# ============================================================================
# Modern command alternatives mapping (parallel lists)
# ============================================================================
# Format: YSU_MODERN_KEYS[i] = legacy command
#         YSU_MODERN_VALS[i] = "alt1:desc|alt2:desc"

if not set -q YSU_MODERN_KEYS
    set -g YSU_MODERN_KEYS \
        cat ls find grep du top ps diff sed curl ping dig man cd df xxd make wget time history
    set -g YSU_MODERN_VALS \
        "bat:Syntax highlighting, line numbers, git integration" \
        "eza:Modern file listing with icons, git status, tree view|lsd:LSDeluxe - colorful ls with icons" \
        "fd:Simpler syntax, faster, respects .gitignore" \
        "rg:Ripgrep - faster, respects .gitignore, better defaults|ag:The Silver Searcher - fast code search" \
        "dust:Intuitive disk usage with visual chart|ncdu:NCurses disk usage analyzer" \
        "btop:Beautiful resource monitor with mouse support|htop:Interactive process viewer" \
        "procs:Modern process viewer with tree display" \
        "delta:Syntax highlighting, side-by-side view, git integration|colordiff:Colorized diff output" \
        "sd:Simpler syntax, uses regex by default" \
        "httpie:Human-friendly HTTP client (command: http)|curlie:Curl with httpie-like interface" \
        "gping:Ping with a graph" \
        "dog:DNS client with colorful output" \
        "tldr:Simplified, community-driven man pages" \
        "zoxide:Smarter cd that learns your habits (command: z)" \
        "duf:Disk usage with colorful output and device overview" \
        "hexyl:Colorful hex viewer with modern UI" \
        "just:Simpler command runner, no tabs required" \
        "xh:Fast, friendly HTTP client (like httpie but faster)" \
        "hyperfine:Benchmarking tool with statistical analysis" \
        "mcfly:Intelligent shell history search with neural network|atuin:Magical shell history with sync"
end

# ============================================================================
# Internal state
# ============================================================================

set -g _YSU_LAST_TIP_TIME 0

# ============================================================================
# Helper functions
# ============================================================================

function _ysu_print
    set -l prefix "$YSU_PREFIX"
    if test -n "$argv[1]"
        set prefix "$prefix$argv[1]"
    end
    set -l msg "$argv[2]"
    echo -e "$prefix \e[1;93m➜\e[0m $msg\e[0m"
end

function _ysu_should_show
    # Check cooldown
    if test "$YSU_COOLDOWN" -gt 0
        set -l now (date +%s)
        set -l elapsed (math "$now - $_YSU_LAST_TIP_TIME")
        if test "$elapsed" -lt "$YSU_COOLDOWN"
            return 1
        end
    end
    # Check probability
    if test "$YSU_PROBABILITY" -lt 100
        set -l rand (random 1 100)
        if test "$rand" -gt "$YSU_PROBABILITY"
            return 1
        end
    end
    return 0
end

function _ysu_record_tip
    set -g _YSU_LAST_TIP_TIME (date +%s)
end

function _ysu_is_ignored_alias
    for ignored in $YSU_IGNORE_ALIASES
        if test "$ignored" = "$argv[1]"
            return 0
        end
    end
    return 1
end

function _ysu_is_ignored_command
    for ignored in $YSU_IGNORE_COMMANDS
        if test "$ignored" = "$argv[1]"
            return 0
        end
    end
    return 1
end

# ============================================================================
# Feature 1: Alias Reminders (Fish abbreviations and functions)
# ============================================================================

function _ysu_check_aliases
    test "$YSU_REMINDER_ENABLED" = true; or return

    set -l typed_command $argv[1]
    set -l first_word (string split -m1 ' ' -- $typed_command)[1]
    set -l found_alias ""
    set -l found_value ""

    # Check Fish abbreviations
    for abbr_line in (abbr --show 2>/dev/null)
        # abbr --show outputs: abbr -a -- name 'expansion'
        set -l parts (string match -r -- '^abbr -a.*-- (\S+) (.+)$' $abbr_line)
        if test (count $parts) -ge 3
            set -l abbr_name $parts[2]
            set -l abbr_value (string trim -c "'" -- $parts[3])

            _ysu_is_ignored_alias $abbr_name; and continue
            test "$first_word" = "$abbr_name"; and continue

            if string match -q -- "$abbr_value*" $typed_command
                if test -z "$found_value" -o (string length -- $abbr_value) -gt (string length -- "$found_value")
                    set found_alias $abbr_name
                    set found_value $abbr_value
                end
            end
        end
    end

    # Check Fish alias functions (created via `alias` command)
    for func_name in (functions --names)
        # Skip private/internal functions
        string match -q '_*' -- $func_name; and continue

        set -l func_body (functions $func_name 2>/dev/null | string collect)
        # Fish aliases create wrapper functions with pattern: command <original> ...
        set -l wrapped (string match -r -- "^\s+command\s+(\S+)" $func_body)
        if test (count $wrapped) -ge 2
            set -l alias_target $wrapped[2]
            _ysu_is_ignored_alias $func_name; and continue
            test "$first_word" = "$func_name"; and continue

            if test "$first_word" = "$alias_target"
                if test -z "$found_value" -o (string length -- $alias_target) -gt (string length -- "$found_value")
                    set found_alias $func_name
                    set found_value $alias_target
                end
            end
        end
    end

    if test -n "$found_alias"
        _ysu_print "$YSU_REMINDER_PREFIX" \
            "You should use \e[1;4;31m$found_alias\e[0m instead of \e[1;4;36m$found_value\e[0m"
        _ysu_record_tip
    end
end

# ============================================================================
# Feature 2: Modern Command Suggestions
# ============================================================================

function _ysu_check_modern
    test "$YSU_SUGGEST_ENABLED" = true; or return

    set -l typed_command $argv[1]
    set -l first_word (string split -m1 ' ' -- $typed_command)[1]

    _ysu_is_ignored_command $first_word; and return

    # Find the command in our mapping
    set -l idx 0
    for i in (seq (count $YSU_MODERN_KEYS))
        if test "$YSU_MODERN_KEYS[$i]" = "$first_word"
            set idx $i
            break
        end
    end
    test "$idx" -eq 0; and return

    set -l mapping $YSU_MODERN_VALS[$idx]

    # Support multiple alternatives separated by |
    for entry in (string split '|' -- $mapping)
        set -l modern_cmd (string split -m1 ':' -- $entry)[1]
        set -l description (string split -m1 ':' -- $entry)[2]

        if command -q $modern_cmd
            # Skip if first_word is already aliased/abbreviated to this modern command
            set -l _skip false
            # Check abbreviations
            for _abbr_line in (abbr --show 2>/dev/null)
                set -l _parts (string match -r -- '^abbr -a.*-- (\S+) (.+)$' $_abbr_line)
                if test (count $_parts) -ge 3; and test "$_parts[2]" = "$first_word"
                    set -l _abbr_val (string trim -c "'" -- $_parts[3])
                    if test (string split -m1 ' ' -- $_abbr_val)[1] = "$modern_cmd"
                        set _skip true
                        break
                    end
                end
            end
            # Check alias functions
            if test "$_skip" = false
                set -l _fbody (functions $first_word 2>/dev/null | string collect)
                set -l _wrapped (string match -r -- "^\s+command\s+(\S+)" $_fbody)
                if test (count $_wrapped) -ge 2; and test "$_wrapped[2]" = "$modern_cmd"
                    set _skip true
                end
            end
            test "$_skip" = true; and return

            _ysu_print "$YSU_SUGGEST_PREFIX" \
                "You should use \e[1;4;31m$modern_cmd\e[0m instead of \e[1;4;36m$first_word\e[0m — \e[3m$description\e[0m"
            _ysu_record_tip
            return
        end
    end
end

# ============================================================================
# Hook: fish_preexec event
# ============================================================================

function _ysu_on_preexec --on-event fish_preexec
    set -l typed_command $argv[1]
    test -n "$typed_command"; or return

    # Strip sudo prefix for matching
    set -l check_command $typed_command
    if string match -q 'sudo *' -- $check_command
        set check_command (string replace -r '^sudo ' '' -- $check_command)
    end

    _ysu_should_show; or return

    _ysu_check_aliases $check_command
    _ysu_check_modern $check_command
end
