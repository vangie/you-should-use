# you-should-use - Alias reminders & modern command suggestions for Fish
# https://github.com/vangie/you-should-use
# MIT License

# Source user config if it exists (before defaults so user values take priority)
set -l _ysu_config_file (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/ysu/config.fish"
if test -f "$_ysu_config_file"
    source "$_ysu_config_file"
end

# ============================================================================
# Configuration (set these in config.fish BEFORE sourcing)
# ============================================================================

set -q YSU_REMINDER_ENABLED; or set -g YSU_REMINDER_ENABLED true
set -q YSU_SUGGEST_ENABLED; or set -g YSU_SUGGEST_ENABLED true
set -q YSU_LLM_ENABLED; or set -g YSU_LLM_ENABLED false
set -q YSU_PREFIX; or set -g YSU_PREFIX "💡"
set -q YSU_REMINDER_PREFIX; or set -g YSU_REMINDER_PREFIX ""
set -q YSU_SUGGEST_PREFIX; or set -g YSU_SUGGEST_PREFIX ""
set -q YSU_LLM_PREFIX; or set -g YSU_LLM_PREFIX "🤖"
set -q YSU_PROBABILITY; or set -g YSU_PROBABILITY 100
set -q YSU_COOLDOWN; or set -g YSU_COOLDOWN 0
set -q YSU_IGNORE_ALIASES; or set -g YSU_IGNORE_ALIASES
set -q YSU_IGNORE_COMMANDS; or set -g YSU_IGNORE_COMMANDS
set -q YSU_LLM_API_URL; or set -g YSU_LLM_API_URL "http://localhost:11434/v1/chat/completions"
set -q YSU_LLM_API_KEY; or set -g YSU_LLM_API_KEY ""
set -q YSU_LLM_MODEL; or set -g YSU_LLM_MODEL "qwen2.5-coder:7b"
set -q YSU_LLM_CACHE_DIR; or set -g YSU_LLM_CACHE_DIR "$HOME/.cache/ysu"

# ============================================================================
# Ollama auto-detection (runs once at plugin load, not every command)
# ============================================================================

if not set -q _YSU_OLLAMA_CHECKED
    set -g _YSU_OLLAMA_CHECKED 1
    # Only auto-detect if user hasn't explicitly configured LLM
    if test "$YSU_LLM_ENABLED" = false
        set -l _ysu_user_set_llm false
        set -l _ysu_cfg (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/ysu/config.fish"
        if test -f "$_ysu_cfg"
            grep -q 'YSU_LLM_ENABLED' "$_ysu_cfg" 2>/dev/null; and set _ysu_user_set_llm true
        end
        if test "$_ysu_user_set_llm" = false
            # Probe Ollama at default port (quick timeout)
            if curl -s --max-time 1 "http://localhost:11434/api/tags" >/dev/null 2>&1
                # Ollama is running — check if default model is available
                set -l _ysu_ollama_tags (curl -s --max-time 2 "http://localhost:11434/api/tags" 2>/dev/null)
                if echo "$_ysu_ollama_tags" | grep -q "\"$YSU_LLM_MODEL\"" 2>/dev/null
                    set -g YSU_LLM_ENABLED true
                end
            end
        end
    end
end

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
set -g _YSU_LLM_PENDING_CMD ""
set -g _YSU_LLM_ASYNC_FILE ""
set -g _YSU_LLM_ASYNC_CMD ""
set -g _YSU_PROMO_SHOWN_TODAY 0
set -g _YSU_PROMO_DATE ""

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

    # Strip sudo prefix (defense-in-depth, same as _ysu_on_preexec)
    if string match -qr '^sudo( |$)' -- $typed_command
        set typed_command (string replace -r '^sudo ?' '' -- $typed_command)
    end
    test -n "$typed_command"; or return

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
            "You should use \e[1;31m$found_alias\e[0m instead of \e[1;36m$found_value\e[0m"
        _ysu_record_tip
    end
end

# ============================================================================
# Feature 2: Modern Command Suggestions
# ============================================================================

function _ysu_check_modern
    test "$YSU_SUGGEST_ENABLED" = true; or return

    set -l typed_command $argv[1]

    # Strip sudo prefix (defense-in-depth, same as _ysu_on_preexec)
    if string match -qr '^sudo( |$)' -- $typed_command
        set typed_command (string replace -r '^sudo ?' '' -- $typed_command)
    end
    test -n "$typed_command"; or return

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
                "You should use \e[1;31m$modern_cmd\e[0m instead of \e[1;36m$first_word\e[0m — \e[3m$description\e[0m"
            _ysu_record_tip
            return
        end
    end
end

# ============================================================================
# Feature 3: Sudo alias suggestion (priority 2 — only when inner command has no suggestion)
# ============================================================================

function _ysu_check_sudo_alias
    set -l inner_command $argv[1]

    # Check abbreviations for sudo
    for abbr_line in (abbr --show 2>/dev/null)
        set -l parts (string match -r -- '^abbr -a.*-- (\S+) (.+)$' $abbr_line)
        if test (count $parts) -ge 3
            set -l abbr_name $parts[2]
            set -l abbr_value (string trim -c "'" -- $parts[3])
            _ysu_is_ignored_alias $abbr_name; and continue
            # Match abbreviations whose value is "sudo" or "sudo "
            if test "$abbr_value" = sudo -o "$abbr_value" = "sudo "
                _ysu_print "$YSU_REMINDER_PREFIX" \
                    "You should use \e[1;31m$abbr_name $inner_command\e[0m instead of \e[1;36msudo $inner_command\e[0m"
                _ysu_record_tip
                return
            end
        end
    end

    # Check alias functions for sudo
    for func_name in (functions --names)
        string match -q '_*' -- $func_name; and continue
        set -l func_body (functions $func_name 2>/dev/null | string collect)
        set -l wrapped (string match -r -- "^\s+command\s+(\S+)" $func_body)
        if test (count $wrapped) -ge 2
            _ysu_is_ignored_alias $func_name; and continue
            if test "$wrapped[2]" = sudo
                _ysu_print "$YSU_REMINDER_PREFIX" \
                    "You should use \e[1;31m$func_name $inner_command\e[0m instead of \e[1;36msudo $inner_command\e[0m"
                _ysu_record_tip
                return
            end
        end
    end
end

# ============================================================================
# Feature 4: LLM-powered suggestions (async + cached)
# ============================================================================

function _ysu_llm_cache_key
    if command -q md5
        echo -n "$argv[1]" | md5
    else if command -q md5sum
        echo -n "$argv[1]" | md5sum | string split -m1 ' '[1]
    else
        echo -n "$argv[1]" | cksum | string split -m1 ' '[1]
    end
end

function _ysu_llm_should_trigger
    set -l cmd $argv[1]
    set -l exit_code $argv[2]

    # Trigger on non-zero exit
    test "$exit_code" -ne 0; and return 0

    # Trigger on pipes or redirects
    string match -q '*|*' -- $cmd; and return 0
    string match -qr '[<>]' -- $cmd; and return 0

    # Trigger on complex args (command + 3 or more arguments)
    set -l words (string split ' ' -- $cmd)
    test (count $words) -ge 4; and return 0

    return 1
end

function _ysu_llm_json_escape
    string replace -a '\\' '\\\\' -- $argv[1] \
        | string replace -a '"' '\\"' \
        | string replace -a \n '\\n' \
        | string replace -a \t '\\t' \
        | string replace -a \r '\\r'
end

function _ysu_llm_extract_content
    set -l json $argv[1]
    if command -q jq
        echo $json | jq -r '.choices[0].message.content // empty' 2>/dev/null
    else if command -q python3
        echo $json | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    print(r['choices'][0]['message']['content'])
except: pass
" 2>/dev/null
    else
        # Simple fallback
        echo $json | string match -r '"content"\s*:\s*"([^"]*)"' | tail -1
    end
end

function _ysu_llm_query_async
    set -l cmd $argv[1]

    # Clean up any previous pending request
    if test -n "$_YSU_LLM_ASYNC_FILE"
        rm -f "$_YSU_LLM_ASYNC_FILE" "$_YSU_LLM_ASYNC_FILE.done" 2>/dev/null
    end

    mkdir -p "$YSU_LLM_CACHE_DIR"
    set -g _YSU_LLM_ASYNC_FILE (mktemp "$YSU_LLM_CACHE_DIR/.pending.XXXXXX")
    set -g _YSU_LLM_ASYNC_CMD "$cmd"

    set -l escaped_cmd (_ysu_llm_json_escape "$cmd")
    set -l system_prompt "You are a shell expert. Given a shell command, suggest a better alternative or optimization in one brief sentence. If there is no improvement, reply with exactly: none"
    set -l payload "{\"model\":\"$YSU_LLM_MODEL\",\"messages\":[{\"role\":\"system\",\"content\":\"$system_prompt\"},{\"role\":\"user\",\"content\":\"$escaped_cmd\"}],\"max_tokens\":100,\"temperature\":0.3}"

    set -l tmp_file $_YSU_LLM_ASYNC_FILE
    set -l api_url $YSU_LLM_API_URL
    set -l api_key $YSU_LLM_API_KEY
    set -l cache_dir $YSU_LLM_CACHE_DIR

    fish -c "
        set -l auth_args
        test -n '$api_key'; and set auth_args -H 'Authorization: Bearer $api_key'

        set -l response (curl -s --max-time 10 \
            -H 'Content-Type: application/json' \
            \$auth_args \
            -d '$payload' \
            '$api_url' 2>/dev/null; or true)

        set -l content ''
        if test -n \"\$response\"
            if command -q jq
                set content (echo \$response | jq -r '.choices[0].message.content // empty' 2>/dev/null)
            else if command -q python3
                set content (echo \$response | python3 -c \"
import sys, json
try:
    r = json.load(sys.stdin)
    print(r['choices'][0]['message']['content'])
except: pass
\" 2>/dev/null)
            end
        end

        set content (string trim -- \$content)
        if test -n \"\$content\"; and test \"\$content\" != none; and test \"\$content\" != 'none.'
            echo \$content > '$tmp_file'
        else
            echo -n > '$tmp_file'
        end
        touch '$tmp_file.done'
    " &
    disown 2>/dev/null
end

function _ysu_llm_check_async
    test -n "$_YSU_LLM_ASYNC_FILE"; or return

    # Check if background process finished
    test -f "$_YSU_LLM_ASYNC_FILE.done"; or return

    # Read result
    set -l result ""
    if test -s "$_YSU_LLM_ASYNC_FILE"
        set result (cat "$_YSU_LLM_ASYNC_FILE")
    end

    # Cache the result
    set -l cache_key (_ysu_llm_cache_key "$_YSU_LLM_ASYNC_CMD")
    set -l cache_file "$YSU_LLM_CACHE_DIR/$cache_key"
    if test -n "$result"
        echo $result > "$cache_file"
        _ysu_print "$YSU_LLM_PREFIX" "$result"
    else
        echo -n > "$cache_file"
    end

    # Cleanup
    rm -f "$_YSU_LLM_ASYNC_FILE" "$_YSU_LLM_ASYNC_FILE.done" 2>/dev/null
    set -g _YSU_LLM_ASYNC_FILE ""
    set -g _YSU_LLM_ASYNC_CMD ""
end

# ============================================================================
# Feature 5: LLM configuration promo (low-frequency reminder)
# ============================================================================

function _ysu_maybe_show_promo
    # Only show when LLM is disabled
    test "$YSU_LLM_ENABLED" = false; or return

    # Rate limit: max 3 per day using cache file
    set -l cache_dir "$YSU_LLM_CACHE_DIR"
    test -n "$cache_dir"; or set cache_dir "$HOME/.cache/ysu"
    mkdir -p "$cache_dir"
    set -l promo_file "$cache_dir/.promo_count"
    set -l today (date +%Y-%m-%d)

    # Reset counter on new day
    if test "$_YSU_PROMO_DATE" != "$today"
        set -g _YSU_PROMO_DATE "$today"
        set -g _YSU_PROMO_SHOWN_TODAY 0
        # Check persistent file
        if test -f "$promo_file"
            set -l saved_date (head -1 "$promo_file" 2>/dev/null)
            set -l saved_count (tail -1 "$promo_file" 2>/dev/null)
            if test "$saved_date" = "$today"
                set -g _YSU_PROMO_SHOWN_TODAY (math "$saved_count + 0")
            end
        end
    end

    test "$_YSU_PROMO_SHOWN_TODAY" -ge 3; and return

    # Show the promo
    set -g _YSU_PROMO_SHOWN_TODAY (math "$_YSU_PROMO_SHOWN_TODAY + 1")
    printf '%s\n%s\n' "$today" "$_YSU_PROMO_SHOWN_TODAY" > "$promo_file"
    _ysu_print "" "Enable AI-powered suggestions! Run \e[1;33mysu config\e[0m to set up."
end

# ============================================================================
# Hooks
# ============================================================================

function _ysu_on_preexec --on-event fish_preexec
    set -l typed_command (string trim -- $argv[1])
    test -n "$typed_command"; or return

    # Save full command for LLM evaluation in postexec
    set -g _YSU_LLM_PENDING_CMD "$typed_command"

    # Strip sudo prefix for matching — check the actual command, not sudo itself
    set -l check_command $typed_command
    set -l _ysu_has_sudo false
    if string match -qr '^sudo( |$)' -- $check_command
        set check_command (string replace -r '^sudo ?' '' -- $check_command)
        set _ysu_has_sudo true
    end

    # Skip if only sudo with no actual command
    test -n "$check_command"; or return

    _ysu_should_show; or return

    # Three-tier priority for sudo commands:
    # Priority 1: Inner command has a suggestion (alias reminder or modern tool)
    # Priority 2: No inner suggestion, but sudo has an alias → suggest that
    # Priority 3: Neither → no suggestion
    set -l tip_time_before $_YSU_LAST_TIP_TIME
    _ysu_check_aliases $check_command
    _ysu_check_modern $check_command

    # Priority 2: suggest sudo alias only when inner command had no suggestions
    if test "$_ysu_has_sudo" = true -a "$_YSU_LAST_TIP_TIME" = "$tip_time_before"
        _ysu_check_sudo_alias $check_command
    end

    # Track whether any tips were shown for this command (for promo gating)
    if test "$_YSU_LAST_TIP_TIME" = "$tip_time_before"
        set -g _YSU_CMD_HAD_TIPS false
    else
        set -g _YSU_CMD_HAD_TIPS true
    end
end

function _ysu_on_postexec --on-event fish_postexec
    set -l last_exit $status

    # LLM: display completed async result from previous command
    if test "$YSU_LLM_ENABLED" = true
        _ysu_llm_check_async
    end

    # LLM: evaluate triggers for the just-finished command
    if test "$YSU_LLM_ENABLED" = true; and test -n "$_YSU_LLM_PENDING_CMD"
        if _ysu_llm_should_trigger "$_YSU_LLM_PENDING_CMD" "$last_exit"
            set -l cache_key (_ysu_llm_cache_key "$_YSU_LLM_PENDING_CMD")
            set -l cache_file "$YSU_LLM_CACHE_DIR/$cache_key"

            if test -f "$cache_file"
                # Cache hit
                if test -s "$cache_file"
                    set -l cached (cat "$cache_file")
                    test -n "$cached"; and _ysu_print "$YSU_LLM_PREFIX" "$cached"
                end
            else
                # Cache miss — fire async request
                _ysu_llm_query_async "$_YSU_LLM_PENDING_CMD"
            end
        end
        set -g _YSU_LLM_PENDING_CMD ""
    end

    # Show LLM promo when no tips were shown for this command
    if test "$_YSU_CMD_HAD_TIPS" = false
        _ysu_maybe_show_promo
    end
end

# ============================================================================
# Interactive configuration: ysu command
# ============================================================================

function ysu
    switch $argv[1]
        case config
            _ysu_config_wizard
        case cache
            switch $argv[2]
                case clear
                    rm -f "$YSU_LLM_CACHE_DIR"/* 2>/dev/null
                    rm -f "$YSU_LLM_CACHE_DIR"/.pending.* 2>/dev/null
                    echo "LLM cache cleared."
                case size
                    set -l count (find "$YSU_LLM_CACHE_DIR" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | string trim)
                    echo "$count cached suggestions"
                case '*'
                    echo "Usage: ysu cache [clear|size]"
            end
        case '*'
            echo "Usage: ysu <command>"
            echo "Commands:"
            echo "  config    Configure you-should-use interactively"
            echo "  cache     Manage LLM suggestion cache"
    end
end

function _ysu_config_wizard
    set -l config_dir (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/ysu"
    set -l config_file "$config_dir/config.fish"

    while true
        echo ""
        echo -e "\e[1mYou Should Use — Configuration\e[0m"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "  1) Alias Reminders:       "(test "$YSU_REMINDER_ENABLED" = true; and echo -e "\e[32m✓ enabled\e[0m"; or echo -e "\e[31m✗ disabled\e[0m")
        echo -e "  2) Modern Suggestions:    "(test "$YSU_SUGGEST_ENABLED" = true; and echo -e "\e[32m✓ enabled\e[0m"; or echo -e "\e[31m✗ disabled\e[0m")
        echo -e "  3) LLM Suggestions:       "(test "$YSU_LLM_ENABLED" = true; and echo -e "\e[32m✓ enabled\e[0m"; or echo -e "\e[31m✗ disabled\e[0m")
        echo "  4) Tip Probability:       $YSU_PROBABILITY%"
        echo "  5) Cooldown:              ${YSU_COOLDOWN}s"
        echo "  6) LLM Settings           →"
        echo ""
        read -P "  Select (1-6, s=save, q=quit): " choice

        switch $choice
            case 1
                test "$YSU_REMINDER_ENABLED" = true; and set -g YSU_REMINDER_ENABLED false; or set -g YSU_REMINDER_ENABLED true
            case 2
                test "$YSU_SUGGEST_ENABLED" = true; and set -g YSU_SUGGEST_ENABLED false; or set -g YSU_SUGGEST_ENABLED true
            case 3
                test "$YSU_LLM_ENABLED" = true; and set -g YSU_LLM_ENABLED false; or set -g YSU_LLM_ENABLED true
            case 4
                read -P "  Probability (1-100): " YSU_PROBABILITY
            case 5
                read -P "  Cooldown (seconds): " YSU_COOLDOWN
            case 6
                _ysu_config_llm
            case s S
                _ysu_config_save "$config_dir" "$config_file"
            case q Q
                echo "  Settings applied to current session."
                return
        end
    end
end

function _ysu_config_llm
    while true
        echo ""
        echo -e "\e[1mLLM Settings\e[0m"
        echo "━━━━━━━━━━━━"
        echo "  a) API URL:   $YSU_LLM_API_URL"
        echo -e "  b) API Key:   "(test -n "$YSU_LLM_API_KEY"; and echo "••••"(string sub -s -4 -- "$YSU_LLM_API_KEY"); or echo "(not set)")
        echo "  c) Model:     $YSU_LLM_MODEL"
        echo ""
        read -P "  Select (a-c, q=back): " choice

        switch $choice
            case a
                read -P "  API URL: " YSU_LLM_API_URL
            case b
                read -P "  API Key: " YSU_LLM_API_KEY
            case c
                read -P "  Model: " YSU_LLM_MODEL
            case q Q
                return
        end
    end
end

function _ysu_config_save
    set -l config_dir $argv[1]
    set -l config_file $argv[2]
    mkdir -p "$config_dir"
    echo "# You Should Use — Configuration (generated by ysu config)
set -g YSU_REMINDER_ENABLED $YSU_REMINDER_ENABLED
set -g YSU_SUGGEST_ENABLED $YSU_SUGGEST_ENABLED
set -g YSU_LLM_ENABLED $YSU_LLM_ENABLED
set -g YSU_PROBABILITY $YSU_PROBABILITY
set -g YSU_COOLDOWN $YSU_COOLDOWN
set -g YSU_LLM_API_URL \"$YSU_LLM_API_URL\"
set -g YSU_LLM_API_KEY \"$YSU_LLM_API_KEY\"
set -g YSU_LLM_MODEL \"$YSU_LLM_MODEL\"" > "$config_file"
    echo "  Saved to $config_file"
end
