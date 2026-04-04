# you-should-use - Alias reminders & modern command suggestions for Nushell
# https://github.com/vangie/you-should-use
# MIT License
#
# Installation:
#   source ~/.config/nushell/you-should-use.plugin.nu
#   (add this line to your config.nu or env.nu)
#
# Requires: Nushell >= 0.80

# ============================================================================
# Configuration (set these in env.nu BEFORE sourcing this plugin)
# ============================================================================

$env.YSU_DISABLED = ($env.YSU_DISABLED? | default false)
$env.YSU_REMINDER_ENABLED = ($env.YSU_REMINDER_ENABLED? | default true)
$env.YSU_SUGGEST_ENABLED = ($env.YSU_SUGGEST_ENABLED? | default true)
$env.YSU_LLM_ENABLED = ($env.YSU_LLM_ENABLED? | default false)
$env.YSU_PREFIX = ($env.YSU_PREFIX? | default "💡")
$env.YSU_REMINDER_PREFIX = ($env.YSU_REMINDER_PREFIX? | default "")
$env.YSU_SUGGEST_PREFIX = ($env.YSU_SUGGEST_PREFIX? | default "")
$env.YSU_LLM_PREFIX = ($env.YSU_LLM_PREFIX? | default "🤖")
$env.YSU_PROBABILITY = ($env.YSU_PROBABILITY? | default 100)
$env.YSU_REMINDER_HALFLIFE = ($env.YSU_REMINDER_HALFLIFE? | default 300)
$env.YSU_COOLDOWN = ($env.YSU_COOLDOWN? | default 0)
$env.YSU_IGNORE_ALIASES = ($env.YSU_IGNORE_ALIASES? | default "")
$env.YSU_IGNORE_COMMANDS = ($env.YSU_IGNORE_COMMANDS? | default "")
$env.YSU_INSTALL_HINT = ($env.YSU_INSTALL_HINT? | default true)
$env.YSU_MESSAGE_FORMAT = ($env.YSU_MESSAGE_FORMAT? | default "{prefix} {arrow} {message}")
$env.YSU_LLM_API_URL = ($env.YSU_LLM_API_URL? | default "http://localhost:11434/v1/chat/completions")
$env.YSU_LLM_API_KEY = ($env.YSU_LLM_API_KEY? | default "")
$env.YSU_LLM_MODEL = ($env.YSU_LLM_MODEL? | default "auto")
$env.YSU_LLM_CACHE_DIR = ($env.YSU_LLM_CACHE_DIR? | default $"($env.HOME)/.cache/ysu")
$env.YSU_LLM_MODE = ($env.YSU_LLM_MODE? | default "single")
$env.YSU_LLM_WINDOW_SIZE = ($env.YSU_LLM_WINDOW_SIZE? | default 5)

# Theme: "dark" (default), "light", or "custom"
$env.YSU_THEME = ($env.YSU_THEME? | default "dark")

# Color initialization
if $env.YSU_THEME == "light" {
    $env._YSU_C_HIGHLIGHT = ($env.YSU_COLOR_HIGHLIGHT? | default (ansi -e "1;31m"))
    $env._YSU_C_COMMAND = ($env.YSU_COLOR_COMMAND? | default (ansi -e "1;34m"))
    $env._YSU_C_DIM = ($env.YSU_COLOR_DIM? | default (ansi -e "3;2m"))
    $env._YSU_C_HINT = ($env.YSU_COLOR_HINT? | default (ansi -e "1;35m"))
} else {
    $env._YSU_C_HIGHLIGHT = ($env.YSU_COLOR_HIGHLIGHT? | default (ansi red_bold))
    $env._YSU_C_COMMAND = ($env.YSU_COLOR_COMMAND? | default (ansi cyan_bold))
    $env._YSU_C_DIM = ($env.YSU_COLOR_DIM? | default (ansi italic))
    $env._YSU_C_HINT = ($env.YSU_COLOR_HINT? | default (ansi yellow_bold))
}
$env._YSU_C_OK = ($env.YSU_COLOR_OK? | default (ansi green))
$env._YSU_C_ERR = ($env.YSU_COLOR_ERR? | default (ansi red))
$env._YSU_C_BOLD = ($env.YSU_COLOR_BOLD? | default (ansi attr_bold))
$env._YSU_C_RESET = (ansi reset)

