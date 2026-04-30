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

set -q YSU_DISABLED; or set -g YSU_DISABLED false
set -q YSU_REMINDER_ENABLED; or set -g YSU_REMINDER_ENABLED true
set -q YSU_SUGGEST_ENABLED; or set -g YSU_SUGGEST_ENABLED true
set -q YSU_LLM_ENABLED; or set -g YSU_LLM_ENABLED false
set -q YSU_PREFIX; or set -g YSU_PREFIX "💡"
set -q YSU_REMINDER_PREFIX; or set -g YSU_REMINDER_PREFIX ""
set -q YSU_SUGGEST_PREFIX; or set -g YSU_SUGGEST_PREFIX ""
set -q YSU_LLM_PREFIX; or set -g YSU_LLM_PREFIX "🤖"
set -q YSU_PROBABILITY; or set -g YSU_PROBABILITY 100
set -q YSU_REMINDER_HALFLIFE; or set -g YSU_REMINDER_HALFLIFE 300
set -q YSU_COOLDOWN; or set -g YSU_COOLDOWN 0
set -q YSU_IGNORE_ALIASES; or set -g YSU_IGNORE_ALIASES
set -q YSU_IGNORE_COMMANDS; or set -g YSU_IGNORE_COMMANDS
set -q YSU_IGNORE_SUGGESTIONS; or set -g YSU_IGNORE_SUGGESTIONS
set -q YSU_LLM_API_URL; or set -g YSU_LLM_API_URL "http://localhost:11434/v1/chat/completions"
set -q YSU_LLM_API_KEY; or set -g YSU_LLM_API_KEY ""
set -q YSU_LLM_MODEL; or set -g YSU_LLM_MODEL "auto"
set -q YSU_LLM_CACHE_DIR; or set -g YSU_LLM_CACHE_DIR "$HOME/.cache/ysu"
set -q YSU_LLM_MODE; or set -g YSU_LLM_MODE "single"
set -q YSU_LLM_WINDOW_SIZE; or set -g YSU_LLM_WINDOW_SIZE 5
set -q YSU_INSTALL_HINT; or set -g YSU_INSTALL_HINT true
set -q YSU_AUTO_DECAY_THRESHOLD; or set -g YSU_AUTO_DECAY_THRESHOLD 10
set -q YSU_MESSAGE_FORMAT; or set -g YSU_MESSAGE_FORMAT "{prefix} {arrow} {message}"

# Theme settings
set -q YSU_THEME; or set -g YSU_THEME "dark"
set -q YSU_DARK_THEME; or set -g YSU_DARK_THEME "tokyo-night"
set -q YSU_LIGHT_THEME; or set -g YSU_LIGHT_THEME "solarized"

# Available themes (dark: tokyo-night, dracula, monokai, catppuccin-mocha)
#                  (light: solarized, catppuccin-latte, github)
function _ysu_init_colors
    set -l theme_name
    if test "$YSU_THEME" = "light"
        set theme_name "$YSU_LIGHT_THEME"
    else
        set theme_name "$YSU_DARK_THEME"
    end

    set -l arrow; set -l highlight; set -l command; set -l dim; set -l hint; set -l ok; set -l err; set -l bold
    switch "$theme_name"
        case tokyo-night
            set arrow '\e[1;93m'; set highlight '\e[1;31m'; set command '\e[1;36m'; set dim '\e[3m'; set hint '\e[1;33m'; set ok '\e[32m'; set err '\e[31m'; set bold '\e[1m'
        case dracula
            set arrow '\e[38;5;141m'; set highlight '\e[1;38;5;212m'; set command '\e[38;5;117m'; set dim '\e[3;38;5;103m'; set hint '\e[38;5;84m'; set ok '\e[32m'; set err '\e[31m'; set bold '\e[1m'
        case monokai
            set arrow '\e[38;5;208m'; set highlight '\e[1;38;5;197m'; set command '\e[38;5;148m'; set dim '\e[3;38;5;242m'; set hint '\e[38;5;186m'; set ok '\e[32m'; set err '\e[31m'; set bold '\e[1m'
        case catppuccin-mocha
            set arrow '\e[38;5;180m'; set highlight '\e[1;38;5;211m'; set command '\e[38;5;153m'; set dim '\e[3;38;5;103m'; set hint '\e[38;5;223m'; set ok '\e[32m'; set err '\e[31m'; set bold '\e[1m'
        case solarized
            set arrow '\e[1;33m'; set highlight '\e[1;31m'; set command '\e[1;34m'; set dim '\e[3;2m'; set hint '\e[1;35m'; set ok '\e[32m'; set err '\e[31m'; set bold '\e[1m'
        case catppuccin-latte
            set arrow '\e[38;5;136m'; set highlight '\e[1;38;5;124m'; set command '\e[38;5;25m'; set dim '\e[3;38;5;145m'; set hint '\e[38;5;133m'; set ok '\e[32m'; set err '\e[31m'; set bold '\e[1m'
        case github
            set arrow '\e[38;5;130m'; set highlight '\e[1;38;5;124m'; set command '\e[38;5;24m'; set dim '\e[3;38;5;246m'; set hint '\e[38;5;90m'; set ok '\e[32m'; set err '\e[31m'; set bold '\e[1m'
        case '*'
            set arrow '\e[1;93m'; set highlight '\e[1;31m'; set command '\e[1;36m'; set dim '\e[3m'; set hint '\e[1;33m'; set ok '\e[32m'; set err '\e[31m'; set bold '\e[1m'
    end

    set -q YSU_COLOR_ARROW; and set -g _YSU_C_ARROW "$YSU_COLOR_ARROW"; or set -g _YSU_C_ARROW "$arrow"
    set -q YSU_COLOR_HIGHLIGHT; and set -g _YSU_C_HIGHLIGHT "$YSU_COLOR_HIGHLIGHT"; or set -g _YSU_C_HIGHLIGHT "$highlight"
    set -q YSU_COLOR_COMMAND; and set -g _YSU_C_COMMAND "$YSU_COLOR_COMMAND"; or set -g _YSU_C_COMMAND "$command"
    set -q YSU_COLOR_DIM; and set -g _YSU_C_DIM "$YSU_COLOR_DIM"; or set -g _YSU_C_DIM "$dim"
    set -q YSU_COLOR_HINT; and set -g _YSU_C_HINT "$YSU_COLOR_HINT"; or set -g _YSU_C_HINT "$hint"
    set -q YSU_COLOR_OK; and set -g _YSU_C_OK "$YSU_COLOR_OK"; or set -g _YSU_C_OK "$ok"
    set -q YSU_COLOR_ERR; and set -g _YSU_C_ERR "$YSU_COLOR_ERR"; or set -g _YSU_C_ERR "$err"
    set -q YSU_COLOR_BOLD; and set -g _YSU_C_BOLD "$YSU_COLOR_BOLD"; or set -g _YSU_C_BOLD "$bold"
    set -g _YSU_C_RESET '\e[0m'
end
_ysu_init_colors

# ============================================================================
# Ollama auto-detection (runs once at plugin load, not every command)
# ============================================================================

