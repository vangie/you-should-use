# =============================================================================
# you-should-use configuration example
# Add these lines to your .zshrc BEFORE sourcing the plugin
# =============================================================================

# --- Feature toggles ---
# YSU_REMINDER_ENABLED=true    # Enable alias reminders (default: true)
# YSU_SUGGEST_ENABLED=true     # Enable modern tool suggestions (default: true)

# --- Display ---
# YSU_PREFIX="💡"               # Prefix for messages (default: 💡)

# --- Theme ---
# YSU_THEME=dark                # "dark" (default), "light", or "custom"
#
# Built-in themes:
#   dark  — bright colors for dark terminal backgrounds (default)
#   light — adjusted colors for light terminal backgrounds
#   custom — uses only your YSU_COLOR_* overrides (falls back to dark)
#
# Individual color overrides (ANSI escape codes, work with any theme):
# YSU_COLOR_ARROW='\e[1;93m'      # Arrow symbol color
# YSU_COLOR_HIGHLIGHT='\e[1;31m'  # Recommended command (alias, modern tool)
# YSU_COLOR_COMMAND='\e[1;36m'    # Original command being replaced
# YSU_COLOR_DIM='\e[3m'           # Description text (italic)
# YSU_COLOR_HINT='\e[1;33m'       # Install hints, config prompts
# YSU_COLOR_OK='\e[32m'           # Success/enabled indicators
# YSU_COLOR_ERR='\e[31m'          # Error/disabled indicators
# YSU_COLOR_BOLD='\e[1m'          # Bold headings

# --- Message template ---
# YSU_MESSAGE_FORMAT="{prefix} {arrow} {message}"  # (default)
# YSU_MESSAGE_FORMAT="[{prefix}] {message}"        # No arrow
# YSU_MESSAGE_FORMAT="{message}"                     # Message only

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