# Internal state
$env._YSU_LAST_TIP_TIME = 0
$env._YSU_MESSAGES = []
$env._YSU_CMD_HAD_TIPS = false

# ============================================================================
# Modern command alternatives mapping
# ============================================================================

const YSU_MODERN_COMMANDS = {
    cat: "bat:Syntax highlighting, line numbers, git integration|glow:Terminal Markdown renderer"
    ls: "eza:Modern file listing with icons, git status, tree view|lsd:LSDeluxe - colorful ls with icons"
    find: "fd:Simpler syntax, faster, respects .gitignore"
    grep: "rg:Ripgrep - faster, respects .gitignore, better defaults|ag:The Silver Searcher - fast code search"
    du: "dust:Intuitive disk usage with visual chart|ncdu:NCurses disk usage analyzer"
    top: "btop:Beautiful resource monitor with mouse support|htop:Interactive process viewer"
    ps: "procs:Modern process viewer with tree display"
    diff: "delta:Syntax highlighting, side-by-side view, git integration|colordiff:Colorized diff output"
    sed: "sd:Simpler syntax, uses regex by default"
    curl: "httpie:Human-friendly HTTP client (command: http)|curlie:Curl with httpie-like interface"
    ping: "gping:Ping with a graph"
    dig: "dog:DNS client with colorful output"
    man: "tldr:Simplified, community-driven man pages"
    cd: "zoxide:Smarter cd that learns your habits (command: z)"
    df: "duf:Disk usage with colorful output and device overview"
    xxd: "hexyl:Colorful hex viewer with modern UI"
    make: "just:Simpler command runner, no tabs required"
    wget: "xh:Fast, friendly HTTP client (like httpie but faster)"
    time: "hyperfine:Benchmarking tool with statistical analysis"
    history: "mcfly:Intelligent shell history search with neural network|atuin:Magical shell history with sync"
    cloc: "tokei:Fast code line counter with language breakdown"
    tree: "broot:Interactive directory tree with fuzzy search"
    traceroute: "mtr:Combined traceroute and ping with live display"
    tmux: "zellij:Modern terminal multiplexer with intuitive UI"
}

# ============================================================================
# Platform detection
# ============================================================================

def _ysu_detect_pkg_manager [] {
    if (which brew | length) > 0 {
        { manager: "brew", install: "brew install" }
    } else if (which apt | length) > 0 {
        { manager: "apt", install: "sudo apt install" }
    } else if (which pacman | length) > 0 {
        { manager: "pacman", install: "sudo pacman -S" }
    } else if (which dnf | length) > 0 {
        { manager: "dnf", install: "sudo dnf install" }
    } else if (which zypper | length) > 0 {
        { manager: "zypper", install: "sudo zypper install" }
    } else if (which apk | length) > 0 {
        { manager: "apk", install: "apk add" }
    } else {
        { manager: "unknown", install: "" }
    }
}

# Package name overrides per manager
const PKG_OVERRIDES = {
    brew: { rg: "ripgrep", ag: "the_silver_searcher", delta: "git-delta" }
    apt: { rg: "ripgrep", ag: "silversearcher-ag", delta: "git-delta", fd: "fd-find", dust: "du-dust" }
    pacman: { rg: "ripgrep", ag: "the_silver_searcher", delta: "git-delta" }
    dnf: { rg: "ripgrep", ag: "the_silver_searcher", delta: "git-delta" }
}

let pkg_info = (_ysu_detect_pkg_manager)
$env._YSU_PKG_MANAGER = $pkg_info.manager
$env._YSU_PKG_INSTALL = $pkg_info.install

def _ysu_get_pkg_name [tool: string] {
    let mgr = $env._YSU_PKG_MANAGER
    if ($mgr in $PKG_OVERRIDES) and ($tool in ($PKG_OVERRIDES | get $mgr)) {
        $PKG_OVERRIDES | get $mgr | get $tool
    } else {
        $tool
    }
}

