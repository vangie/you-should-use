# you-should-use

A shell plugin that helps you work smarter by:

1. **Alias Reminders** — When you type a full command that has an alias defined, it reminds you to use the alias
2. **Modern Command Suggestions** — When you use legacy commands (cat, ls, find, grep, etc.), it suggests modern Rust/Go alternatives if they're installed
3. **AI-Powered Suggestions** — Uses a local LLM (via Ollama) to suggest better ways to write your commands

> Supports **Zsh**, **Fish**, **Bash**, and **Nushell**.

## Demos

### Alias Reminders

Forgot you had an alias? The plugin gently reminds you.

[![asciicast](https://asciinema.org/a/876668.svg)](https://asciinema.org/a/876668)

### Modern Tool Suggestions

Still using `cat`, `find`, or `ls`? Get suggestions for modern alternatives.

[![asciicast](https://asciinema.org/a/876669.svg)](https://asciinema.org/a/876669)

### AI-Powered Suggestions

With Ollama running locally, get intelligent command rewrites.

[![asciicast](https://asciinema.org/a/876671.svg)](https://asciinema.org/a/876671)

### Status Dashboard

See your full configuration at a glance with `ysu status`.

[![asciicast](https://asciinema.org/a/876670.svg)](https://asciinema.org/a/876670)

## Quick Start

```bash
# Homebrew (macOS — recommended)
brew install vangie/formula/you-should-use

# Or one-line install (auto-detects your shell)
curl -fsSL https://raw.githubusercontent.com/vangie/you-should-use/main/install.sh | sh
```

Then follow the post-install instructions to add the source line to your shell config.

## Installation

### Homebrew (macOS)

```bash
brew install vangie/formula/you-should-use
```

Then add to your shell config as shown in the post-install message:

```bash
# Zsh (~/.zshrc)
source $(brew --prefix)/Cellar/you-should-use/*/you-should-use.plugin.zsh

# Bash (~/.bashrc)
source $(brew --prefix)/Cellar/you-should-use/*/you-should-use.plugin.bash

# Fish
ln -sf $(brew --prefix)/Cellar/you-should-use/*/conf.d/you-should-use.fish ~/.config/fish/conf.d/
```

### Install Script

```bash
curl -fsSL https://raw.githubusercontent.com/vangie/you-should-use/main/install.sh | sh
```

Auto-detects your shell (zsh/bash/fish), clones the repo, and adds the source line to your rc file.

### oh-my-zsh

```bash
git clone https://github.com/vangie/you-should-use ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use
```

Then add `you-should-use` to your plugins in `~/.zshrc`:

```bash
plugins=(... you-should-use)
```

### zinit

```bash
zinit light vangie/you-should-use
```

### zplug

```bash
zplug "vangie/you-should-use"
```

### Antidote

Add to your `.zsh_plugins.txt`:

```
vangie/you-should-use
```

### Fisher (Fish)

```fish
fisher install vangie/you-should-use
```

### Oh My Fish

```fish
omf install https://github.com/vangie/you-should-use
```

### Manual (Zsh)

```bash
git clone https://github.com/vangie/you-should-use ~/.you-should-use
echo 'source ~/.you-should-use/you-should-use.plugin.zsh' >> ~/.zshrc
```

### Manual (Fish)

```fish
git clone https://github.com/vangie/you-should-use ~/.you-should-use
ln -sf ~/.you-should-use/conf.d/you-should-use.fish ~/.config/fish/conf.d/
```

### Bash

```bash
git clone https://github.com/vangie/you-should-use ~/.you-should-use
echo 'source ~/.you-should-use/you-should-use.plugin.bash' >> ~/.bashrc
```

> **Note:** Requires Bash 3.2+. Uses `DEBUG` trap for pre-execution hooks and `PROMPT_COMMAND` for post-execution processing.

### Nushell

```nushell
git clone https://github.com/vangie/you-should-use ~/.you-should-use
```

Then add to your `config.nu` or `env.nu`:

```nushell
source ~/.you-should-use/you-should-use.plugin.nu
```

> **Note:** Requires Nushell >= 0.80. Uses `pre_execution` hooks. Nushell support is experimental.

## Managing the Plugin

```bash
ysu update      # Update to the latest version
ysu uninstall   # Remove from your system
```

These commands auto-detect your install method (Homebrew, oh-my-zsh, zinit, zplug, antidote, Fisher, Oh My Fish, or git clone) and provide the appropriate instructions.

## Configuration

All configuration is done via environment variables. Set them in your shell config **before** the plugin is loaded.

### Feature Toggles

```bash
YSU_DISABLED=true            # Disable the entire plugin (default: false)
YSU_REMINDER_ENABLED=true    # Enable alias reminders (default: true)
YSU_SUGGEST_ENABLED=true     # Enable modern tool suggestions (default: true)
YSU_LLM_ENABLED=true         # Enable AI-powered suggestions (default: false, auto-detected with Ollama)
```

Setting `YSU_DISABLED=true` silences all YSU output — alias reminders, modern suggestions, and LLM tips. You can toggle it dynamically without restarting your shell.

### Display

```bash
YSU_PREFIX="💡"               # Prefix for all messages
YSU_REMINDER_PREFIX=""        # Extra prefix for alias reminders
YSU_SUGGEST_PREFIX=""         # Extra prefix for tool suggestions
YSU_MESSAGE_FORMAT="{prefix} {arrow} {message}"  # Custom message template
```

The `YSU_MESSAGE_FORMAT` variable supports three placeholders:
- `{prefix}` — The combined prefix (YSU_PREFIX + feature-specific prefix)
- `{arrow}` — The colored arrow separator (➜)
- `{message}` — The actual suggestion text

Examples:
```bash
YSU_MESSAGE_FORMAT="[{prefix}] {message}"      # No arrow
YSU_MESSAGE_FORMAT="{message}"                   # Message only
YSU_MESSAGE_FORMAT="{prefix}: {arrow} {message}" # Custom separator
```

### Frequency Control

Avoid being too intrusive with these settings:

```bash
YSU_PROBABILITY=50           # Show tips 50% of the time (default: 100)
YSU_REMINDER_HALFLIFE=300    # Per-tip refractory period in seconds (default: 0)
YSU_COOLDOWN=30              # Minimum 30 seconds between tips (default: 0)
```

**Reminder Half-life**: When set, each specific tip enters a "refractory period" after being shown. The probability of showing the same tip again ramps linearly from 0% to 100% over the half-life duration. For example, with `YSU_REMINDER_HALFLIFE=300`, a tip that just fired has ~0% chance of showing again immediately, ~50% chance after 150 seconds, and 100% chance after 300 seconds. This prevents the same reminder (e.g., `make` → `just`) from being annoying on repeated use while still eventually reminding you. Set to `0` (default) to always show matching tips.

### Exclusions

```bash
YSU_IGNORE_ALIASES="g gc"    # Don't remind about these aliases
YSU_IGNORE_COMMANDS="cat ls" # Don't suggest alternatives for these
```

### Install Hints

When a modern tool alternative is not installed, the plugin can show the install command:

```bash
YSU_INSTALL_HINT=true         # Show install commands (default: true)
```

The plugin auto-detects your package manager (brew, apt, pacman, dnf, zypper, apk, pkg) and generates appropriate install commands. WSL is also detected.

Example output:
```
💡 ➜ Try bat instead of cat — Syntax highlighting, line numbers (install: brew install bat)
💡 ➜ Try bat instead of cat — Syntax highlighting, line numbers (install: sudo apt install bat)
```

You can customize the install commands mapping:

```bash
typeset -gA YSU_INSTALL_COMMANDS
YSU_INSTALL_COMMANDS=(
  bat    "brew install bat"
  eza    "cargo install eza"    # Override default
  myutil "pip install myutil"   # Add custom
)
```

### Custom Modern Command Mappings

Override or extend the default mappings. Use `|` to separate multiple alternatives — the first installed one is suggested.

```bash
typeset -gA YSU_MODERN_COMMANDS
YSU_MODERN_COMMANDS=(
  cat    "bat:Syntax highlighting, line numbers, git integration"
  ls     "eza:Modern file listing with icons|lsd:LSDeluxe - colorful ls with icons"
  find   "fd:Simpler syntax, faster, respects .gitignore"
  grep   "rg:Ripgrep - faster, respects .gitignore|ag:The Silver Searcher"
  vim    "nvim:Neovim - modernized Vim fork"
)
```

### LLM Settings

Configure the AI-powered suggestion engine. Works with any OpenAI-compatible API (Ollama, OpenAI, etc.).

```bash
YSU_LLM_API_URL="http://localhost:11434/v1"  # API endpoint (default: Ollama)
YSU_LLM_MODEL="auto"                          # Model name or "auto" (picks first available)
YSU_LLM_API_KEY=""                             # API key (not needed for Ollama)
YSU_LLM_MODE="single"                         # single, multi, or both
YSU_LLM_WINDOW_SIZE=5                          # Commands for multi-command analysis
```

#### Multi-Command Mode

In `multi` or `both` mode, the plugin analyzes your recent command history as a sliding window and suggests workflow optimizations:

```bash
YSU_LLM_MODE="both"          # Enable both single-command and multi-command analysis
YSU_LLM_WINDOW_SIZE=5        # Analyze the last 5 commands
```

- **single** — Analyze each command individually (default)
- **multi** — Only analyze command sequences (sliding window)
- **both** — Analyze both individual commands and sequences

> **Ollama Auto-Detection:** If [Ollama](https://ollama.com) is running locally, the plugin automatically enables LLM suggestions — no configuration needed.

## Commands

```bash
ysu status      # Show current configuration and statistics
ysu config      # Interactive configuration wizard
ysu cache       # Manage LLM suggestion cache (clear, size)
ysu doctor      # Run diagnostics and check for issues
ysu discover    # Analyze history and suggest aliases (optional: min count)
ysu update      # Update to the latest version
ysu uninstall   # Remove from your system
```

### ysu doctor

Runs comprehensive diagnostics:
- Shell version compatibility
- Hook registration status
- Plugin load time
- Config conflict detection
- Package manager detection
- LLM connection status
- Dependency checks

### ysu discover

Scans your shell history for frequently typed multi-word commands and suggests creating aliases:

```
$ ysu discover
  git checkout -b  (used 47 times)
    alias gc='git checkout -b'

  docker compose up  (used 23 times)
    alias dcu='docker compose up'
```

Pass a threshold to customize: `ysu discover 3` (default: 5).

## Default Modern Command Mappings

| Legacy Command | Modern Alternatives | Description |
|---|---|---|
| `cat` | `bat` | Syntax highlighting, line numbers, git integration |
| `ls` | `eza`, `lsd` | Modern file listing with icons, git status, tree view |
| `find` | `fd` | Simpler syntax, faster, respects .gitignore |
| `grep` | `rg`, `ag` | Ripgrep / Silver Searcher - faster, respects .gitignore |
| `du` | `dust`, `ncdu` | Intuitive disk usage with visual chart |
| `top` | `btop`, `htop` | Beautiful resource monitor with mouse support |
| `ps` | `procs` | Modern process viewer with tree display |
| `diff` | `delta`, `colordiff` | Syntax highlighting, side-by-side view |
| `sed` | `sd` | Simpler syntax, uses regex by default |
| `curl` | `httpie`, `curlie` | Human-friendly HTTP client |
| `ping` | `gping` | Ping with a graph |
| `dig` | `dog` | DNS client with colorful output |
| `man` | `tldr` | Simplified, community-driven man pages |
| `cd` | `zoxide` | Smarter cd that learns your habits |

> **Note:** Suggestions only appear when the modern alternative is actually installed on your system. When multiple alternatives are configured, the first installed one is suggested.

## How It Works

The plugin hooks into the shell's pre-execution mechanism (`preexec` in Zsh, `fish_preexec` event in Fish, `DEBUG` trap in Bash, `pre_execution` hook in Nushell) to intercept commands before they run. It:

1. Checks if you typed a command that matches an existing alias expansion (alias reminder)
2. Checks if the command has a known modern alternative that is installed (tool suggestion)
3. Sends complex commands to a local LLM for intelligent rewrite suggestions (async, cached)

All checks respect the probability and cooldown settings to avoid being annoying. LLM suggestions run asynchronously and display on the next prompt to avoid slowing down your workflow.

## Roadmap

- [x] Zsh support
- [x] Fish support
- [x] AI-powered suggestions (Ollama / OpenAI)
- [x] Install command hints
- [x] Custom message templates
- [x] Multi-command workflow analysis
- [x] Bash support
- [x] Platform-aware install hints (auto-detect OS)
- [x] Diagnostic command (`ysu doctor`)
- [x] Alias discovery (`ysu discover`)
- [x] Nushell support (experimental)
- [x] Homebrew formula and install script
- [x] Plugin lifecycle management (`ysu update`, `ysu uninstall`)

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Feel free to:

- Add new modern command mappings
- Improve alias matching logic
- Add support for more shells or plugin managers
- Fix bugs or improve documentation

Please open an issue or pull request on GitHub.
