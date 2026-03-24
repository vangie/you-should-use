# =============================================================================
# zsh-you-should-use configuration example
# Add these lines to your .zshrc BEFORE sourcing the plugin
# =============================================================================

# --- Feature toggles ---
# YSU_REMINDER_ENABLED=true    # Enable alias reminders (default: true)
# YSU_SUGGEST_ENABLED=true     # Enable modern tool suggestions (default: true)

# --- Display ---
# YSU_COLOR=yellow             # Message color (default: yellow)
# YSU_PREFIX="💡"               # Prefix for messages (default: 💡)

# --- Frequency control ---
# YSU_PROBABILITY=50           # Show tips 50% of the time (default: 100)
# YSU_COOLDOWN=30              # Wait 30s between tips (default: 0)

# --- Exclusions ---
# YSU_IGNORE_ALIASES="g gc"    # Don't remind about these aliases
# YSU_IGNORE_COMMANDS="cat ls"  # Don't suggest alternatives for these

# --- Custom modern command mappings ---
# Override or extend the default mappings:
# typeset -gA YSU_MODERN_COMMANDS
# YSU_MODERN_COMMANDS=(
#   cat   "bat:Syntax highlighting and line numbers"
#   ls    "eza:Modern file listing with icons"
#   find  "fd:Simpler syntax, faster"
#   grep  "rg:Ripgrep - faster grep"
#   vim   "nvim:Neovim - modernized Vim"
# )
