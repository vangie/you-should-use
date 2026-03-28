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

$env.YSU_REMINDER_ENABLED = ($env.YSU_REMINDER_ENABLED? | default true)
$env.YSU_SUGGEST_ENABLED = ($env.YSU_SUGGEST_ENABLED? | default true)
$env.YSU_LLM_ENABLED = ($env.YSU_LLM_ENABLED? | default false)
$env.YSU_PREFIX = ($env.YSU_PREFIX? | default "💡")
$env.YSU_REMINDER_PREFIX = ($env.YSU_REMINDER_PREFIX? | default "")
$env.YSU_SUGGEST_PREFIX = ($env.YSU_SUGGEST_PREFIX? | default "")
$env.YSU_LLM_PREFIX = ($env.YSU_LLM_PREFIX? | default "🤖")
$env.YSU_PROBABILITY = ($env.YSU_PROBABILITY? | default 100)
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
        let msg = _ysu_format $env.YSU_REMINDER_PREFIX $"Use alias (ansi red_bold)($best_alias)(ansi reset) instead of (ansi cyan_bold)($best_match)(ansi reset)"
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
            let msg = _ysu_format $env.YSU_SUGGEST_PREFIX $"You should use (ansi red_bold)($modern_cmd)(ansi reset) instead of (ansi cyan_bold)($first_word)(ansi reset) — (ansi italic)($description)(ansi reset)"
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
            let msg = _ysu_format $env.YSU_SUGGEST_PREFIX $"Try (ansi red_bold)($first_uninstalled)(ansi reset) instead of (ansi cyan_bold)($first_word)(ansi reset) — (ansi italic)($first_uninstalled_desc)(ansi reset) \(install: (ansi yellow_bold)($install_cmd)(ansi reset)\)"
            print $msg
            $env._YSU_CMD_HAD_TIPS = true
        }
    }
}

# ============================================================================
# Pre-execution hook
# ============================================================================

def _ysu_preexec [cmd: string] {
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
    let check = $"(ansi green)✓(ansi reset)"
    let cross = $"(ansi red)✗(ansi reset)"

    print ""
    print $"(ansi attr_bold)📊 you-should-use status(ansi reset)"
    print "─────────────────────────"

    print $"(ansi attr_bold)Core Settings:(ansi reset)"
    print $"  Alias Reminders:    (if $env.YSU_REMINDER_ENABLED { $'($check) enabled' } else { $'($cross) disabled' })"
    print $"  Modern Suggestions: (if $env.YSU_SUGGEST_ENABLED { $'($check) enabled' } else { $'($cross) disabled' })"
    print $"  Prefix:             \"($env.YSU_PREFIX)\""
    print $"  Probability:        ($env.YSU_PROBABILITY)%"
    print $"  Cooldown:           ($env.YSU_COOLDOWN)s"
    print $"  Install Hints:      (if $env.YSU_INSTALL_HINT { $'($check) enabled' } else { $'($cross) disabled' })"
    print $"  Package Manager:    ($env._YSU_PKG_MANAGER)"
    print ""

    print $"(ansi attr_bold)LLM Settings:(ansi reset)"
    print $"  Enabled:            (if $env.YSU_LLM_ENABLED { $'($check) enabled' } else { $'($cross) disabled' })"
    print $"  API URL:            ($env.YSU_LLM_API_URL)"
    print $"  Model:              ($env.YSU_LLM_MODEL)"
    print $"  Mode:               ($env.YSU_LLM_MODE)"
    print ""

    print $"(ansi attr_bold)Statistics:(ansi reset)"
    let alias_count = (scope aliases | length)
    let modern_count = ($YSU_MODERN_COMMANDS | columns | length)
    print $"  Aliases defined:    ($alias_count)"
    print $"  Modern mappings:    ($modern_count)"
    print ""
}

def "ysu doctor" [] {
    let check = $"(ansi green)✓(ansi reset)"
    let cross = $"(ansi red)✗(ansi reset)"
    let warn = $"(ansi yellow_bold)!(ansi reset)"
    mut issues = 0

    print ""
    print $"(ansi attr_bold)🩺 you-should-use doctor(ansi reset)"
    print "─────────────────────────"

    # Shell
    print $"(ansi attr_bold)Shell:(ansi reset)"
    print $"  ($check) Nushell (version)"

    # Plugin
    print ""
    print $"(ansi attr_bold)Plugin:(ansi reset)"
    print $"  ($check) Plugin loaded"

    # Config
    print ""
    print $"(ansi attr_bold)Config:(ansi reset)"
    if $env.YSU_PROBABILITY < 1 or $env.YSU_PROBABILITY > 100 {
        print $"  ($cross) YSU_PROBABILITY=($env.YSU_PROBABILITY) — must be 1-100"
        $issues = $issues + 1
    } else {
        print $"  ($check) YSU_PROBABILITY=($env.YSU_PROBABILITY)"
    }

    # Package manager
    print ""
    print $"(ansi attr_bold)Package Manager:(ansi reset)"
    if $env._YSU_PKG_MANAGER != "unknown" {
        print $"  ($check) Detected: ($env._YSU_PKG_MANAGER)"
    } else {
        print $"  ($warn) No package manager detected"
        $issues = $issues + 1
    }

    # LLM
    print ""
    print $"(ansi attr_bold)LLM:(ansi reset)"
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
    print $"(ansi attr_bold)Dependencies:(ansi reset)"
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
        print $"(ansi green)(ansi attr_bold)No issues found!(ansi reset)"
    } else {
        print $"(ansi yellow_bold)($issues) issue\(s\) found(ansi reset)"
    }
    print ""
}

def "ysu discover" [min_count?: int] {
    let min_count = ($min_count | default 5)

    print ""
    print $"(ansi attr_bold)🔍 Alias Discovery(ansi reset)"
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

        print $"  (ansi cyan_bold)($prefix)(ansi reset)  \(used (ansi yellow_bold)($count)(ansi reset) times\)"
        print $"    (ansi green)alias ($suggestion) = \"($prefix)\"(ansi reset)"
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
        rm -rf $"($cache_dir)/*" | ignore
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
