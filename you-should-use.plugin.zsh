#!/usr/bin/env zsh
# you-should-use - Alias reminders & modern command suggestions
# https://github.com/vangie/you-should-use
# MIT License

# ============================================================================
# Configuration (override these in your .zshrc BEFORE sourcing the plugin)
# ============================================================================

# Feature toggles
: ${YSU_REMINDER_ENABLED:=true}
: ${YSU_SUGGEST_ENABLED:=true}

# Display settings
: ${YSU_COLOR:=yellow}           # Color for messages (black,red,green,yellow,blue,magenta,cyan,white)
: ${YSU_PREFIX:="💡"}             # Prefix for all messages
: ${YSU_REMINDER_PREFIX:=""}      # Additional prefix for alias reminders
: ${YSU_SUGGEST_PREFIX:=""}       # Additional prefix for modern tool suggestions

# Frequency control
: ${YSU_PROBABILITY:=100}         # Percentage chance to show a tip (1-100)
: ${YSU_COOLDOWN:=0}              # Minimum seconds between tips (0 = no cooldown)

# Exclusions
: ${YSU_IGNORE_ALIASES:=""}       # Space-separated list of aliases to ignore
: ${YSU_IGNORE_COMMANDS:=""}      # Space-separated list of commands to ignore for suggestions

# ============================================================================
# Modern command alternatives mapping
# ============================================================================

typeset -gA YSU_MODERN_COMMANDS

