# zsh-smart-alias

A Zsh plugin that helps you work smarter by:

1. **Alias Reminders** - When you type a full command that has an alias defined, it reminds you to use the alias
2. **Modern Command Suggestions** - When you use legacy commands (cat, ls, find, grep, etc.), it suggests modern Rust/Go alternatives if they're installed

## Demo

```
$ git status
💡 Use alias gs instead of git status

$ cat README.md
💡 Try bat instead of cat — Syntax highlighting, line numbers, git integration

$ find . -name "*.js"
💡 Try fd instead of find — Simpler syntax, faster, respects .gitignore
```

## Installation

### oh-my-zsh

```bash
git clone https://github.com/vangie/zsh-smart-alias ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-smart-alias
```

Then add `zsh-smart-alias` to your plugins in `~/.zshrc`:

```bash
plugins=(... zsh-smart-alias)
```

### zinit

```bash
zinit light vangie/zsh-smart-alias
```

### zplug

```bash
zplug "vangie/zsh-smart-alias"
```

### Antidote

Add to your `.zsh_plugins.txt`:

```
vangie/zsh-smart-alias
```

### Manual

```bash
git clone https://github.com/vangie/zsh-smart-alias ~/.zsh-smart-alias
echo 'source ~/.zsh-smart-alias/zsh-smart-alias.plugin.zsh' >> ~/.zshrc
```

## Configuration

All configuration is done via environment variables. Set them in your `.zshrc` **before** the plugin is loaded.

### Feature Toggles

```bash
ZSH_SMART_ALIAS_REMINDER_ENABLED=true    # Enable alias reminders (default: true)
ZSH_SMART_ALIAS_SUGGEST_ENABLED=true     # Enable modern tool suggestions (default: true)
```

### Display

```bash
ZSH_SMART_ALIAS_COLOR=yellow             # Message color (default: yellow)
# Options: black, red, green, yellow, blue, magenta, cyan, white

ZSH_SMART_ALIAS_PREFIX="💡"               # Prefix for all messages
ZSH_SMART_ALIAS_REMINDER_PREFIX=""        # Extra prefix for alias reminders
ZSH_SMART_ALIAS_SUGGEST_PREFIX=""         # Extra prefix for tool suggestions
```

### Frequency Control

Avoid being too intrusive with these settings:

```bash
ZSH_SMART_ALIAS_PROBABILITY=50           # Show tips 50% of the time (default: 100)
ZSH_SMART_ALIAS_COOLDOWN=30              # Minimum 30 seconds between tips (default: 0)
```

### Exclusions

```bash
ZSH_SMART_ALIAS_IGNORE_ALIASES="g gc"    # Don't remind about these aliases
ZSH_SMART_ALIAS_IGNORE_COMMANDS="cat ls" # Don't suggest alternatives for these
```

### Custom Modern Command Mappings

Override or extend the default mappings. Format: `command "alternative:description"`.

```bash
typeset -gA ZSH_SMART_ALIAS_MODERN_COMMANDS
ZSH_SMART_ALIAS_MODERN_COMMANDS=(
  cat    "bat:Syntax highlighting, line numbers, git integration"
  ls     "eza:Modern file listing with icons, git status, tree view"
  find   "fd:Simpler syntax, faster, respects .gitignore"
  grep   "rg:Ripgrep - faster, respects .gitignore, better defaults"
  du     "dust:Intuitive disk usage with visual chart"
  top    "btop:Beautiful resource monitor with mouse support"
  ps     "procs:Modern process viewer with tree display"
  diff   "delta:Syntax highlighting, side-by-side view, git integration"
  sed    "sd:Simpler syntax, uses regex by default"
  curl   "httpie:Human-friendly HTTP client (command: http)"
  ping   "gping:Ping with a graph"
  dig    "dog:DNS client with colorful output"
  man    "tldr:Simplified, community-driven man pages"
  cd     "zoxide:Smarter cd that learns your habits (command: z)"
  vim    "nvim:Neovim - modernized Vim fork"
)
```

## Default Modern Command Mappings

| Legacy Command | Modern Alternative | Description |
|---|---|---|
| `cat` | `bat` | Syntax highlighting, line numbers, git integration |
| `ls` | `eza` | Modern file listing with icons, git status, tree view |
| `find` | `fd` | Simpler syntax, faster, respects .gitignore |
| `grep` | `rg` | Ripgrep - faster, respects .gitignore |
| `du` | `dust` | Intuitive disk usage with visual chart |
| `top` | `btop` | Beautiful resource monitor with mouse support |
| `ps` | `procs` | Modern process viewer with tree display |
| `diff` | `delta` | Syntax highlighting, side-by-side view |
| `sed` | `sd` | Simpler syntax, uses regex by default |
| `curl` | `httpie` | Human-friendly HTTP client |
| `ping` | `gping` | Ping with a graph |
| `dig` | `dog` | DNS client with colorful output |
| `man` | `tldr` | Simplified, community-driven man pages |
| `cd` | `zoxide` | Smarter cd that learns your habits |

> **Note:** Suggestions only appear when the modern alternative is actually installed on your system.

## How It Works

The plugin hooks into Zsh's `preexec` function, which runs just before each command is executed. It:

1. Checks if you typed a command that matches an existing alias expansion (alias reminder)
2. Checks if the command has a known modern alternative that is installed (tool suggestion)

Both checks respect the probability and cooldown settings to avoid being annoying.

## Comparison with Similar Projects

| Feature | zsh-smart-alias | [you-should-use](https://github.com/MichaelAquilina/zsh-you-should-use) |
|---|---|---|
| Alias reminders | Yes | Yes |
| Modern tool suggestions | Yes | No |
| Cooldown timer | Yes | No |
| Probability control | Yes | No |
| Custom mappings | Yes | N/A |

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Feel free to:

- Add new modern command mappings
- Improve alias matching logic
- Add support for more plugin managers
- Fix bugs or improve documentation

Please open an issue or pull request on GitHub.