# Build install commands table
const INSTALL_TOOLS = [
    "bat" "eza" "lsd" "fd" "rg" "ag" "dust" "ncdu" "btop" "htop"
    "procs" "delta" "colordiff" "sd" "httpie" "curlie" "gping" "dog"
    "tldr" "zoxide" "duf" "hexyl" "just" "xh" "hyperfine" "mcfly"
    "atuin" "glow" "tokei" "broot" "mtr" "zellij"
]

# ============================================================================
# Helper functions
# ============================================================================

def _ysu_is_ignored_command [cmd: string] {
    let ignored = ($env.YSU_IGNORE_COMMANDS | split row " " | where { |it| $it != "" })
    $cmd in $ignored
}

def _ysu_is_ignored_alias [name: string] {
    let ignored = ($env.YSU_IGNORE_ALIASES | split row " " | where { |it| $it != "" })
    $name in $ignored
}

def _ysu_reminder_roll [key: string] {
    # Fast path: no half-life configured — always show
    if $env.YSU_REMINDER_HALFLIFE <= 0 {
        return true
    }

    let cache_dir = $env.YSU_LLM_CACHE_DIR
    # Simple hash: use string length + first/last chars as key
    let key_hash = ($key | hash md5)
    let seen_file = $"($cache_dir)/.seen_($key_hash)"

    if ($seen_file | path exists) {
        let last_shown = (open $seen_file | str trim | into int)
        let now = (date now | into int) / 1_000_000_000
        let elapsed = $now - $last_shown

        # Linear ramp: 0% at t=0, 100% at t=halflife
        let prob = [100, ($elapsed * 100 / $env.YSU_REMINDER_HALFLIFE)] | math min
        let rand = (random int 1..100)
        if $rand > $prob {
            return false
        }
    }

    # Will show — update timestamp
    mkdir ($cache_dir)
    let now = (date now | into int) / 1_000_000_000 | into string
    $now | save -f $seen_file
    true
}

def _ysu_should_show [] {
    # Probability check
    if $env.YSU_PROBABILITY < 100 {
        let r = (random int 1..100)
        if $r > $env.YSU_PROBABILITY {
            return false
        }
    }
    # Cooldown check
    if $env.YSU_COOLDOWN > 0 {
        let now = (date now | into int) / 1_000_000_000
        let elapsed = $now - $env._YSU_LAST_TIP_TIME
        if $elapsed < $env.YSU_COOLDOWN {
            return false
        }
    }
    true
}

def _ysu_format [prefix: string, message: string] {
    let arrow = "→"
    let full_prefix = if $prefix != "" {
        $"($env.YSU_PREFIX) ($prefix)"
    } else {
        $env.YSU_PREFIX
    }
    $env.YSU_MESSAGE_FORMAT
        | str replace "{prefix}" $full_prefix
        | str replace "{arrow}" $arrow
        | str replace "{message}" $message
}

def _ysu_get_install_cmd [tool: string] {
    if $env._YSU_PKG_INSTALL == "" {
        return ""
    }
    let pkg = (_ysu_get_pkg_name $tool)
    $"($env._YSU_PKG_INSTALL) ($pkg)"
}

# ============================================================================
# Feature 1: Alias reminders
# ============================================================================

def _ysu_check_aliases [typed_command: string] {
    if not $env.YSU_REMINDER_ENABLED { return }
    if not (_ysu_should_show) { return }

    let cmd = $typed_command | str trim
    if ($cmd | is-empty) { return }

    # Get all aliases
    let aliases = (scope aliases)
    mut best_match = ""
    mut best_alias = ""

    for alias_def in $aliases {
        let name = $alias_def.name
        let expansion = $alias_def.expansion

        (_ysu_is_ignored_alias $name) | if $in { continue }

        # Check if typed command starts with alias expansion
        if ($cmd | str starts-with $expansion) {
            # Prefer longer match
            if ($expansion | str length) > ($best_match | str length) {
                $best_match = $expansion
                $best_alias = $name
            }
        }
    }

    if $best_alias != "" {
        let first_word = ($cmd | split row " " | first)
        if not (_ysu_reminder_roll $first_word) { return }
        let msg = _ysu_format $env.YSU_REMINDER_PREFIX $"Use alias ($env._YSU_C_HIGHLIGHT)($best_alias)($env._YSU_C_RESET) instead of ($env._YSU_C_COMMAND)($best_match)($env._YSU_C_RESET)"
        print $msg
        $env._YSU_CMD_HAD_TIPS = true
    }
}

