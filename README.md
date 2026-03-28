# you-should-use

A shell plugin that helps you work smarter by:

1. **Alias Reminders** — When you type a full command that has an alias defined, it reminds you to use the alias
2. **Modern Command Suggestions** — When you use legacy commands (cat, ls, find, grep, etc.), it suggests modern Rust/Go alternatives if they're installed
3. **AI-Powered Suggestions** — Uses a local LLM (via Ollama) to suggest better ways to write your commands

> Currently supports **Zsh** and **Fish**. Bash support is planned.

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
YSU_LLM_ENABLED=true         # Enable AI-powered suggestions (default: false, auto-detected with Ollama)
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

### LLM Settings

Configure the AI-powered suggestion engine. Works with any OpenAI-compatible API (Ollama, OpenAI, etc.).

```bash
YSU_LLM_API_URL="http://localhost:11434/v1"  # API endpoint (default: Ollama)
YSU_LLM_MODEL="auto"                          # Model name or "auto" (picks first available)
YSU_LLM_API_KEY=""                             # API key (not needed for Ollama)
```

> **Ollama Auto-Detection:** If [Ollama](https://ollama.com) is running locally, the plugin automatically enables LLM suggestions — no configuration needed.

## Commands

```bash
ysu status    # Show current configuration and statistics
ysu config    # Interactive configuration wizard
ysu cache     # Manage LLM suggestion cache (clear, size)
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
3. Sends complex commands to a local LLM for intelligent rewrite suggestions (async, cached)

All checks respect the probability and cooldown settings to avoid being annoying. LLM suggestions run asynchronously and display on the next prompt to avoid slowing down your workflow.

## Roadmap

- [x] Zsh support
- [x] Fish support
- [x] AI-powered suggestions (Ollama / OpenAI)
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