set -g _YSU_LLM_RESOLVED_MODEL ""

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
            set -l _ysu_ollama_tags (curl -s --max-time 2 "http://localhost:11434/api/tags" 2>/dev/null)
            if test -n "$_ysu_ollama_tags"
                if test "$YSU_LLM_MODEL" = auto
                    # Auto mode: pick the first available model
                    set -l _ysu_first_model ""
                    if command -q jq
                        set _ysu_first_model (echo "$_ysu_ollama_tags" | jq -r '.models[0].name // empty' 2>/dev/null)
                    else if command -q python3
                        set _ysu_first_model (echo "$_ysu_ollama_tags" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    m = r.get('models', [])
    if m: print(m[0]['name'])
except: pass
" 2>/dev/null)
                    end
                    if test -n "$_ysu_first_model"
                        set -g _YSU_LLM_RESOLVED_MODEL "$_ysu_first_model"
                        set -g YSU_LLM_ENABLED true
                    end
                else
                    # Specific model: check if it's available
                    if echo "$_ysu_ollama_tags" | grep -q "\"$YSU_LLM_MODEL\"" 2>/dev/null
                        set -g _YSU_LLM_RESOLVED_MODEL "$YSU_LLM_MODEL"
                        set -g YSU_LLM_ENABLED true
                    end
                end
            end
        end
    end
end

# Resolve model for non-auto-detect cases (user enabled LLM manually)
if test "$YSU_LLM_ENABLED" = true; and test -z "$_YSU_LLM_RESOLVED_MODEL"
    if test "$YSU_LLM_MODEL" = auto
        # Try to resolve from Ollama
        set -l _ysu_tags (curl -s --max-time 2 "http://localhost:11434/api/tags" 2>/dev/null)
        if test -n "$_ysu_tags"
            if command -q jq
                set -g _YSU_LLM_RESOLVED_MODEL (echo "$_ysu_tags" | jq -r '.models[0].name // empty' 2>/dev/null)
            else if command -q python3
                set -g _YSU_LLM_RESOLVED_MODEL (echo "$_ysu_tags" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    m = r.get('models', [])
    if m: print(m[0]['name'])
except: pass
" 2>/dev/null)
            end
        end
    else
        set -g _YSU_LLM_RESOLVED_MODEL "$YSU_LLM_MODEL"
    end
end

# ============================================================================
# Modern command alternatives mapping (parallel lists)
# ============================================================================
# Format: YSU_MODERN_KEYS[i] = legacy command
#         YSU_MODERN_VALS[i] = "alt1:desc|alt2:desc"

if not set -q YSU_MODERN_KEYS
    set -g YSU_MODERN_KEYS \
        cat ls find grep du top ps diff sed curl ping dig man cd df xxd make wget time history cloc tree traceroute tmux vim
    set -g YSU_MODERN_VALS \
        "bat:Syntax highlighting, line numbers, git integration|glow:Terminal Markdown renderer" \
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
        "mcfly:Intelligent shell history search with neural network|atuin:Magical shell history with sync" \
        "tokei:Fast code line counter with language breakdown" \
        "broot:Interactive directory tree with fuzzy search" \
        "mtr:Combined traceroute and ping with live display" \
        "zellij:Modern terminal multiplexer with intuitive UI" \
        "nvim:Neovim - modernized Vim fork"
end

# Context-aware suggestions: suggest tools based on command + file extension
if not set -q YSU_CONTEXT_KEYS
    set -g YSU_CONTEXT_KEYS "diff:.json" "diff:.yaml" "diff:.yml"
    set -g YSU_CONTEXT_VALS \
        "jd:JSON diff and patch tool" \
        "jd:JSON diff and patch tool (also handles YAML)" \
        "jd:JSON diff and patch tool (also handles YAML)"
end

# ============================================================================
# Platform detection for install hints
# ============================================================================

function _ysu_detect_pkg_manager
    # WSL detection
    if test -f /proc/version; and grep -qi microsoft /proc/version 2>/dev/null
        set -g _YSU_IS_WSL true
    else
        set -g _YSU_IS_WSL false
    end

    if command -q brew
        set -g _YSU_PKG_MANAGER brew
        set -g _YSU_PKG_INSTALL "brew install"
    else if command -q apt
        set -g _YSU_PKG_MANAGER apt
        set -g _YSU_PKG_INSTALL "sudo apt install"
    else if command -q pacman
        set -g _YSU_PKG_MANAGER pacman
        set -g _YSU_PKG_INSTALL "sudo pacman -S"
    else if command -q dnf
        set -g _YSU_PKG_MANAGER dnf
        set -g _YSU_PKG_INSTALL "sudo dnf install"
    else if command -q zypper
        set -g _YSU_PKG_MANAGER zypper
        set -g _YSU_PKG_INSTALL "sudo zypper install"
    else if command -q apk
        set -g _YSU_PKG_MANAGER apk
        set -g _YSU_PKG_INSTALL "apk add"
    else if command -q pkg
        set -g _YSU_PKG_MANAGER pkg
        set -g _YSU_PKG_INSTALL "pkg install"
    else
        set -g _YSU_PKG_MANAGER unknown
        set -g _YSU_PKG_INSTALL ""
    end
end
_ysu_detect_pkg_manager

# Package name overrides per manager (tool → package_name)
# Parallel arrays: _YSU_PKG_OVERRIDE_KEYS_<mgr> / _YSU_PKG_OVERRIDE_VALS_<mgr>
set -g _YSU_PKG_OVERRIDE_KEYS_brew rg ag delta
set -g _YSU_PKG_OVERRIDE_VALS_brew ripgrep the_silver_searcher git-delta

set -g _YSU_PKG_OVERRIDE_KEYS_apt rg ag delta fd dust
set -g _YSU_PKG_OVERRIDE_VALS_apt ripgrep silversearcher-ag git-delta fd-find du-dust

set -g _YSU_PKG_OVERRIDE_KEYS_pacman rg ag delta
set -g _YSU_PKG_OVERRIDE_VALS_pacman ripgrep the_silver_searcher git-delta

set -g _YSU_PKG_OVERRIDE_KEYS_dnf rg ag delta
set -g _YSU_PKG_OVERRIDE_VALS_dnf ripgrep the_silver_searcher git-delta

function _ysu_get_pkg_name
    set -l tool $argv[1]
    set -l keys_var _YSU_PKG_OVERRIDE_KEYS_$_YSU_PKG_MANAGER
    set -l vals_var _YSU_PKG_OVERRIDE_VALS_$_YSU_PKG_MANAGER
    if set -q $keys_var
        set -l keys $$keys_var
        set -l vals $$vals_var
        for i in (seq (count $keys))
            if test "$keys[$i]" = "$tool"
                echo "$vals[$i]"
                return
            end
        end
    end
    echo "$tool"
end

# Install command hints (parallel lists: tool name → install command)
# Auto-generated based on detected package manager
if not set -q YSU_INSTALL_KEYS
    set -g YSU_INSTALL_KEYS \
        bat eza lsd fd rg ag dust ncdu btop htop procs delta colordiff sd httpie curlie gping dog tldr zoxide duf hexyl just xh hyperfine mcfly atuin glow tokei broot mtr zellij
    if test -n "$_YSU_PKG_INSTALL"
        set -g YSU_INSTALL_VALS
        for _t in $YSU_INSTALL_KEYS
            set -a YSU_INSTALL_VALS "$_YSU_PKG_INSTALL "(_ysu_get_pkg_name $_t)
        end
    else
        set -g YSU_INSTALL_VALS
        for _t in $YSU_INSTALL_KEYS
            set -a YSU_INSTALL_VALS ""
        end
    end
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
set -g _YSU_CMD_HISTORY
set -g _YSU_MULTI_ASYNC_FILE ""
set -g _YSU_MULTI_ASYNC_KEY ""

# ============================================================================
# Helper functions
# ============================================================================

function _ysu_print
    set -l prefix "$YSU_PREFIX"
    if test -n "$argv[1]"
        set prefix "$prefix$argv[1]"
    end
    set -l arrow "$_YSU_C_ARROW➜$_YSU_C_RESET"
    set -l message "$argv[2]$_YSU_C_RESET"
    set -l result (string replace -a '{prefix}' "$prefix" -- "$YSU_MESSAGE_FORMAT")
    set result (string replace -a '{arrow}' "$arrow" -- $result)
    set result (string replace -a '{message}' "$message" -- $result)
    echo -e $result
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

function _ysu_is_ignored_suggestion
    set -l cmd $argv[1]
    set -l alt $argv[2]
    for pair in $YSU_IGNORE_SUGGESTIONS
        if test "$pair" = "$cmd:$alt"
            return 0
        end
    end
    return 1
end

function _ysu_save_ignore_suggestions
    set -l cfg_dir (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/ysu"
    set -l cfg_file "$cfg_dir/config.fish"
    test -d "$cfg_dir"; or mkdir -p "$cfg_dir"
    if test -f "$cfg_file"
        set -l tmp (mktemp)
        grep -v '^set -gx YSU_IGNORE_SUGGESTIONS' "$cfg_file" > "$tmp"; and mv "$tmp" "$cfg_file"
    end
    if test -n "$YSU_IGNORE_SUGGESTIONS"
        echo "set -gx YSU_IGNORE_SUGGESTIONS $YSU_IGNORE_SUGGESTIONS" >> "$cfg_file"
    end
end

function _ysu_reminder_roll
    set -l key $argv[1]
    # Fast path: no half-life configured — always show
    test "$YSU_REMINDER_HALFLIFE" -le 0; and return 0

    set -l cache_dir "$YSU_LLM_CACHE_DIR"
    test -n "$cache_dir"; or set cache_dir "$HOME/.cache/ysu"
    set -l key_hash (_ysu_llm_cache_key "$key")
    set -l seen_file "$cache_dir/.seen_$key_hash"

    if test -f "$seen_file"
        set -l last_shown (cat "$seen_file" 2>/dev/null)
        set -l now (date +%s)
        set -l elapsed (math "$now - $last_shown")

        # Linear ramp: 0% at t=0, 100% at t=halflife
        set -l prob (math "min(100, $elapsed * 100 / $YSU_REMINDER_HALFLIFE)")
        set -l rand (random 1 100)
        if test "$rand" -gt "$prob"
            return 1
        end
    end

    # Will show — update timestamp
    mkdir -p "$cache_dir"
    date +%s > "$seen_file"
    return 0
end

# ============================================================================
# Auto-decay: reduce frequency for repeatedly ignored suggestions
# ============================================================================

function _ysu_decay_file
    set -l cache_dir "$YSU_LLM_CACHE_DIR"
    test -n "$cache_dir"; or set cache_dir "$HOME/.cache/ysu"
    set -l key_hash (_ysu_llm_cache_key "$argv[1]:$argv[2]")
    echo "$cache_dir/.decay_$key_hash"
end

function _ysu_decay_increment
    set -l file (_ysu_decay_file $argv[1] $argv[2])
    set -l cache_dir (dirname "$file")
    mkdir -p "$cache_dir"
    set -l count 0
    test -f "$file"; and set count (cat "$file" 2>/dev/null)
    math "$count + 1" > "$file"
end

function _ysu_decay_should_show
    test "$YSU_AUTO_DECAY_THRESHOLD" -le 0; and return 0
    set -l file (_ysu_decay_file $argv[1] $argv[2])
    set -l count 0
    test -f "$file"; and set count (cat "$file" 2>/dev/null)
    test "$count" -lt "$YSU_AUTO_DECAY_THRESHOLD"; and return 0
    set -l since (math "$count - $YSU_AUTO_DECAY_THRESHOLD")
    test (math "$since % 50") -eq 0; and return 0
    return 1
end

function _ysu_decay_is_low_freq
    test "$YSU_AUTO_DECAY_THRESHOLD" -le 0; and return 1
    set -l file (_ysu_decay_file $argv[1] $argv[2])
    set -l count 0
    test -f "$file"; and set count (cat "$file" 2>/dev/null)
    test "$count" -ge "$YSU_AUTO_DECAY_THRESHOLD"
end

function _ysu_decay_reset
    set -l file (_ysu_decay_file $argv[1] $argv[2])
    rm -f "$file" 2>/dev/null
end

function _ysu_check_adoption
    set -l first_word (string split -m1 ' ' -- $argv[1])[1]
    for i in (seq (count $YSU_MODERN_KEYS))
        for entry in (string split '|' -- $YSU_MODERN_VALS[$i])
            set -l alt_cmd (string split -m1 ':' -- $entry)[1]
            if test "$first_word" = "$alt_cmd"
                _ysu_decay_reset "$YSU_MODERN_KEYS[$i]" "$alt_cmd"
            end
        end
    end
    for j in (seq (count $YSU_CONTEXT_KEYS))
        set -l ctx_cmd (string split -m1 ':' -- $YSU_CONTEXT_VALS[$j])[1]
        if test "$first_word" = "$ctx_cmd"
            set -l ctx_orig (string split -m1 ':' -- $YSU_CONTEXT_KEYS[$j])[1]
            _ysu_decay_reset "$ctx_orig" "$ctx_cmd"
        end
    end
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
        _ysu_reminder_roll "$first_word"; or return
        _ysu_print "$YSU_REMINDER_PREFIX" \
            "You should use $_YSU_C_HIGHLIGHT$found_alias$_YSU_C_RESET instead of $_YSU_C_COMMAND$found_value$_YSU_C_RESET"
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

    # Context-aware check: inspect file extensions in arguments
    set -l _args (string split ' ' -- $typed_command)
    if test (count $_args) -gt 1
        for _arg in $_args[2..-1]
            set -l _ext (string match -r '\.([^.]+)$' -- $_arg)
            if test (count $_ext) -ge 2
                set -l _ctx_key "$first_word:.$_ext[2]"
                for _ci in (seq (count $YSU_CONTEXT_KEYS))
                    if test "$YSU_CONTEXT_KEYS[$_ci]" = "$_ctx_key"
                        set -l _ctx_entry $YSU_CONTEXT_VALS[$_ci]
                        set -l _ctx_cmd (string split -m1 ':' -- $_ctx_entry)[1]
                        set -l _ctx_desc (string split -m1 ':' -- $_ctx_entry)[2]
                        _ysu_is_ignored_suggestion "$first_word" "$_ctx_cmd"; and continue
                        if command -q $_ctx_cmd
                            _ysu_decay_increment "$first_word" "$_ctx_cmd"
                            _ysu_decay_should_show "$first_word" "$_ctx_cmd"; or return
                            _ysu_reminder_roll "$first_word"; or return
                            set -l _decay_msg "You should use $_YSU_C_HIGHLIGHT$_ctx_cmd$_YSU_C_RESET instead of $_YSU_C_COMMAND$first_word$_YSU_C_RESET — $_YSU_C_DIM$_ctx_desc$_YSU_C_RESET"
                            if _ysu_decay_is_low_freq "$first_word" "$_ctx_cmd"
                                set _decay_msg "$_decay_msg\n     $_YSU_C_DIM""此建议已被多次忽略，运行 $_YSU_C_HINT""ysu ignore $first_word:$_ctx_cmd$_YSU_C_RESET$_YSU_C_DIM 可永久关闭$_YSU_C_RESET"
                            end
                            _ysu_print "$YSU_SUGGEST_PREFIX" "$_decay_msg"
                            _ysu_record_tip
                            return
                        else if test "$YSU_INSTALL_HINT" = true
                            set -l _ctx_install ""
                            for _ii in (seq (count $YSU_INSTALL_KEYS))
                                if test "$YSU_INSTALL_KEYS[$_ii]" = "$_ctx_cmd"
                                    set _ctx_install "$YSU_INSTALL_VALS[$_ii]"
                                    break
                                end
                            end
                            if test -n "$_ctx_install"
                                _ysu_reminder_roll "$first_word"; or return
                                _ysu_print "$YSU_SUGGEST_PREFIX" \
                                    "Try $_YSU_C_HIGHLIGHT$_ctx_cmd$_YSU_C_RESET instead of $_YSU_C_COMMAND$first_word$_YSU_C_RESET — $_YSU_C_DIM$_ctx_desc$_YSU_C_RESET (install: $_YSU_C_HINT$_ctx_install$_YSU_C_RESET)"
                                _ysu_record_tip
                            end
                            return
                        end
                        break
                    end
                end
            end
        end
    end

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
    set -l _first_uninstalled ""
    set -l _first_uninstalled_desc ""
    set -l _first_uninstalled_install ""
    for entry in (string split '|' -- $mapping)
        set -l modern_cmd (string split -m1 ':' -- $entry)[1]
        set -l description (string split -m1 ':' -- $entry)[2]

        _ysu_is_ignored_suggestion "$first_word" "$modern_cmd"; and continue

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

            _ysu_decay_increment "$first_word" "$modern_cmd"
            _ysu_decay_should_show "$first_word" "$modern_cmd"; or return
            _ysu_reminder_roll "$first_word"; or return
            set -l _decay_msg "You should use $_YSU_C_HIGHLIGHT$modern_cmd$_YSU_C_RESET instead of $_YSU_C_COMMAND$first_word$_YSU_C_RESET — $_YSU_C_DIM$description$_YSU_C_RESET"
            if _ysu_decay_is_low_freq "$first_word" "$modern_cmd"
                set _decay_msg "$_decay_msg\n     $_YSU_C_DIM""此建议已被多次忽略，运行 $_YSU_C_HINT""ysu ignore $first_word:$modern_cmd$_YSU_C_RESET$_YSU_C_DIM 可永久关闭$_YSU_C_RESET"
            end
            _ysu_print "$YSU_SUGGEST_PREFIX" "$_decay_msg"
            _ysu_record_tip
            return
        else if test -z "$_first_uninstalled"
            set _first_uninstalled $modern_cmd
            set _first_uninstalled_desc $description
            # Look up install command
            for ii in (seq (count $YSU_INSTALL_KEYS))
                if test "$YSU_INSTALL_KEYS[$ii]" = "$modern_cmd"
                    set _first_uninstalled_install "$YSU_INSTALL_VALS[$ii]"
                    break
                end
            end
        end
    end

    # No installed alternative found — show install hint for the first one
    if test "$YSU_INSTALL_HINT" = true; and test -n "$_first_uninstalled"; and test -n "$_first_uninstalled_install"
        _ysu_reminder_roll "$first_word"; or return
        _ysu_print "$YSU_SUGGEST_PREFIX" \
            "Try $_YSU_C_HIGHLIGHT$_first_uninstalled$_YSU_C_RESET instead of $_YSU_C_COMMAND$first_word$_YSU_C_RESET — $_YSU_C_DIM$_first_uninstalled_desc$_YSU_C_RESET (install: $_YSU_C_HINT$_first_uninstalled_install$_YSU_C_RESET)"
        _ysu_record_tip
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
                _ysu_reminder_roll "$inner_command"; or return
                _ysu_print "$YSU_REMINDER_PREFIX" \
                    "You should use $_YSU_C_HIGHLIGHT$abbr_name $inner_command$_YSU_C_RESET instead of $_YSU_C_COMMAND""sudo $inner_command$_YSU_C_RESET"
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
                _ysu_reminder_roll "$inner_command"; or return
                _ysu_print "$YSU_REMINDER_PREFIX" \
                    "You should use $_YSU_C_HIGHLIGHT$func_name $inner_command$_YSU_C_RESET instead of $_YSU_C_COMMAND""sudo $inner_command$_YSU_C_RESET"
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

function _ysu_strip_env_prefix
    set -l cmd $argv[1]
    # Strip leading VAR=value assignments (e.g. "TASKS=0104 make run" → "make run")
    while string match -qr '^[A-Za-z_][A-Za-z0-9_]*=[^\\s]+\\s+(.+)' -- $cmd
        set cmd (string replace -r '^[A-Za-z_][A-Za-z0-9_]*=[^\\s]+\\s+' '' -- $cmd)
    end
    echo $cmd
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

function _ysu_get_effective_model
    if test "$YSU_LLM_MODEL" = auto; and test -n "$_YSU_LLM_RESOLVED_MODEL"
        echo "$_YSU_LLM_RESOLVED_MODEL"
    else if test "$YSU_LLM_MODEL" != auto
        echo "$YSU_LLM_MODEL"
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

    set -l effective_model (_ysu_get_effective_model)
    test -n "$effective_model"; or return

    set -l escaped_cmd (_ysu_llm_json_escape "$cmd")
    set -l system_prompt "You are a shell expert. Given a shell command, suggest a better alternative or optimization in one brief sentence. If there is no improvement, reply with exactly: none"
    set -l payload "{\"model\":\"$effective_model\",\"messages\":[{\"role\":\"system\",\"content\":\"$system_prompt\"},{\"role\":\"user\",\"content\":\"$escaped_cmd\"}],\"max_tokens\":100,\"temperature\":0.3}"

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
# Feature 4b: LLM multi-command analysis (sliding window)
# ============================================================================

function _ysu_multi_push_cmd
    set -g -a _YSU_CMD_HISTORY $argv[1]
    # Trim to window size
    while test (count $_YSU_CMD_HISTORY) -gt $YSU_LLM_WINDOW_SIZE
        set -e _YSU_CMD_HISTORY[1]
    end
end

function _ysu_multi_should_trigger
    test (count $_YSU_CMD_HISTORY) -ge 3; or return 1
    return 0
end

function _ysu_multi_query_async
    # Clean up any previous pending request
    if test -n "$_YSU_MULTI_ASYNC_FILE"
        rm -f "$_YSU_MULTI_ASYNC_FILE" "$_YSU_MULTI_ASYNC_FILE.done" 2>/dev/null
    end

    mkdir -p "$YSU_LLM_CACHE_DIR"
    set -g _YSU_MULTI_ASYNC_FILE (mktemp "$YSU_LLM_CACHE_DIR/.multi.XXXXXX")

    set -l effective_model (_ysu_get_effective_model)
    test -n "$effective_model"; or return

    # Build the command sequence string
    set -l cmd_sequence (string join \n -- $_YSU_CMD_HISTORY)

    set -l cache_key (_ysu_llm_cache_key "$cmd_sequence")
    set -l cache_file "$YSU_LLM_CACHE_DIR/multi_$cache_key"
    set -g _YSU_MULTI_ASYNC_KEY "$cache_key"

    # Check cache first
    if test -f "$cache_file"
        if test -s "$cache_file"
            set -l cached (cat "$cache_file")
            test -n "$cached"; and _ysu_print "$YSU_LLM_PREFIX" "$cached"
        end
        set -g _YSU_MULTI_ASYNC_FILE ""
        set -g _YSU_MULTI_ASYNC_KEY ""
        return
    end

    set -l escaped_cmds (_ysu_llm_json_escape "$cmd_sequence")
    set -l system_prompt "You are a shell workflow expert. Given a sequence of recent shell commands, identify if there is a pattern or workflow that could be optimized. Suggest a single improvement (a combined command, a tool, or a better workflow) in one brief sentence. If there is no improvement, reply with exactly: none"
    set -l payload "{\"model\":\"$effective_model\",\"messages\":[{\"role\":\"system\",\"content\":\"$system_prompt\"},{\"role\":\"user\",\"content\":\"Recent commands:\\n$escaped_cmds\"}],\"max_tokens\":150,\"temperature\":0.3}"

    set -l tmp_file $_YSU_MULTI_ASYNC_FILE
    set -l api_url $YSU_LLM_API_URL
    set -l api_key $YSU_LLM_API_KEY
    set -l cache_dir $YSU_LLM_CACHE_DIR

    fish -c "
        set -l auth_args
        test -n '$api_key'; and set auth_args -H 'Authorization: Bearer $api_key'

        set -l response (curl -s --max-time 15 \
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

function _ysu_multi_check_async
    test -n "$_YSU_MULTI_ASYNC_FILE"; or return
    test -f "$_YSU_MULTI_ASYNC_FILE.done"; or return

    set -l result ""
    if test -s "$_YSU_MULTI_ASYNC_FILE"
        set result (cat "$_YSU_MULTI_ASYNC_FILE")
    end

    set -l cache_file "$YSU_LLM_CACHE_DIR/multi_$_YSU_MULTI_ASYNC_KEY"
    if test -n "$result"
        echo $result > "$cache_file"
        _ysu_print "$YSU_LLM_PREFIX" "$result"
    else
        echo -n > "$cache_file"
    end

    rm -f "$_YSU_MULTI_ASYNC_FILE" "$_YSU_MULTI_ASYNC_FILE.done" 2>/dev/null
    set -g _YSU_MULTI_ASYNC_FILE ""
    set -g _YSU_MULTI_ASYNC_KEY ""
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
    _ysu_print "" "Enable AI-powered suggestions! Run $_YSU_C_HINT""ysu config$_YSU_C_RESET to set up."
end

# ============================================================================
# Hooks
# ============================================================================

function _ysu_on_preexec --on-event fish_preexec
    # Bail out if plugin is disabled
    test "$YSU_DISABLED" = true; and return

    set -l typed_command (string trim -- $argv[1])
    test -n "$typed_command"; or return

    # Save command for LLM evaluation in postexec (strip env var assignments)
    set -g _YSU_LLM_PENDING_CMD (_ysu_strip_env_prefix "$typed_command")

    # Push to multi-command history buffer
    if test "$YSU_LLM_ENABLED" = true; and test "$YSU_LLM_MODE" != single
        _ysu_multi_push_cmd "$_YSU_LLM_PENDING_CMD"
    end

    # Strip sudo prefix for matching — check the actual command, not sudo itself
    set -l check_command $typed_command
    set -l _ysu_has_sudo false
    if string match -qr '^sudo( |$)' -- $check_command
        set check_command (string replace -r '^sudo ?' '' -- $check_command)
        set _ysu_has_sudo true
    end

    # Skip if only sudo with no actual command
    test -n "$check_command"; or return

    # Check if user adopted a modern alternative (resets decay counter)
    _ysu_check_adoption "$check_command"

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

    # Bail out if plugin is disabled
    test "$YSU_DISABLED" = true; and return

    # LLM: display completed async results from previous commands
    # Track which cache keys were just displayed to avoid duplicates
    set -l _llm_just_shown ""
    if test "$YSU_LLM_ENABLED" = true
        if test -n "$_YSU_LLM_ASYNC_CMD"
            set _llm_just_shown (_ysu_llm_cache_key "$_YSU_LLM_ASYNC_CMD")
        end
        if test "$YSU_LLM_MODE" != multi
            _ysu_llm_check_async
        end
        if test "$YSU_LLM_MODE" != single
            _ysu_multi_check_async
        end
    end

    # LLM: evaluate triggers for the just-finished command
    if test "$YSU_LLM_ENABLED" = true; and test -n "$_YSU_LLM_PENDING_CMD"
        # Single-command mode
        if test "$YSU_LLM_MODE" != multi
            if _ysu_llm_should_trigger "$_YSU_LLM_PENDING_CMD" "$last_exit"
                set -l cache_key (_ysu_llm_cache_key "$_YSU_LLM_PENDING_CMD")
                set -l cache_file "$YSU_LLM_CACHE_DIR/$cache_key"

                # Skip if async check already displayed this same result
                if test "$cache_key" != "$_llm_just_shown"
                    if test -f "$cache_file"
                        if test -s "$cache_file"
                            set -l cached (cat "$cache_file")
                            test -n "$cached"; and _ysu_print "$YSU_LLM_PREFIX" "$cached"
                        end
                    else
                        _ysu_llm_query_async "$_YSU_LLM_PENDING_CMD"
                    end
                end
            end
        end

        # Multi-command mode
        if test "$YSU_LLM_MODE" != single
            if _ysu_multi_should_trigger
                _ysu_multi_query_async
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

function _ysu_install_method
    set -l plugin_file (status filename)
    if string match -q '*/Cellar/*' "$plugin_file"; or string match -q '*/homebrew/*' "$plugin_file"
        echo "homebrew"
    else if functions -q fisher
        # Check if installed via fisher
        if fisher list 2>/dev/null | string match -q '*you-should-use*'
            echo "fisher"
            return
        end
        echo "git"
    else if type -q omf
        echo "omf"
    else if test -d (dirname "$plugin_file")/.git
        echo "git"
    else
        echo "unknown"
    end
end

function ysu
    switch $argv[1]
        case config
            _ysu_config_wizard
        case cache
            switch $argv[2]
                case clear
                    find "$YSU_LLM_CACHE_DIR" -maxdepth 1 -type f -delete 2>/dev/null
                    echo "LLM cache cleared."
                case size
                    set -l count (find "$YSU_LLM_CACHE_DIR" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | string trim)
                    echo "$count cached suggestions"
                case '*'
                    echo "Usage: ysu cache [clear|size]"
            end
        case ignore
            if test (count $argv) -lt 2
                if test -z "$YSU_IGNORE_SUGGESTIONS"
                    echo "No suggestions are currently ignored."
                    echo "Usage: ysu ignore <command>:<alternative>"
                    echo "Example: ysu ignore make:just"
                else
                    echo "Ignored suggestions:"
                    for pair in $YSU_IGNORE_SUGGESTIONS
                        set -l _cmd (string split -m1 ':' -- $pair)[1]
                        set -l _alt (string split -m1 ':' -- $pair)[2]
                        echo "  $_cmd → $_alt"
                    end
                end
            else
                set -l pair $argv[2]
                if not string match -qr ':' -- $pair
                    echo "Invalid format. Use: ysu ignore <command>:<alternative>"
                    echo "Example: ysu ignore make:just"
                    return 1
                end
                set -l _cmd (string split -m1 ':' -- $pair)[1]
                set -l _alt (string split -m1 ':' -- $pair)[2]
                if _ysu_is_ignored_suggestion "$_cmd" "$_alt"
                    echo "Already ignored: $pair"
                    return 0
                end
                set -g -a YSU_IGNORE_SUGGESTIONS $pair
                _ysu_save_ignore_suggestions
                echo "Ignored: $_cmd → $_alt"
            end
        case unignore
            if test (count $argv) -lt 2
                echo "Usage: ysu unignore <command>:<alternative>"
                echo "Example: ysu unignore make:just"
                return 1
            end
            set -l pair $argv[2]
            set -l _cmd (string split -m1 ':' -- $pair)[1]
            set -l _alt (string split -m1 ':' -- $pair)[2]
            if not _ysu_is_ignored_suggestion "$_cmd" "$_alt"
                echo "Not currently ignored: $pair"
                return 1
            end
            set -l new_list
            for p in $YSU_IGNORE_SUGGESTIONS
                if test "$p" != "$pair"
                    set -a new_list $p
                end
            end
            set -g YSU_IGNORE_SUGGESTIONS $new_list
            _ysu_save_ignore_suggestions
            echo "Unignored: $_cmd → $_alt"
        case status
            _ysu_status
        case doctor
            _ysu_doctor
        case discover
            _ysu_discover $argv[2..-1]
        case update
            set -l method (_ysu_install_method)
            switch $method
                case homebrew
                    echo "Installed via Homebrew. Run:"
                    echo "  brew upgrade you-should-use"
                case fisher
                    echo "Installed via Fisher. Run:"
                    echo "  fisher update vangie/you-should-use"
                case omf
                    echo "Installed via Oh My Fish. Run:"
                    echo "  omf update you-should-use"
                case git
                    set -l plugin_dir (dirname (status filename))
                    # If it's a symlink, follow to the repo
                    if test -L (status filename)
                        set plugin_dir (realpath (status filename) | xargs dirname)
                    end
                    echo "Updating you-should-use..."
                    git -C "$plugin_dir" pull --ff-only; and echo "Updated. Restart your shell: exec fish"
                case '*'
                    echo "Unknown install method. Update manually from https://github.com/vangie/you-should-use"
            end
        case uninstall
            set -l method (_ysu_install_method)
            switch $method
                case homebrew
                    echo "Installed via Homebrew. Run:"
                    echo "  brew uninstall you-should-use"
                case fisher
                    echo "Installed via Fisher. Run:"
                    echo "  fisher remove vangie/you-should-use"
                case omf
                    echo "Installed via Oh My Fish. Run:"
                    echo "  omf remove you-should-use"
                case git
                    set -l plugin_file (status filename)
                    set -l conf_link "$HOME/.config/fish/conf.d/you-should-use.fish"
                    echo "Uninstalling you-should-use..."
                    if test -L "$conf_link"
                        rm -f "$conf_link"
                        echo "Removed symlink $conf_link"
                    else if test -f "$conf_link"
                        rm -f "$conf_link"
                        echo "Removed $conf_link"
                    end
                    # Remove source repo if it's the standalone clone
                    if test -L "$plugin_file"
                        set -l repo_dir (realpath "$plugin_file" | xargs dirname | xargs dirname)
                        if test -d "$repo_dir/.git"
                            rm -rf "$repo_dir"
                            echo "Removed $repo_dir"
                        end
                    end
                    rm -rf (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/ysu"
                    rm -rf (set -q XDG_CACHE_HOME; and echo "$XDG_CACHE_HOME"; or echo "$HOME/.cache")"/ysu"
                    echo "Uninstalled. Restart your shell: exec fish"
                case '*'
                    echo "Unknown install method. Uninstall manually."
            end
        case '*'
            echo "Usage: ysu <command>"
            echo "Commands:"
            echo "  config      Configure you-should-use interactively"
            echo "  ignore      Suppress a specific suggestion (e.g. ysu ignore make:just)"
            echo "  unignore    Re-enable a suppressed suggestion"
            echo "  cache       Manage LLM suggestion cache"
            echo "  status      Show current configuration and statistics"
            echo "  doctor      Run diagnostics and check for issues"
            echo "  discover    Analyze history and suggest aliases"
            echo "  update      Update you-should-use to the latest version"
            echo "  uninstall   Remove you-should-use from your system"
    end
end

function _ysu_status
    set -l green "$_YSU_C_OK"
    set -l red "$_YSU_C_ERR"
    set -l bold "$_YSU_C_BOLD"
    set -l reset "$_YSU_C_RESET"
    set -l check $green'✓'$reset
    set -l cross $red'✗'$reset

    echo ""
    echo -e $bold'📊 you-should-use status'$reset
    echo "─────────────────────────"

    # Core Settings
    echo -e $bold'Core Settings:'$reset
    if test "$YSU_DISABLED" = true
        echo -e "  Plugin:             "$cross' disabled (YSU_DISABLED=true)'
    end
    echo -e "  Alias Reminders:    "(test "$YSU_REMINDER_ENABLED" = true; and echo -e $check' enabled'; or echo -e $cross' disabled')
    echo -e "  Modern Suggestions: "(test "$YSU_SUGGEST_ENABLED" = true; and echo -e $check' enabled'; or echo -e $cross' disabled')
    echo -e "  Prefix:             \"$YSU_PREFIX\""
    echo -e "  Probability:        $YSU_PROBABILITY%"
    if test "$YSU_REMINDER_HALFLIFE" -gt 0
        echo -e "  Reminder Halflife:  "$YSU_REMINDER_HALFLIFE"s"
    end
    echo -e "  Cooldown:           "$YSU_COOLDOWN"s"
    if test "$YSU_AUTO_DECAY_THRESHOLD" -gt 0
        echo -e "  Auto-Decay:         after "$YSU_AUTO_DECAY_THRESHOLD" ignores → low-frequency"
    else
        echo -e "  Auto-Decay:         "$cross" disabled"
    end
    echo -e "  Install Hints:      "(test "$YSU_INSTALL_HINT" = true; and echo -e $check' enabled'; or echo -e $cross' disabled')
    echo -e "  Package Manager:    $_YSU_PKG_MANAGER"(test "$_YSU_IS_WSL" = true; and echo " (WSL)"; or echo "")
    if test "$YSU_MESSAGE_FORMAT" != "{prefix} {arrow} {message}"
        echo -e "  Message Format:     $YSU_MESSAGE_FORMAT"
    end
    if test -n "$YSU_IGNORE_ALIASES"
        echo -e "  Ignored Aliases:    $YSU_IGNORE_ALIASES"
    end
    if test -n "$YSU_IGNORE_COMMANDS"
        echo -e "  Ignored Commands:   $YSU_IGNORE_COMMANDS"
    end
    if test -n "$YSU_IGNORE_SUGGESTIONS"
        echo -e "  Ignored Suggestions:"
        for _pair in $YSU_IGNORE_SUGGESTIONS
            set -l _cmd (string split -m1 ':' -- $_pair)[1]
            set -l _alt (string split -m1 ':' -- $_pair)[2]
            echo -e "    $_cmd → $_alt"
        end
    end

    # LLM Settings
    echo ""
    echo -e $bold'LLM Settings:'$reset
    set -l llm_status
    if test "$YSU_LLM_ENABLED" = true
        set llm_status $check' enabled'
        # Check if it was auto-detected via Ollama
        if set -q _YSU_OLLAMA_CHECKED
            set -l _ysu_cfg (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/ysu/config.fish"
            if test -f "$_ysu_cfg"; and grep -q 'YSU_LLM_ENABLED' "$_ysu_cfg" 2>/dev/null
                set llm_status $llm_status' (user configured)'
            else
                set llm_status $llm_status' (auto-detected Ollama)'
            end
        end
    else
        set llm_status $cross' disabled'
    end
    echo -e "  Enabled:            $llm_status"
    echo -e "  API URL:            $YSU_LLM_API_URL"
    if test "$YSU_LLM_MODEL" = auto
        if test -n "$_YSU_LLM_RESOLVED_MODEL"
            echo -e "  Model:              auto ($_YSU_LLM_RESOLVED_MODEL)"
        else
            echo -e "  Model:              auto (unresolved)"
        end
    else
        echo -e "  Model:              $YSU_LLM_MODEL"
    end
    if test -n "$YSU_LLM_API_KEY"
        echo -e "  API Key:            ••••"(string sub -s -4 -- "$YSU_LLM_API_KEY")
    else
        echo -e "  API Key:            (not set)"
    end

    # Cache stats
    set -l cache_count 0
    if test -d "$YSU_LLM_CACHE_DIR"
        set cache_count (find "$YSU_LLM_CACHE_DIR" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | string trim)
    end
    echo -e "  Mode:               $YSU_LLM_MODE"
    if test "$YSU_LLM_MODE" != single
        echo -e "  Window Size:        $YSU_LLM_WINDOW_SIZE commands"
        echo -e "  History Buffer:     "(count $_YSU_CMD_HISTORY)" commands"
    end
    echo -e "  Cache:              $cache_count entries"

    # Statistics
    echo ""
    echo -e $bold'Statistics:'$reset

    # Count abbreviations
    set -l abbr_count (abbr --list 2>/dev/null | wc -l | string trim)
    echo -e "  Abbreviations:      $abbr_count defined"

    # Count modern tool mappings
    set -l modern_count (count $YSU_MODERN_KEYS)
    echo -e "  Modern mappings:    $modern_count"

    # Promo stats
    if test "$YSU_LLM_ENABLED" = false
        echo -e "  Promo shown today:  $_YSU_PROMO_SHOWN_TODAY/3"
    end

    # Config file
    echo ""
    echo -e $bold'Config File:'$reset
    set -l cfg_file (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/ysu/config.fish"
    if test -f "$cfg_file"
        echo -e "  $check $cfg_file"
    else
        echo -e "  (using defaults — run $_YSU_C_HINT""ysu config$_YSU_C_RESET to customize)"
    end
    echo ""
end

function _ysu_discover
    set -l min_count 5
    if test (count $argv) -ge 1; and string match -qr '^\d+$' -- $argv[1]
        set min_count $argv[1]
    end
    set -l min_words 2
    set -l bold "$_YSU_C_BOLD"
    set -l reset "$_YSU_C_RESET"
    set -l cyan "$_YSU_C_COMMAND"
    set -l yellow "$_YSU_C_HINT"
    set -l green "$_YSU_C_OK"

    echo ""
    echo -e $bold'🔍 Alias Discovery'$reset
    echo "─────────────────────────"
    echo -e "Analyzing history for commands used >= $min_count times..."
    echo ""

    # Fish stores history in ~/.local/share/fish/fish_history
    set -l histfile "$HOME/.local/share/fish/fish_history"
    if not test -f "$histfile"
        echo "No history file found at $histfile"
        return 1
    end

    # Get existing abbreviations for filtering
    set -l existing_abbrs (abbr --list 2>/dev/null)

    # Parse fish history (format: "- cmd: command\n  when: timestamp")
    # Extract commands, count 2-word and 3-word prefixes
    set -l prefixes
    set -l counts
    for line in (grep '^- cmd: ' "$histfile" | sed 's/^- cmd: //')
        set -l words (string split ' ' -- $line)
        test (count $words) -lt $min_words; and continue

        # 2-word prefix
        set -l p2 "$words[1] $words[2]"
        # Skip internal functions
        string match -q '_ysu_*' -- $p2; and continue
        string match -q 'cd *' -- $p2; and continue
        string match -q 'echo *' -- $p2; and continue

        set -l found_idx 0
        for i in (seq (count $prefixes))
            if test "$prefixes[$i]" = "$p2"
                set found_idx $i
                break
            end
        end
        if test "$found_idx" -gt 0
            set counts[$found_idx] (math $counts[$found_idx] + 1)
        else
            set -a prefixes "$p2"
            set -a counts 1
        end

        # 3-word prefix
        if test (count $words) -ge 3
            set -l p3 "$words[1] $words[2] $words[3]"
            set found_idx 0
            for i in (seq (count $prefixes))
                if test "$prefixes[$i]" = "$p3"
                    set found_idx $i
                    break
                end
            end
            if test "$found_idx" -gt 0
                set counts[$found_idx] (math $counts[$found_idx] + 1)
            else
                set -a prefixes "$p3"
                set -a counts 1
            end
        end
    end

    # Display suggestions
    set -l found 0
    for i in (seq (count $prefixes))
        test "$counts[$i]" -lt "$min_count"; and continue

        # Skip if already abbreviated
        set -l skip false
        for ab in $existing_abbrs
            if test "$ab" = "$prefixes[$i]"
                set skip true
                break
            end
        end
        test "$skip" = true; and continue

        set -l suggestion (_ysu_suggest_alias_name "$prefixes[$i]")
        echo -e "  $cyan$prefixes[$i]$reset  (used $yellow$counts[$i]$reset times)"
        echo -e "    $green""abbr -a $suggestion '$prefixes[$i]'$reset"
        echo ""
        set found (math $found + 1)
    end

    if test "$found" -eq 0
        echo "No alias suggestions found. Try lowering the threshold: ysu discover 3"
    end
    echo ""
end

function _ysu_suggest_alias_name
    set -l cmd $argv[1]
    set -l words (string split ' ' -- $cmd)
    set -l name ""
    for word in $words
        # Skip flags
        string match -q '-*' -- $word; and continue
        set name $name(string sub -l 1 -- $word)
    end
    if test (string length -- "$name") -lt 2
        set name ""
        for word in $words
            set name $name(string sub -l 1 -- $word)
        end
    end
    echo (string lower -- $name)
end

function _ysu_doctor
    set -l green "$_YSU_C_OK"
    set -l red "$_YSU_C_ERR"
    set -l yellow "$_YSU_C_HINT"
    set -l bold "$_YSU_C_BOLD"
    set -l reset "$_YSU_C_RESET"
    set -l check $green'✓'$reset
    set -l cross $red'✗'$reset
    set -l warn $yellow'!'$reset
    set -l issues 0

    echo ""
    echo -e $bold'🩺 you-should-use doctor'$reset
    echo "─────────────────────────"

    # 1. Shell compatibility
    echo -e $bold'Shell:'$reset
    echo -e "  $check Fish $FISH_VERSION"
    set -l major (string split '.' -- $FISH_VERSION)[1]
    if test "$major" -ge 3
        echo -e "  $check Fish version >= 3.0 (required)"
    else
        echo -e "  $cross Fish version < 3.0 — some features may not work"
        set issues (math $issues + 1)
    end

    # 2. Plugin load
    echo ""
    echo -e $bold'Plugin:'$reset
    if functions -q _ysu_on_preexec
        echo -e "  $check preexec handler defined"
    else
        echo -e "  $cross preexec handler NOT defined — alias reminders won't work"
        set issues (math $issues + 1)
    end

    # Plugin load time
    set -l t0 (date +%s%N 2>/dev/null; or gdate +%s%N 2>/dev/null; or echo 0)
    fish -c "source (status filename)" 2>/dev/null
    set -l t1 (date +%s%N 2>/dev/null; or gdate +%s%N 2>/dev/null; or echo 0)
    if test "$t0" != 0 -a "$t1" != 0
        set -l ms (math "($t1 - $t0) / 1000000")
        echo -e "  Plugin load time:   "$ms"ms"
        if test "$ms" -gt 500
            echo -e "  $warn Load time > 500ms — consider disabling Ollama auto-detect if slow"
            set issues (math $issues + 1)
        end
    end

    # 3. Config conflicts
    echo ""
    echo -e $bold'Config:'$reset
    set -l cfg_file (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/ysu/config.fish"
    if test -f "$cfg_file"
        echo -e "  $check Config file: $cfg_file"
        if grep -q 'YSU_PROBABILITY 0' "$cfg_file" 2>/dev/null
            echo -e "  $warn YSU_PROBABILITY=0 — tips will never show"
            set issues (math $issues + 1)
        end
    else
        echo -e "  $check No config file (using defaults)"
    end
    if test "$YSU_PROBABILITY" -lt 1 -o "$YSU_PROBABILITY" -gt 100 2>/dev/null
        echo -e "  $cross YSU_PROBABILITY=$YSU_PROBABILITY — must be 1-100"
        set issues (math $issues + 1)
    end
    if test "$YSU_REMINDER_HALFLIFE" -lt 0 2>/dev/null
        echo -e "  $cross YSU_REMINDER_HALFLIFE=$YSU_REMINDER_HALFLIFE — must be >= 0"
        set issues (math $issues + 1)
    end

    # 4. Package manager
    echo ""
    echo -e $bold'Package Manager:'$reset
    if test "$_YSU_PKG_MANAGER" != unknown
        echo -e "  $check Detected: $_YSU_PKG_MANAGER"
    else
        echo -e "  $warn No package manager detected — install hints will be empty"
        set issues (math $issues + 1)
    end

    # 5. LLM connection
    echo ""
    echo -e $bold'LLM:'$reset
    if test "$YSU_LLM_ENABLED" = true
        echo -e "  $check LLM enabled"
        if string match -q '*localhost:11434*' -- "$YSU_LLM_API_URL"; or string match -q '*127.0.0.1:11434*' -- "$YSU_LLM_API_URL"
            set -l ollama_resp (curl -s --max-time 3 "http://localhost:11434/api/tags" 2>/dev/null)
            if test -n "$ollama_resp"
                echo -e "  $check Ollama reachable"
                set -l model (_ysu_get_effective_model)
                if test -n "$model"
                    echo -e "  $check Model: $model"
                else
                    echo -e "  $cross No model resolved — run 'ollama pull qwen2.5-coder:7b'"
                    set issues (math $issues + 1)
                end
            else
                echo -e "  $cross Ollama not reachable at localhost:11434"
                set issues (math $issues + 1)
            end
        else
            set -l api_resp (curl -s --max-time 5 -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer $YSU_LLM_API_KEY" \
                "$YSU_LLM_API_URL" 2>/dev/null)
            if string match -qr '^[23]' -- "$api_resp"
                echo -e "  $check API reachable (HTTP $api_resp)"
            else
                echo -e "  $cross API not reachable: $YSU_LLM_API_URL (HTTP $api_resp)"
                set issues (math $issues + 1)
            end
        end
        if test -d "$YSU_LLM_CACHE_DIR" -a -w "$YSU_LLM_CACHE_DIR"
            echo -e "  $check Cache dir writable: $YSU_LLM_CACHE_DIR"
        else
            echo -e "  $cross Cache dir not writable: $YSU_LLM_CACHE_DIR"
            set issues (math $issues + 1)
        end
    else
        echo -e "  LLM disabled (not tested)"
    end

    # 6. Dependencies
    echo ""
    echo -e $bold'Dependencies:'$reset
    if command -q curl
        echo -e "  $check curl"
    else
        echo -e "  $cross curl (required for LLM)"
        set issues (math $issues + 1)
    end
    if command -q jq
        echo -e "  $check jq"
    else
        echo -e "  $warn jq (optional — used for Ollama model detection)"
    end

    # Summary
    echo ""
    if test "$issues" -eq 0
        echo -e $green$bold'No issues found!'$reset
    else
        echo -e $yellow$bold$issues' issue(s) found'$reset
    end
    echo ""
end

function _ysu_config_wizard
    set -l _script_dir (dirname (status filename))"/../bin"
    # Resolve to absolute path if possible
    if command -sq realpath
        set _script_dir (realpath "$_script_dir")
    end
    set -l _script "$_script_dir/ysu-config.sh"
    set -l _config_file (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/ysu/config.fish"
    set -lx YSU_REMINDER_ENABLED "$YSU_REMINDER_ENABLED"
    set -lx YSU_SUGGEST_ENABLED "$YSU_SUGGEST_ENABLED"
    set -lx YSU_LLM_ENABLED "$YSU_LLM_ENABLED"
    set -lx YSU_PROBABILITY "$YSU_PROBABILITY"
    set -lx YSU_REMINDER_HALFLIFE "$YSU_REMINDER_HALFLIFE"
    set -lx YSU_COOLDOWN "$YSU_COOLDOWN"
    set -lx YSU_LLM_API_URL "$YSU_LLM_API_URL"
    set -lx YSU_LLM_API_KEY "$YSU_LLM_API_KEY"
    set -lx YSU_LLM_MODEL "$YSU_LLM_MODEL"
    set -lx YSU_LLM_MODE "$YSU_LLM_MODE"
    set -lx YSU_INSTALL_HINT "$YSU_INSTALL_HINT"
    set -lx YSU_MESSAGE_FORMAT "$YSU_MESSAGE_FORMAT"
    set -lx YSU_THEME "$YSU_THEME"
    set -lx YSU_DARK_THEME "$YSU_DARK_THEME"
    set -lx YSU_LIGHT_THEME "$YSU_LIGHT_THEME"
    bash "$_script" --format fish
    test -f "$_config_file"; and source "$_config_file"
    _ysu_init_colors
end