# ============================================================================
# Feature 2: Modern command suggestions
# ============================================================================

def _ysu_check_modern [typed_command: string] {
    if not $env.YSU_SUGGEST_ENABLED { return }

    let cmd = $typed_command | str trim
    if ($cmd | is-empty) { return }

    # Strip sudo prefix
    let cmd = if ($cmd | str starts-with "sudo ") {
        $cmd | str replace -r "^sudo +" ""
    } else {
        $cmd
    }

    let first_word = ($cmd | split row " " | first)

    if (_ysu_is_ignored_command $first_word) { return }

    # Look up in modern commands mapping
    if not ($first_word in $YSU_MODERN_COMMANDS) { return }

    let mapping = ($YSU_MODERN_COMMANDS | get $first_word)
    let alternatives = ($mapping | split row "|")

    mut first_uninstalled = ""
    mut first_uninstalled_desc = ""

    for entry in $alternatives {
        let parts = ($entry | split row ":" -n 2)
        let modern_cmd = $parts.0
        let description = (if ($parts | length) > 1 { $parts.1 } else { "" })

        if (which $modern_cmd | length) > 0 {
            if not (_ysu_reminder_roll $first_word) { return }
            let msg = _ysu_format $env.YSU_SUGGEST_PREFIX $"You should use ($env._YSU_C_HIGHLIGHT)($modern_cmd)($env._YSU_C_RESET) instead of ($env._YSU_C_COMMAND)($first_word)($env._YSU_C_RESET) — ($env._YSU_C_DIM)($description)($env._YSU_C_RESET)"
            print $msg
            $env._YSU_CMD_HAD_TIPS = true
            return
        } else if $first_uninstalled == "" {
            $first_uninstalled = $modern_cmd
            $first_uninstalled_desc = $description
        }
    }

    # Show install hint for first uninstalled alternative
    if $env.YSU_INSTALL_HINT and $first_uninstalled != "" {
        let install_cmd = (_ysu_get_install_cmd $first_uninstalled)
        if $install_cmd != "" {
            if not (_ysu_reminder_roll $first_word) { return }
            let msg = _ysu_format $env.YSU_SUGGEST_PREFIX $"Try ($env._YSU_C_HIGHLIGHT)($first_uninstalled)($env._YSU_C_RESET) instead of ($env._YSU_C_COMMAND)($first_word)($env._YSU_C_RESET) — ($env._YSU_C_DIM)($first_uninstalled_desc)($env._YSU_C_RESET) \(install: ($env._YSU_C_HINT)($install_cmd)($env._YSU_C_RESET)\)"
            print $msg
            $env._YSU_CMD_HAD_TIPS = true
        }
    }
}

# ============================================================================
# Pre-execution hook
# ============================================================================

def _ysu_preexec [cmd: string] {
    # Bail out if plugin is disabled
    if $env.YSU_DISABLED == true { return }

    $env._YSU_CMD_HAD_TIPS = false
    _ysu_check_aliases $cmd
    _ysu_check_modern $cmd
}

# ============================================================================
# Hook registration
# ============================================================================

# Register hooks by merging with existing config
$env.config = ($env.config | upsert hooks ($env.config.hooks? | default {} | upsert pre_execution (
    ($env.config.hooks?.pre_execution? | default []) | append {|cmd|
        _ysu_preexec ($cmd | get -i commandline | default "")
    }
)))

# ============================================================================
# ysu command
# ============================================================================

