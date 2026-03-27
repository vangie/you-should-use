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
    df     "duf:Disk usage with colorful output and device overview"
    xxd    "hexyl:Colorful hex viewer with modern UI"
    make   "just:Simpler command runner, no tabs required"
    wget   "xh:Fast, friendly HTTP client (like httpie but faster)"
    time   "hyperfine:Benchmarking tool with statistical analysis"
    history "mcfly:Intelligent shell history search with neural network|atuin:Magical shell history with sync"
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

_ysu_format() {
  local prefix="$YSU_PREFIX"
  [[ -n "$1" ]] && prefix="$prefix$1"
  echo "${prefix} \e[1;93m➜\e[0m $2\e[0m"
}

_ysu_buffer() {
  local msg
  msg=$(_ysu_format "$1" "$2")
  _YSU_MESSAGES+=("$msg")
}

_ysu_flush() {
  local msg
  for msg in "${_YSU_MESSAGES[@]}"; do
    echo -e "$msg"
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

# Expand chained aliases: resolve alias values by expanding aliases in them
_ysu_expand_alias() {
  local value="$1"
  local first="${value%% *}"
  local rest="${value#"$first"}"
  local depth=0
  while [[ -n "${aliases[$first]}" ]] && [[ $depth -lt 10 ]]; do
    value="${aliases[$first]}${rest}"
    first="${value%% *}"
    rest="${value#"$first"}"
    (( depth++ ))
  done
  echo "$value"
}

_ysu_check_aliases() {
  [[ "$YSU_REMINDER_ENABLED" != "true" ]] && return

  local typed_command="$1"

  # Strip sudo prefix — only check the actual command, not sudo itself
  # (defense-in-depth: _ysu_preexec also strips, but some environments may bypass it)
  if [[ "$typed_command" == sudo\ * || "$typed_command" == "sudo" ]]; then
    typed_command="${typed_command#sudo}"
    typed_command="${typed_command# }"
  fi
  [[ -z "$typed_command" ]] && return

  local first_word="${typed_command%% *}"
  local found_alias=""
  local found_value=""
  local found_expanded=""

  # Check all defined aliases
  local alias_name alias_value expanded_value
  for alias_name alias_value in ${(kv)aliases}; do
    _ysu_is_ignored_alias "$alias_name" && continue

    # Skip if the user already typed the alias
    [[ "$first_word" == "$alias_name" ]] && continue

    # Expand chained aliases for matching
    expanded_value="$(_ysu_expand_alias "$alias_value")"

    # Check if the typed command starts with the expanded alias value
    if [[ "$typed_command" == "${expanded_value}"* ]]; then
      # Prefer longer expanded matches (more specific)
      if [[ -z "$found_expanded" ]] || [[ ${#expanded_value} -gt ${#found_expanded} ]]; then
        found_alias="$alias_name"
        found_value="$alias_value"
        found_expanded="$expanded_value"
      fi
    fi
  done

  # Also check global aliases
  for alias_name alias_value in ${(kv)galiases}; do
    _ysu_is_ignored_alias "$alias_name" && continue
    [[ "$first_word" == "$alias_name" ]] && continue
    if [[ "$typed_command" == *"${alias_value}"* ]]; then
      if [[ -z "$found_expanded" ]] || [[ ${#alias_value} -gt ${#found_expanded} ]]; then
        found_alias="$alias_name"
        found_value="$alias_value"
        found_expanded="$alias_value"
      fi
    fi
  done

  # Check zsh-abbr abbreviations (if zsh-abbr plugin is loaded)
  if (( ${+ABBR_REGULAR_USER_ABBREVIATIONS} )); then
    for alias_name alias_value in ${(kv)ABBR_REGULAR_USER_ABBREVIATIONS}; do
      _ysu_is_ignored_alias "$alias_name" && continue
      [[ "$first_word" == "$alias_name" ]] && continue
      expanded_value="$(_ysu_expand_alias "$alias_value")"
      if [[ "$typed_command" == "${expanded_value}"* ]]; then
        if [[ -z "$found_expanded" ]] || [[ ${#expanded_value} -gt ${#found_expanded} ]]; then
          found_alias="$alias_name"
          found_value="$alias_value"
          found_expanded="$expanded_value"
        fi
      fi
    done
  fi
  if (( ${+ABBR_GLOBAL_USER_ABBREVIATIONS} )); then
    for alias_name alias_value in ${(kv)ABBR_GLOBAL_USER_ABBREVIATIONS}; do
      _ysu_is_ignored_alias "$alias_name" && continue
      [[ "$first_word" == "$alias_name" ]] && continue
      if [[ "$typed_command" == *"${alias_value}"* ]]; then
        if [[ -z "$found_expanded" ]] || [[ ${#alias_value} -gt ${#found_expanded} ]]; then
          found_alias="$alias_name"
          found_value="$alias_value"
          found_expanded="$alias_value"
        fi
      fi
    done
  fi

  if [[ -n "$found_alias" ]]; then
    _ysu_buffer "$YSU_REMINDER_PREFIX" \
      "You should use \e[1;4;31m${found_alias}\e[0m instead of \e[1;4;36m${found_expanded}\e[0m"
    _ysu_record_tip
  fi
}

# ============================================================================
# Feature 2: Modern Command Suggestions
# ============================================================================

_ysu_check_modern() {
  [[ "$YSU_SUGGEST_ENABLED" != "true" ]] && return

  local typed_command="$1"

  # Strip sudo prefix (defense-in-depth, same as _ysu_check_aliases)
  if [[ "$typed_command" == sudo\ * || "$typed_command" == "sudo" ]]; then
    typed_command="${typed_command#sudo}"
    typed_command="${typed_command# }"
  fi
  [[ -z "$typed_command" ]] && return

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
      # Skip if first_word is already aliased to this modern command
      local alias_val="${aliases[$first_word]:-${galiases[$first_word]:-}}"
      [[ "${alias_val%% *}" == "$modern_cmd" ]] && return

      _ysu_buffer "$YSU_SUGGEST_PREFIX" \
        "You should use \e[1;4;31m${modern_cmd}\e[0m instead of \e[1;4;36m${first_word}\e[0m — \e[3m${description}\e[0m"
      _ysu_record_tip
      return
    fi
  done
}

# ============================================================================
# Feature 3: Sudo alias suggestion (priority 2 — only when inner command has no suggestion)
# ============================================================================

_ysu_check_sudo_alias() {
  local inner_command="$1"
  local alias_name alias_value
  for alias_name alias_value in ${(kv)aliases}; do
    _ysu_is_ignored_alias "$alias_name" && continue
    # Skip "sudo" itself (alias sudo="sudo " is common but not useful to suggest)
    [[ "$alias_name" == "sudo" ]] && continue
    # Match aliases whose value is "sudo" or "sudo " (trailing space for alias chaining)
    if [[ "$alias_value" == "sudo" || "$alias_value" == "sudo " ]]; then
      _ysu_buffer "$YSU_REMINDER_PREFIX" \
        "You should use \e[1;4;31m${alias_name} ${inner_command}\e[0m instead of \e[1;4;36msudo ${inner_command}\e[0m"
      _ysu_record_tip
      return
    fi
  done
}

# ============================================================================
# Hooks: collect in preexec, display in precmd
# ============================================================================

_ysu_preexec() {
  # Ghostty shell integration doesn't pass $1; fall back to history
  local typed_command="${1:-${history[$HISTCMD]}}"

  # Trim leading whitespace
  typed_command="${typed_command#"${typed_command%%[! ]*}"}"

  # Skip empty commands
  [[ -z "$typed_command" ]] && return

  # Strip sudo prefix for matching — check the actual command, not sudo itself
  local check_command="$typed_command"
  local _ysu_has_sudo=false
  if [[ "$check_command" == sudo\ * || "$check_command" == "sudo" ]]; then
    check_command="${check_command#sudo}"
    check_command="${check_command# }"
    _ysu_has_sudo=true
  fi

  # Skip if only sudo with no actual command
  [[ -z "$check_command" ]] && return

  # Check rate limiting
  _ysu_should_show || return

  # Three-tier priority for sudo commands:
  # Priority 1: Inner command has a suggestion (alias reminder or modern tool)
  # Priority 2: No inner suggestion, but sudo has an alias (e.g. _="sudo") → suggest that
  # Priority 3: Neither → no suggestion
  # Non-sudo commands: normal alias + modern check
  _ysu_check_aliases "$check_command"
  _ysu_check_modern "$check_command"

  # Priority 2: suggest sudo alias only when inner command had no suggestions
  if [[ ${#_YSU_MESSAGES} -eq 0 ]] && $_ysu_has_sudo; then
    _ysu_check_sudo_alias "$check_command"
  fi

  _ysu_flush
}

_ysu_precmd() {
  # Flush any remaining buffered messages (fallback)
  [[ ${#_YSU_MESSAGES} -eq 0 ]] && return
  _ysu_flush
}

# Register hooks (append, don't overwrite)
autoload -Uz add-zsh-hook
add-zsh-hook preexec _ysu_preexec
add-zsh-hook precmd _ysu_precmd
