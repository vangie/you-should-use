# =============================================================================
# zsh-smart-alias configuration example
# Add these lines to your .zshrc BEFORE sourcing the plugin
# =============================================================================

# --- Feature toggles ---
# ZSH_SMART_ALIAS_REMINDER_ENABLED=true    # Enable alias reminders (default: true)
# ZSH_SMART_ALIAS_SUGGEST_ENABLED=true     # Enable modern tool suggestions (default: true)

# --- Display ---
# ZSH_SMART_ALIAS_COLOR=yellow             # Message color (default: yellow)
# ZSH_SMART_ALIAS_PREFIX="💡"               # Prefix for messages (default: 💡)

# --- Frequency control ---
# ZSH_SMART_ALIAS_PROBABILITY=50           # Show tips 50% of the time (default: 100)
# ZSH_SMART_ALIAS_COOLDOWN=30              # Wait 30s between tips (default: 0)

# --- Exclusions ---
# ZSH_SMART_ALIAS_IGNORE_ALIASES="g gc"    # Don't remind about these aliases
# ZSH_SMART_ALIAS_IGNORE_COMMANDS="cat ls"  # Don't suggest alternatives for these

# --- Custom modern command mappings ---
# Override or extend the default mappings:
# typeset -gA ZSH_SMART_ALIAS_MODERN_COMMANDS
# ZSH_SMART_ALIAS_MODERN_COMMANDS=(
#   cat   "bat:Syntax highlighting and line numbers"
#   ls    "eza:Modern file listing with icons"
#   find  "fd:Simpler syntax, faster"
#   grep  "rg:Ripgrep - faster grep"
#   vim   "nvim:Neovim - modernized Vim"
# )
