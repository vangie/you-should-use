# you-should-use

A shell plugin that helps you work smarter by:

1. **Alias Reminders** — When you type a full command that has an alias defined, it reminds you to use the alias
2. **Modern Command Suggestions** — When you use legacy commands (cat, ls, find, grep, etc.), it suggests modern Rust/Go alternatives if they're installed

> Currently supports **Zsh** and **Fish**. Bash support is planned.

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

### Manual (Zsh)

```bash
git clone https://github.com/vangie/you-should-use ~/.you-should-use
echo 'source ~/.you-should-use/you-should-use.plugin.zsh' >> ~/.zshrc
```

### Fish

#### Using Fisher

```fish
fisher install vangie/you-should-use
```

#### Using Oh My Fish

```fish
omf install https://github.com/vangie/you-should-use
```

#### Manual (Fish)

```fish
git clone https://github.com/vangie/you-should-use ~/.you-should-use
cp ~/.you-should-use/conf.d/you-should-use.fish ~/.config/fish/conf.d/
```

## Configuration

All configuration is done via environment variables. Set them in your shell config **before** the plugin is loaded.

### Feature Toggles

```bash
YSU_REMINDER_ENABLED=true    # Enable alias reminders (default: true)
YSU_SUGGEST_ENABLED=true     # Enable modern tool suggestions (default: true)
```

### Display

```bash
YSU_COLOR=yellow             # Message color (default: yellow)
# Options: black, red, green, yellow, blue, magenta, cyan, white

YSU_PREFIX="💡"               # Prefix for all messages
YSU_REMINDER_PREFIX=""        # Extra prefix for alias reminders
YSU_SUGGEST_PREFIX=""         # Extra prefix for tool suggestions
```

### Frequency Control

Avoid being too intrusive with these settings:

```bash
YSU_PROBABILITY=50           # Show tips 50% of the time (default: 100)
YSU_COOLDOWN=30              # Minimum 30 seconds between tips (default: 0)
```

### Exclusions

```bash
YSU_IGNORE_ALIASES="g gc"    # Don't remind about these aliases
YSU_IGNORE_COMMANDS="cat ls" # Don't suggest alternatives for these
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

The plugin hooks into the shell's pre-execution mechanism (`preexec` in Zsh, `fish_preexec` event in Fish) to intercept commands before they run. It:

1. Checks if you typed a command that matches an existing alias expansion (alias reminder)
2. Checks if the command has a known modern alternative that is installed (tool suggestion)

Both checks respect the probability and cooldown settings to avoid being annoying.

## Roadmap

- [x] Zsh support
- [x] Fish support
- [ ] Bash support

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Feel free to:

- Add new modern command mappings
- Improve alias matching logic
- Add support for more shells or plugin managers
- Fix bugs or improve documentation

Please open an issue or pull request on GitHub.
