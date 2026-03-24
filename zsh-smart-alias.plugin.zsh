#!/usr/bin/env zsh
# zsh-smart-alias - Alias reminders & modern command suggestions for Zsh
# https://github.com/vangie/zsh-smart-alias
# MIT License

# ============================================================================
# Configuration (override these in your .zshrc BEFORE sourcing the plugin)
# ============================================================================

# Feature toggles
: ${ZSH_SMART_ALIAS_REMINDER_ENABLED:=true}
: ${ZSH_SMART_ALIAS_SUGGEST_ENABLED:=true}

# Display settings
: ${ZSH_SMART_ALIAS_COLOR:=yellow}           # Color for messages (black,red,green,yellow,blue,magenta,cyan,white)
: ${ZSH_SMART_ALIAS_PREFIX:="💡"}             # Prefix for all messages
: ${ZSH_SMART_ALIAS_REMINDER_PREFIX:=""}      # Additional prefix for alias reminders
: ${ZSH_SMART_ALIAS_SUGGEST_PREFIX:=""}       # Additional prefix for modern tool suggestions

# Frequency control
: ${ZSH_SMART_ALIAS_PROBABILITY:=100}         # Percentage chance to show a tip (1-100)
: ${ZSH_SMART_ALIAS_COOLDOWN:=0}              # Minimum seconds between tips (0 = no cooldown)

# Exclusions
: ${ZSH_SMART_ALIAS_IGNORE_ALIASES:=""}       # Space-separated list of aliases to ignore
: ${ZSH_SMART_ALIAS_IGNORE_COMMANDS:=""}      # Space-separated list of commands to ignore for suggestions

# ============================================================================
# Modern command alternatives mapping
# ============================================================================

typeset -gA ZSH_SMART_ALIAS_MODERN_COMMANDS

# Default mappings (user can override or extend)
if [[ ${#ZSH_SMART_ALIAS_MODERN_COMMANDS} -eq 0 ]]; then
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
  )
fi

# ============================================================================
# Internal state
# ============================================================================

typeset -g _ZSH_SMART_ALIAS_LAST_TIP_TIME=0

# ============================================================================
# Helper functions
# ============================================================================

_zsh_smart_alias_color() {
  local color=$1
  case $color in
    black)   echo "0" ;;
    red)     echo "1" ;;
    green)   echo "2" ;;
    yellow)  echo "3" ;;
    blue)    echo "4" ;;
    magenta) echo "5" ;;
    cyan)    echo "6" ;;
    white)   echo "7" ;;
    *)       echo "3" ;;  # default yellow
  esac
}

_zsh_smart_alias_print() {
  local color_code
  color_code=$(_zsh_smart_alias_color "$ZSH_SMART_ALIAS_COLOR")
  local prefix="$ZSH_SMART_ALIAS_PREFIX"
  [[ -n "$1" ]] && prefix="$prefix$1"
  echo -e "\e[3${color_code}m${prefix} $2\e[0m" >&2
}

_zsh_smart_alias_should_show() {
  # Check cooldown
  if [[ $ZSH_SMART_ALIAS_COOLDOWN -gt 0 ]]; then
    local now=$EPOCHSECONDS
    local elapsed=$(( now - _ZSH_SMART_ALIAS_LAST_TIP_TIME ))
    if [[ $elapsed -lt $ZSH_SMART_ALIAS_COOLDOWN ]]; then
      return 1
    fi
  fi

  # Check probability
  if [[ $ZSH_SMART_ALIAS_PROBABILITY -lt 100 ]]; then
    local rand=$(( RANDOM % 100 + 1 ))
    if [[ $rand -gt $ZSH_SMART_ALIAS_PROBABILITY ]]; then
      return 1
    fi
  fi

  return 0
}

_zsh_smart_alias_record_tip() {
  _ZSH_SMART_ALIAS_LAST_TIP_TIME=$EPOCHSECONDS
}

_zsh_smart_alias_is_ignored_alias() {
  local alias_name="$1"
  local ignored
  for ignored in ${(s: :)ZSH_SMART_ALIAS_IGNORE_ALIASES}; do
    [[ "$ignored" == "$alias_name" ]] && return 0
  done
  return 1
}