def "ysu status" [] {
    let check = $"($env._YSU_C_OK)✓($env._YSU_C_RESET)"
    let cross = $"($env._YSU_C_ERR)✗($env._YSU_C_RESET)"

    print ""
    print $"($env._YSU_C_BOLD)📊 you-should-use status($env._YSU_C_RESET)"
    print "─────────────────────────"

    print $"($env._YSU_C_BOLD)Core Settings:($env._YSU_C_RESET)"
    if $env.YSU_DISABLED {
        print $"  Plugin:             ($cross) disabled (YSU_DISABLED=true)"
    }
    print $"  Alias Reminders:    (if $env.YSU_REMINDER_ENABLED { $'($check) enabled' } else { $'($cross) disabled' })"
    print $"  Modern Suggestions: (if $env.YSU_SUGGEST_ENABLED { $'($check) enabled' } else { $'($cross) disabled' })"
    print $"  Prefix:             \"($env.YSU_PREFIX)\""
    print $"  Probability:        ($env.YSU_PROBABILITY)%"
    if $env.YSU_REMINDER_HALFLIFE > 0 {
        print $"  Reminder Halflife:  ($env.YSU_REMINDER_HALFLIFE)s"
    }
    print $"  Cooldown:           ($env.YSU_COOLDOWN)s"
    print $"  Install Hints:      (if $env.YSU_INSTALL_HINT { $'($check) enabled' } else { $'($cross) disabled' })"
    print $"  Package Manager:    ($env._YSU_PKG_MANAGER)"
    print ""

    print $"($env._YSU_C_BOLD)LLM Settings:($env._YSU_C_RESET)"
    print $"  Enabled:            (if $env.YSU_LLM_ENABLED { $'($check) enabled' } else { $'($cross) disabled' })"
    print $"  API URL:            ($env.YSU_LLM_API_URL)"
    print $"  Model:              ($env.YSU_LLM_MODEL)"
    print $"  Mode:               ($env.YSU_LLM_MODE)"
    print ""

    print $"($env._YSU_C_BOLD)Statistics:($env._YSU_C_RESET)"
    let alias_count = (scope aliases | length)
    let modern_count = ($YSU_MODERN_COMMANDS | columns | length)
    print $"  Aliases defined:    ($alias_count)"
    print $"  Modern mappings:    ($modern_count)"
    print ""
}

def "ysu doctor" [] {
    let check = $"($env._YSU_C_OK)✓($env._YSU_C_RESET)"
    let cross = $"($env._YSU_C_ERR)✗($env._YSU_C_RESET)"
    let warn = $"($env._YSU_C_HINT)!($env._YSU_C_RESET)"
    mut issues = 0

    print ""
    print $"($env._YSU_C_BOLD)🩺 you-should-use doctor($env._YSU_C_RESET)"
    print "─────────────────────────"

    # Shell
    print $"($env._YSU_C_BOLD)Shell:($env._YSU_C_RESET)"
    print $"  ($check) Nushell (version)"

    # Plugin
    print ""
    print $"($env._YSU_C_BOLD)Plugin:($env._YSU_C_RESET)"
    print $"  ($check) Plugin loaded"

    # Config
    print ""
    print $"($env._YSU_C_BOLD)Config:($env._YSU_C_RESET)"
    if $env.YSU_PROBABILITY < 1 or $env.YSU_PROBABILITY > 100 {
        print $"  ($cross) YSU_PROBABILITY=($env.YSU_PROBABILITY) — must be 1-100"
        $issues = $issues + 1
    } else {
        print $"  ($check) YSU_PROBABILITY=($env.YSU_PROBABILITY)"
    }
    if $env.YSU_REMINDER_HALFLIFE < 0 {
        print $"  ($cross) YSU_REMINDER_HALFLIFE=($env.YSU_REMINDER_HALFLIFE) — must be >= 0"
        $issues = $issues + 1
    }

    # Package manager
    print ""
    print $"($env._YSU_C_BOLD)Package Manager:($env._YSU_C_RESET)"
    if $env._YSU_PKG_MANAGER != "unknown" {
        print $"  ($check) Detected: ($env._YSU_PKG_MANAGER)"
    } else {
        print $"  ($warn) No package manager detected"
        $issues = $issues + 1
    }

    # LLM
    print ""
    print $"($env._YSU_C_BOLD)LLM:($env._YSU_C_RESET)"
    if $env.YSU_LLM_ENABLED {
        print $"  ($check) LLM enabled"
        if (which curl | length) > 0 {
            print $"  ($check) curl available"
        } else {
            print $"  ($cross) curl not found (required for LLM)"
            $issues = $issues + 1
        }
    } else {
        print "  LLM disabled (not tested)"
    }

    # Dependencies
    print ""
    print $"($env._YSU_C_BOLD)Dependencies:($env._YSU_C_RESET)"
    for dep in ["curl" "jq"] {
        if (which $dep | length) > 0 {
            print $"  ($check) ($dep)"
        } else {
            if $dep == "jq" {
                print $"  ($warn) ($dep) (optional)"
            } else {
                print $"  ($cross) ($dep)"
                $issues = $issues + 1
            }
        }
    }

    print ""
    if $issues == 0 {
        print $"($env._YSU_C_OK)($env._YSU_C_BOLD)No issues found!($env._YSU_C_RESET)"
    } else {
        print $"($env._YSU_C_HINT)($issues) issue\(s\) found($env._YSU_C_RESET)"
    }
    print ""
}