# Default mappings (user can override or extend)
# Format: command "alt1:description|alt2:description" (pipe-separated for multiple alternatives)
# The first installed alternative is suggested
if [[ ${#YSU_MODERN_COMMANDS} -eq 0 ]]; then
  YSU_MODERN_COMMANDS=(
    cat    "bat:Syntax highlighting, line numbers, git integration"
    ls     "eza:Modern file listing with icons, git status, tree view|lsd:LSDeluxe - colorful ls with icons"
    find   "fd:Simpler syntax, faster, respects .gitignore"
    grep   "rg:Ripgrep - faster, respects .gitignore, better defaults|ag:The Silver Searcher - fast code search"
    du     "dust:Intuitive disk usage with visual chart|ncdu:NCurses disk usage analyzer"
    top    "btop:Beautiful resource monitor with mouse support|htop:Interactive process viewer"
    ps     "procs:Modern process viewer with tree display"
    diff   "delta:Syntax highlighting, side-by-side view, git integration|colordiff:Colorized diff output"
    sed    "sd:Simpler syntax, uses regex by default"
    curl   "httpie:Human-friendly HTTP client (command: http)|curlie:Curl with httpie-like interface"
    ping   "gping:Ping with a graph"
    dig    "dog:DNS client with colorful output"
    man    "tldr:Simplified, community-driven man pages"
    cd     "zoxide:Smarter cd that learns your habits (command: z)"
  )
fi

# ============================================================================
# Internal state
# ============================================================================

typeset -g _YSU_LAST_TIP_TIME=0
typeset -ga _YSU_MESSAGES=()

# ============================================================================
# Helper functions
# ============================================================================

_ysu_color() {
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

_ysu_format() {
  local color_code
  color_code=$(_ysu_color "$YSU_COLOR")
  local prefix="$YSU_PREFIX"
  [[ -n "$1" ]] && prefix="$prefix$1"
  echo "\e[3${color_code}m${prefix} $2\e[0m"
}

_ysu_buffer() {
  local msg
  msg=$(_ysu_format "$1" "$2")
  _YSU_MESSAGES+=("$msg")
}

_ysu_flush() {
  local msg
  for msg in "${_YSU_MESSAGES[@]}"; do
    echo -e "$msg" >&2
  done
  _YSU_MESSAGES=()
}

_ysu_should_show() {
  # Check cooldown
  if [[ $YSU_COOLDOWN -gt 0 ]]; then
    local now=$EPOCHSECONDS
    local elapsed=$(( now - _YSU_LAST_TIP_TIME ))
    if [[ $elapsed -lt $YSU_COOLDOWN ]]; then
      return 1
    fi
  fi

  # Check probability
  if [[ $YSU_PROBABILITY -lt 100 ]]; then
    local rand=$(( RANDOM % 100 + 1 ))
    if [[ $rand -gt $YSU_PROBABILITY ]]; then
      return 1
    fi
  fi

  return 0
}

_ysu_record_tip() {
  _YSU_LAST_TIP_TIME=$EPOCHSECONDS
}

_ysu_is_ignored_alias() {
  local alias_name="$1"
  local ignored
  for ignored in ${(s: :)YSU_IGNORE_ALIASES}; do
    [[ "$ignored" == "$alias_name" ]] && return 0
  done
  return 1
}

_ysu_is_ignored_command() {
  local cmd="$1"
  local ignored
  for ignored in ${(s: :)YSU_IGNORE_COMMANDS}; do
    [[ "$ignored" == "$cmd" ]] && return 0
  done
  return 1
}

# ============================================================================
# Feature 1: Alias Reminders
# ============================================================================

_ysu_check_aliases() {
  [[ "$YSU_REMINDER_ENABLED" != "true" ]] && return

  local typed_command="$1"
  local first_word="${typed_command%% *}"
  local found_alias=""
  local found_value=""

  # Check all defined aliases
  local alias_name alias_value
  for alias_name alias_value in ${(kv)aliases}; do
    _ysu_is_ignored_alias "$alias_name" && continue

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
    _ysu_is_ignored_alias "$alias_name" && continue
    [[ "$first_word" == "$alias_name" ]] && continue
    if [[ "$typed_command" == *"${alias_value}"* ]]; then
      if [[ -z "$found_value" ]] || [[ ${#alias_value} -gt ${#found_value} ]]; then
        found_alias="$alias_name"
        found_value="$alias_value"
      fi
    fi
  done

  if [[ -n "$found_alias" ]]; then
    _ysu_buffer "$YSU_REMINDER_PREFIX" \
      "Use alias \e[1m${found_alias}\e[0m\e[3$(_ysu_color $YSU_COLOR)m instead of \e[1m${found_value}\e[0m"
    _ysu_record_tip
  fi
}

# ============================================================================
# Feature 2: Modern Command Suggestions
# ============================================================================

_ysu_check_modern() {
  [[ "$YSU_SUGGEST_ENABLED" != "true" ]] && return

  local typed_command="$1"
  local first_word="${typed_command%% *}"

  _ysu_is_ignored_command "$first_word" && return

  # Check if the command has a modern alternative
  local mapping="${YSU_MODERN_COMMANDS[$first_word]}"
  [[ -z "$mapping" ]] && return

  # Support multiple alternatives separated by |
  local entry modern_cmd description
  for entry in ${(s:|:)mapping}; do
    modern_cmd="${entry%%:*}"
    description="${entry#*:}"

    # Suggest the first installed alternative
    if command -v "$modern_cmd" &>/dev/null; then
      _ysu_buffer "$YSU_SUGGEST_PREFIX" \
        "Try \e[1m${modern_cmd}\e[0m\e[3$(_ysu_color $YSU_COLOR)m instead of \e[1m${first_word}\e[0m — ${description}"
      _ysu_record_tip
      return
    fi
  done
}

# ============================================================================
# Hooks: collect in preexec, display in precmd
# ============================================================================

_ysu_preexec() {
  local typed_command="$1"

  # Skip empty commands
  [[ -z "$typed_command" ]] && return

  # Check rate limiting
  _ysu_should_show || return

  # Buffer messages (displayed later in precmd)
  _ysu_check_aliases "$typed_command"
  _ysu_check_modern "$typed_command"
}

_ysu_precmd() {
  # Flush any buffered messages after the command finishes
  # This avoids issues with prompt themes (e.g. powerlevel10k) that
  # capture/redirect stderr during preexec
  [[ ${#_YSU_MESSAGES} -eq 0 ]] && return
  _ysu_flush
}

# Register hooks (append, don't overwrite)
autoload -Uz add-zsh-hook
add-zsh-hook preexec _ysu_preexec
add-zsh-hook precmd _ysu_precmd