_zsh_smart_alias_is_ignored_command() {
  local cmd="$1"
  local ignored
  for ignored in ${(s: :)ZSH_SMART_ALIAS_IGNORE_COMMANDS}; do
    [[ "$ignored" == "$cmd" ]] && return 0
  done
  return 1
}

# ============================================================================
# Feature 1: Alias Reminders
# ============================================================================

_zsh_smart_alias_check_aliases() {
  [[ "$ZSH_SMART_ALIAS_REMINDER_ENABLED" != "true" ]] && return

  local typed_command="$1"
  local first_word="${typed_command%% *}"
  local found_alias=""
  local found_value=""

  # Check all defined aliases
  local alias_name alias_value
  for alias_name alias_value in ${(kv)aliases}; do
    _zsh_smart_alias_is_ignored_alias "$alias_name" && continue

    # Skip if the user already typed the alias
    [[ "$first_word" == "$alias_name" ]] && continue

    # Check if the typed command starts with the alias expansion
    if [[ "$typed_command" == "${alias_value}"* ]]; then
      # Prefer longer alias matches (more specific)
      if [[ -z "$found_value" ]] || [[ ${#alias_value} -gt ${#found_value} ]]; then
        found_alias="$alias_name"
        found_value="$alias_value"
      fi
    fi
  done

  # Also check global aliases
  for alias_name alias_value in ${(kv)galiases}; do
    _zsh_smart_alias_is_ignored_alias "$alias_name" && continue
    [[ "$first_word" == "$alias_name" ]] && continue
    if [[ "$typed_command" == *"${alias_value}"* ]]; then
      if [[ -z "$found_value" ]] || [[ ${#alias_value} -gt ${#found_value} ]]; then
        found_alias="$alias_name"
        found_value="$alias_value"
      fi
    fi
  done

  if [[ -n "$found_alias" ]]; then
    _zsh_smart_alias_print "$ZSH_SMART_ALIAS_REMINDER_PREFIX" \
      "Use alias \e[1m${found_alias}\e[0m\e[3${(_zsh_smart_alias_color $ZSH_SMART_ALIAS_COLOR)}m instead of \e[1m${found_value}\e[0m"
    _zsh_smart_alias_record_tip
  fi
}

# ============================================================================
# Feature 2: Modern Command Suggestions
# ============================================================================

_zsh_smart_alias_check_modern() {
  [[ "$ZSH_SMART_ALIAS_SUGGEST_ENABLED" != "true" ]] && return

  local typed_command="$1"
  local first_word="${typed_command%% *}"

  _zsh_smart_alias_is_ignored_command "$first_word" && return

  # Check if the command has a modern alternative
  local mapping="${ZSH_SMART_ALIAS_MODERN_COMMANDS[$first_word]}"
  [[ -z "$mapping" ]] && return

  local modern_cmd="${mapping%%:*}"
  local description="${mapping#*:}"

  # Only suggest if the modern tool is actually installed
  if command -v "$modern_cmd" &>/dev/null; then
    _zsh_smart_alias_print "$ZSH_SMART_ALIAS_SUGGEST_PREFIX" \
      "Try \e[1m${modern_cmd}\e[0m\e[3${(_zsh_smart_alias_color $ZSH_SMART_ALIAS_COLOR)}m instead of \e[1m${first_word}\e[0m — ${description}"
    _zsh_smart_alias_record_tip
  fi
}

# ============================================================================
# Hook into Zsh's preexec
# ============================================================================

_zsh_smart_alias_preexec() {
  local typed_command="$1"

  # Skip empty commands
  [[ -z "$typed_command" ]] && return

  # Check rate limiting
  _zsh_smart_alias_should_show || return

  # Run both checks
  _zsh_smart_alias_check_aliases "$typed_command"
  _zsh_smart_alias_check_modern "$typed_command"
}

# Register the preexec hook (append, don't overwrite)
autoload -Uz add-zsh-hook
add-zsh-hook preexec _zsh_smart_alias_preexec