def "ysu discover" [min_count?: int] {
    let min_count = ($min_count | default 5)

    print ""
    print $"($env._YSU_C_BOLD)🔍 Alias Discovery($env._YSU_C_RESET)"
    print "─────────────────────────"
    print $"Analyzing history for commands used >= ($min_count) times..."
    print ""

    # Nushell history
    let hist = (history | get command)
    if ($hist | length) == 0 {
        print "No history entries found."
        return
    }

    # Count 2-word prefixes
    let prefixes = ($hist
        | each { |cmd|
            let words = ($cmd | split row " " | where { |w| $w != "" })
            if ($words | length) >= 2 {
                $"($words.0) ($words.1)"
            } else {
                null
            }
        }
        | compact
        | where { |p| not ($p | str starts-with "_ysu_") and not ($p | str starts-with "cd ") }
        | uniq -c
        | where { |r| $r.count >= $min_count }
        | sort-by count -r
    )

    # Get existing aliases
    let existing = (scope aliases | get name)

    mut found = 0
    for entry in $prefixes {
        let prefix = $entry.value
        let count = $entry.count

        # Generate alias name
        let words = ($prefix | split row " " | where { |w| not ($w | str starts-with "-") })
        let suggestion = ($words | each { |w| $w | str substring 0..1 } | str join "" | str downcase)

        if $suggestion in $existing { continue }

        print $"  ($env._YSU_C_COMMAND)($prefix)($env._YSU_C_RESET)  \(used ($env._YSU_C_HINT)($count)($env._YSU_C_RESET) times\)"
        print $"    ($env._YSU_C_OK)alias ($suggestion) = \"($prefix)\"($env._YSU_C_RESET)"
        print ""
        $found = $found + 1
        if $found >= 30 { break }
    }

    if $found == 0 {
        print "No alias suggestions found. Try: ysu discover 3"
    }
    print ""
}

def "ysu cache clear" [] {
    let cache_dir = $env.YSU_LLM_CACHE_DIR
    if ($cache_dir | path exists) {
        glob $"($cache_dir)/*" $"($cache_dir)/.*" | where { |f| ($f | path type) == "file" } | each { |f| rm $f } | ignore
        print "LLM cache cleared."
    } else {
        print "Cache directory does not exist."
    }
}

def "ysu cache size" [] {
    let cache_dir = $env.YSU_LLM_CACHE_DIR
    if ($cache_dir | path exists) {
        let count = (ls $cache_dir | where { |f| not ($f.name | str starts-with ".") } | length)
        print $"($count) cached suggestions"
    } else {
        print "0 cached suggestions"
    }
}

# Main ysu command
def ysu [] {
    print "Usage: ysu <command>"
    print "Commands:"
    print "  status    Show current configuration and statistics"
    print "  doctor    Run diagnostics and check for issues"
    print "  discover  Analyze history and suggest aliases"
    print "  cache     Manage LLM suggestion cache"
}
