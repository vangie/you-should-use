#!/usr/bin/env zsh
# you-should-use - Alias reminders & modern command suggestions
# https://github.com/vangie/you-should-use
# MIT License

# Guard against double-sourcing (add-zsh-hook would register duplicate hooks)
[[ -n "$_YSU_LOADED" ]] && return
_YSU_LOADED=1

# Source user config if it exists (before defaults so user values take priority)
local _ysu_config="${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.zsh"
[[ -f "$_ysu_config" ]] && source "$_ysu_config"

# ============================================================================
# Configuration (override these in your .zshrc BEFORE sourcing the plugin)
# ============================================================================

# Feature toggles
: ${YSU_DISABLED:=false}
: ${YSU_REMINDER_ENABLED:=true}
: ${YSU_SUGGEST_ENABLED:=true}
: ${YSU_LLM_ENABLED:=false}

# Display settings
: ${YSU_PREFIX:="💡"}             # Prefix for all messages
: ${YSU_REMINDER_PREFIX:=""}      # Additional prefix for alias reminders
: ${YSU_SUGGEST_PREFIX:=""}       # Additional prefix for modern tool suggestions
: ${YSU_LLM_PREFIX:="🤖"}        # Additional prefix for LLM suggestions

# Frequency control
: ${YSU_PROBABILITY:=100}         # Percentage chance to show a tip (1-100)
: ${YSU_COOLDOWN:=0}              # Minimum seconds between tips (0 = no cooldown)

# Exclusions
: ${YSU_IGNORE_ALIASES:=""}       # Space-separated list of aliases to ignore
: ${YSU_IGNORE_COMMANDS:=""}      # Space-separated list of commands to ignore for suggestions
: ${YSU_INSTALL_HINT:=true}        # Show install commands for modern tool suggestions

# Message template (use {prefix}, {arrow}, {message} placeholders)
: ${YSU_MESSAGE_FORMAT:="{prefix} {arrow} {message}"}

# Theme settings
: ${YSU_THEME:="dark"}
: ${YSU_DARK_THEME:="tokyo-night"}
: ${YSU_LIGHT_THEME:="solarized"}

# Available themes (dark: tokyo-night, dracula, monokai, catppuccin-mocha)
#                  (light: solarized, catppuccin-latte, github)
_ysu_init_colors() {
  local theme_name
  if [[ "$YSU_THEME" == "light" ]]; then
    theme_name="$YSU_LIGHT_THEME"
  else
    theme_name="$YSU_DARK_THEME"
  fi

  local -A _colors
  case "$theme_name" in
    # Dark themes
    tokyo-night)      _colors=(arrow '\e[1;93m' highlight '\e[1;31m' command '\e[1;36m' dim '\e[3m' hint '\e[1;33m' ok '\e[32m' err '\e[31m' bold '\e[1m') ;;
    dracula)          _colors=(arrow '\e[38;5;141m' highlight '\e[1;38;5;212m' command '\e[38;5;117m' dim '\e[3;38;5;103m' hint '\e[38;5;84m' ok '\e[32m' err '\e[31m' bold '\e[1m') ;;
    monokai)          _colors=(arrow '\e[38;5;208m' highlight '\e[1;38;5;197m' command '\e[38;5;148m' dim '\e[3;38;5;242m' hint '\e[38;5;186m' ok '\e[32m' err '\e[31m' bold '\e[1m') ;;
    catppuccin-mocha) _colors=(arrow '\e[38;5;180m' highlight '\e[1;38;5;211m' command '\e[38;5;153m' dim '\e[3;38;5;103m' hint '\e[38;5;223m' ok '\e[32m' err '\e[31m' bold '\e[1m') ;;
    # Light themes
    solarized)        _colors=(arrow '\e[1;33m' highlight '\e[1;31m' command '\e[1;34m' dim '\e[3;2m' hint '\e[1;35m' ok '\e[32m' err '\e[31m' bold '\e[1m') ;;
    catppuccin-latte) _colors=(arrow '\e[38;5;136m' highlight '\e[1;38;5;124m' command '\e[38;5;25m' dim '\e[3;38;5;145m' hint '\e[38;5;133m' ok '\e[32m' err '\e[31m' bold '\e[1m') ;;
    github)           _colors=(arrow '\e[38;5;130m' highlight '\e[1;38;5;124m' command '\e[38;5;24m' dim '\e[3;38;5;246m' hint '\e[38;5;90m' ok '\e[32m' err '\e[31m' bold '\e[1m') ;;
    # Fallback
    *)                _colors=(arrow '\e[1;93m' highlight '\e[1;31m' command '\e[1;36m' dim '\e[3m' hint '\e[1;33m' ok '\e[32m' err '\e[31m' bold '\e[1m') ;;
  esac

  typeset -g _YSU_C_ARROW="${YSU_COLOR_ARROW:-${_colors[arrow]}}"
  typeset -g _YSU_C_HIGHLIGHT="${YSU_COLOR_HIGHLIGHT:-${_colors[highlight]}}"
  typeset -g _YSU_C_COMMAND="${YSU_COLOR_COMMAND:-${_colors[command]}}"
  typeset -g _YSU_C_DIM="${YSU_COLOR_DIM:-${_colors[dim]}}"
  typeset -g _YSU_C_HINT="${YSU_COLOR_HINT:-${_colors[hint]}}"
  typeset -g _YSU_C_OK="${YSU_COLOR_OK:-${_colors[ok]}}"
  typeset -g _YSU_C_ERR="${YSU_COLOR_ERR:-${_colors[err]}}"
  typeset -g _YSU_C_BOLD="${YSU_COLOR_BOLD:-${_colors[bold]}}"
  typeset -g _YSU_C_RESET='\e[0m'
}
_ysu_init_colors

# LLM settings (OpenAI-compatible API — works with Ollama, OpenAI, etc.)
: ${YSU_LLM_API_URL:="http://localhost:11434/v1/chat/completions"}
: ${YSU_LLM_API_KEY:=""}
: ${YSU_LLM_MODEL:="auto"}
: ${YSU_LLM_CACHE_DIR:="$HOME/.cache/ysu"}
: ${YSU_LLM_MODE:="single"}             # single, multi, or both
: ${YSU_LLM_WINDOW_SIZE:=5}             # Number of commands for multi-command analysis

# ============================================================================
# Ollama auto-detection (runs once at plugin load, not every command)
# ============================================================================

typeset -g _YSU_LLM_RESOLVED_MODEL=""

if [[ -z "$_YSU_OLLAMA_CHECKED" ]]; then
  typeset -g _YSU_OLLAMA_CHECKED=1
  # Only auto-detect if user hasn't explicitly configured LLM
  if [[ "$YSU_LLM_ENABLED" == "false" ]]; then
    # Check if the config file explicitly set YSU_LLM_ENABLED
    local _ysu_user_set_llm=false
    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.zsh" ]]; then
      grep -q 'YSU_LLM_ENABLED' "${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.zsh" 2>/dev/null && _ysu_user_set_llm=true
    fi
    if [[ "$_ysu_user_set_llm" == "false" ]]; then
      # Probe Ollama at default port (quick timeout)
      local _ysu_ollama_tags
      _ysu_ollama_tags=$(curl -s --max-time 2 "http://localhost:11434/api/tags" 2>/dev/null)
      if [[ -n "$_ysu_ollama_tags" ]]; then
        if [[ "$YSU_LLM_MODEL" == "auto" ]]; then
          # Auto mode: pick the first available model
          local _ysu_first_model=""
          if command -v jq &>/dev/null; then
            _ysu_first_model=$(echo "$_ysu_ollama_tags" | jq -r '.models[0].name // empty' 2>/dev/null)
          elif command -v python3 &>/dev/null; then
            _ysu_first_model=$(python3 -c "
import sys, json
try:
    r = json.loads(sys.stdin.read())
    m = r.get('models', [])
    if m: print(m[0]['name'])
except: pass
" <<< "$_ysu_ollama_tags" 2>/dev/null)
          fi
          if [[ -n "$_ysu_first_model" ]]; then
            _YSU_LLM_RESOLVED_MODEL="$_ysu_first_model"
            YSU_LLM_ENABLED=true
          fi
        else
          # Specific model: check if it's available
          if echo "$_ysu_ollama_tags" | grep -q "\"${YSU_LLM_MODEL}\"" 2>/dev/null; then
            _YSU_LLM_RESOLVED_MODEL="$YSU_LLM_MODEL"
            YSU_LLM_ENABLED=true
          fi
        fi
      fi
    fi
  fi
fi

# Resolve model for non-auto-detect cases (user enabled LLM manually)
if [[ "$YSU_LLM_ENABLED" == "true" && -z "$_YSU_LLM_RESOLVED_MODEL" ]]; then
  if [[ "$YSU_LLM_MODEL" == "auto" ]]; then
    # Try to resolve from Ollama
    local _ysu_tags
    _ysu_tags=$(curl -s --max-time 2 "http://localhost:11434/api/tags" 2>/dev/null)
    if [[ -n "$_ysu_tags" ]]; then
      if command -v jq &>/dev/null; then
        _YSU_LLM_RESOLVED_MODEL=$(echo "$_ysu_tags" | jq -r '.models[0].name // empty' 2>/dev/null)
      elif command -v python3 &>/dev/null; then
        _YSU_LLM_RESOLVED_MODEL=$(python3 -c "
import sys, json
try:
    r = json.loads(sys.stdin.read())
    m = r.get('models', [])
    if m: print(m[0]['name'])
except: pass
" <<< "$_ysu_tags" 2>/dev/null)
      fi
    fi
  else
    _YSU_LLM_RESOLVED_MODEL="$YSU_LLM_MODEL"
  fi
fi

# ============================================================================
# Modern command alternatives mapping
# ============================================================================

typeset -gA YSU_MODERN_COMMANDS

# Default mappings (user can override or extend)
# Format: command "alt1:description|alt2:description" (pipe-separated for multiple alternatives)
# The first installed alternative is suggested
if [[ ${#YSU_MODERN_COMMANDS} -eq 0 ]]; then
  YSU_MODERN_COMMANDS=(
    cat    "bat:Syntax highlighting, line numbers, git integration|glow:Terminal Markdown renderer"
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
    cloc   "tokei:Fast code line counter with language breakdown"
    tree   "broot:Interactive directory tree with fuzzy search"
    traceroute "mtr:Combined traceroute and ping with live display"
    tmux   "zellij:Modern terminal multiplexer with intuitive UI"
    vim    "nvim:Neovim - modernized Vim fork"
  )
fi

# Context-aware suggestions: suggest tools based on command + file extension
# Format: "command:.ext" → "tool:description"
typeset -gA YSU_CONTEXT_COMMANDS
if [[ ${#YSU_CONTEXT_COMMANDS} -eq 0 ]]; then
  YSU_CONTEXT_COMMANDS=(
    "diff:.json"  "jd:JSON diff and patch tool"
    "diff:.yaml"  "jd:JSON diff and patch tool (also handles YAML)"
    "diff:.yml"   "jd:JSON diff and patch tool (also handles YAML)"
  )
fi

# ============================================================================
# Platform detection for install hints
# ============================================================================

_ysu_detect_pkg_manager() {
  # WSL detection
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    typeset -g _YSU_IS_WSL=true
  else
    typeset -g _YSU_IS_WSL=false
  fi

  if command -v brew &>/dev/null; then
    typeset -g _YSU_PKG_MANAGER="brew"
    typeset -g _YSU_PKG_INSTALL="brew install"
  elif command -v apt &>/dev/null; then
    typeset -g _YSU_PKG_MANAGER="apt"
    typeset -g _YSU_PKG_INSTALL="sudo apt install"
  elif command -v pacman &>/dev/null; then
    typeset -g _YSU_PKG_MANAGER="pacman"
    typeset -g _YSU_PKG_INSTALL="sudo pacman -S"
  elif command -v dnf &>/dev/null; then
    typeset -g _YSU_PKG_MANAGER="dnf"
    typeset -g _YSU_PKG_INSTALL="sudo dnf install"
  elif command -v zypper &>/dev/null; then
    typeset -g _YSU_PKG_MANAGER="zypper"
    typeset -g _YSU_PKG_INSTALL="sudo zypper install"
  elif command -v apk &>/dev/null; then
    typeset -g _YSU_PKG_MANAGER="apk"
    typeset -g _YSU_PKG_INSTALL="apk add"
  elif command -v pkg &>/dev/null; then
    typeset -g _YSU_PKG_MANAGER="pkg"
    typeset -g _YSU_PKG_INSTALL="pkg install"
  else
    typeset -g _YSU_PKG_MANAGER="unknown"
    typeset -g _YSU_PKG_INSTALL=""
  fi
}
_ysu_detect_pkg_manager

# Package name overrides (where package name differs from tool name)
# Format: _YSU_PKG_OVERRIDES_<manager>[tool]=package_name
typeset -gA _YSU_PKG_OVERRIDES_brew=(
  rg ripgrep  ag the_silver_searcher  delta git-delta
)
typeset -gA _YSU_PKG_OVERRIDES_apt=(
  rg ripgrep  ag silversearcher-ag  delta git-delta
  fd fd-find  dust du-dust  bat bat  lsd lsd
  dog dog  procs procs
)
typeset -gA _YSU_PKG_OVERRIDES_pacman=(
  rg ripgrep  ag the_silver_searcher  delta git-delta
)
typeset -gA _YSU_PKG_OVERRIDES_dnf=(
  rg ripgrep  ag the_silver_searcher  delta git-delta
)

_ysu_get_pkg_name() {
  local tool="$1"
  local overrides_var="_YSU_PKG_OVERRIDES_${_YSU_PKG_MANAGER}"
  local pkg
  # Use (P) parameter expansion for indirect associative array access
  pkg="${${(P)overrides_var}[$tool]}"
  if [[ -n "$pkg" ]]; then
    echo "$pkg"
  else
    echo "$tool"
  fi
}

# Install command hints (tool → install command)
# Auto-generated based on detected package manager
typeset -gA YSU_INSTALL_COMMANDS
if [[ ${#YSU_INSTALL_COMMANDS} -eq 0 && -n "$_YSU_PKG_INSTALL" ]]; then
  local _ysu_tools=(bat eza lsd fd rg ag dust ncdu btop htop procs delta colordiff sd httpie curlie gping dog tldr zoxide duf hexyl just xh hyperfine mcfly atuin glow tokei broot mtr zellij)
  local _t _pkg
  for _t in "${_ysu_tools[@]}"; do
    _pkg=$(_ysu_get_pkg_name "$_t")
    YSU_INSTALL_COMMANDS[$_t]="${_YSU_PKG_INSTALL} ${_pkg}"
  done
  unset _t _pkg _ysu_tools
fi

# ============================================================================
# Internal state
# ============================================================================

typeset -g _YSU_LAST_TIP_TIME=0
typeset -ga _YSU_MESSAGES=()
typeset -g _YSU_LLM_PENDING_CMD=""
typeset -g _YSU_LLM_ASYNC_FILE=""
typeset -g _YSU_LLM_ASYNC_CMD=""
typeset -g _YSU_PROMO_SHOWN_TODAY=0
typeset -g _YSU_PROMO_DATE=""
typeset -ga _YSU_CMD_HISTORY=()
typeset -g _YSU_MULTI_ASYNC_FILE=""
typeset -g _YSU_MULTI_ASYNC_KEY=""

# ============================================================================
# Helper functions
# ============================================================================

_ysu_format() {
  local prefix="$YSU_PREFIX"
  [[ -n "$1" ]] && prefix="$prefix$1"
  local arrow="${_YSU_C_ARROW}➜${_YSU_C_RESET}"
  local message="$2${_YSU_C_RESET}"
  local result="$YSU_MESSAGE_FORMAT"
  result="${result//\{prefix\}/$prefix}"
  result="${result//\{arrow\}/$arrow}"
  result="${result//\{message\}/$message}"
  echo "$result"
}

_ysu_buffer() {
  local msg
  msg=$(_ysu_format "$1" "$2")
  # Deduplicate: skip if identical message already buffered
  local existing
  for existing in "${_YSU_MESSAGES[@]}"; do
    [[ "$existing" == "$msg" ]] && return
  done
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
      "You should use ${_YSU_C_HIGHLIGHT}${found_alias}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${found_expanded}${_YSU_C_RESET}"
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

  # Context-aware check: inspect file extensions in arguments
  local _args="${typed_command#* }"
  if [[ "$_args" != "$typed_command" ]]; then
    local _arg _ext _ctx_key _ctx_entry _ctx_cmd _ctx_desc
    for _arg in ${(z)_args}; do
      _ext="${_arg##*.}"
      [[ "$_ext" != "$_arg" && -n "$_ext" ]] || continue
      _ctx_key="${first_word}:.${_ext}"
      _ctx_entry="${YSU_CONTEXT_COMMANDS[$_ctx_key]}"
      [[ -n "$_ctx_entry" ]] || continue
      _ctx_cmd="${_ctx_entry%%:*}"
      _ctx_desc="${_ctx_entry#*:}"
      if command -v "$_ctx_cmd" &>/dev/null; then
        _ysu_buffer "$YSU_SUGGEST_PREFIX" \
          "You should use ${_YSU_C_HIGHLIGHT}${_ctx_cmd}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${first_word}${_YSU_C_RESET} — ${_YSU_C_DIM}${_ctx_desc}${_YSU_C_RESET}"
        _ysu_record_tip
        return
      elif [[ "$YSU_INSTALL_HINT" == "true" ]]; then
        local _ctx_install="${YSU_INSTALL_COMMANDS[$_ctx_cmd]}"
        if [[ -n "$_ctx_install" ]]; then
          _ysu_buffer "$YSU_SUGGEST_PREFIX" \
            "Try ${_YSU_C_HIGHLIGHT}${_ctx_cmd}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${first_word}${_YSU_C_RESET} — ${_YSU_C_DIM}${_ctx_desc}${_YSU_C_RESET} (install: ${_YSU_C_HINT}${_ctx_install}${_YSU_C_RESET})"
          _ysu_record_tip
        fi
        return
      fi
    done
  fi

  # Check if the command has a modern alternative
  local mapping="${YSU_MODERN_COMMANDS[$first_word]}"
  [[ -z "$mapping" ]] && return

  # Support multiple alternatives separated by |
  local entry modern_cmd description
  local _ysu_first_uninstalled="" _ysu_first_uninstalled_desc="" _ysu_first_uninstalled_install=""
  for entry in ${(s:|:)mapping}; do
    modern_cmd="${entry%%:*}"
    description="${entry#*:}"

    # Suggest the first installed alternative
    if command -v "$modern_cmd" &>/dev/null; then
      # Skip if first_word is already aliased to this modern command
      local alias_val="${aliases[$first_word]:-${galiases[$first_word]:-}}"
      [[ "${alias_val%% *}" == "$modern_cmd" ]] && return

      _ysu_buffer "$YSU_SUGGEST_PREFIX" \
        "You should use ${_YSU_C_HIGHLIGHT}${modern_cmd}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${first_word}${_YSU_C_RESET} — ${_YSU_C_DIM}${description}${_YSU_C_RESET}"
      _ysu_record_tip
      return
    elif [[ -z "$_ysu_first_uninstalled" ]]; then
      _ysu_first_uninstalled="$modern_cmd"
      _ysu_first_uninstalled_desc="$description"
      _ysu_first_uninstalled_install="${YSU_INSTALL_COMMANDS[$modern_cmd]}"
    fi
  done

  # No installed alternative found — show install hint for the first one
  if [[ "$YSU_INSTALL_HINT" == "true" && -n "$_ysu_first_uninstalled" && -n "$_ysu_first_uninstalled_install" ]]; then
    _ysu_buffer "$YSU_SUGGEST_PREFIX" \
      "Try ${_YSU_C_HIGHLIGHT}${_ysu_first_uninstalled}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${first_word}${_YSU_C_RESET} — ${_YSU_C_DIM}${_ysu_first_uninstalled_desc}${_YSU_C_RESET} (install: ${_YSU_C_HINT}${_ysu_first_uninstalled_install}${_YSU_C_RESET})"
    _ysu_record_tip
  fi
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
        "You should use ${_YSU_C_HIGHLIGHT}${alias_name} ${inner_command}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}sudo ${inner_command}${_YSU_C_RESET}"
      _ysu_record_tip
      return
    fi
  done
}

# ============================================================================
# Feature 4: LLM-powered suggestions (async + cached)
# ============================================================================

_ysu_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  echo -n "$s"
}

_ysu_json_extract_content() {
  local json="$1"
  if command -v jq &>/dev/null; then
    echo "$json" | jq -r '.choices[0].message.content // empty' 2>/dev/null
  elif command -v python3 &>/dev/null; then
    python3 -c "
import sys, json
try:
    r = json.loads(sys.stdin.read())
    print(r['choices'][0]['message']['content'])
except: pass
" <<< "$json" 2>/dev/null
  else
    # Simple fallback
    echo "$json" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tail -1
  fi
}

_ysu_llm_cache_key() {
  if command -v md5 &>/dev/null; then
    echo -n "$1" | md5
  elif command -v md5sum &>/dev/null; then
    echo -n "$1" | md5sum | cut -d' ' -f1
  else
    echo -n "$1" | cksum | cut -d' ' -f1
  fi
}

_ysu_llm_should_trigger() {
  local cmd="$1" exit_code="$2"

  # Trigger on non-zero exit
  [[ "$exit_code" -ne 0 ]] && return 0

  # Trigger on pipes or redirects
  [[ "$cmd" == *"|"* || "$cmd" == *">>"* || "$cmd" == *">"* || "$cmd" == *"<"* ]] && return 0

  # Trigger on complex args (command + 3 or more arguments)
  local -a words=(${(z)cmd})
  [[ ${#words} -ge 4 ]] && return 0

  return 1
}

_ysu_get_effective_model() {
  if [[ "$YSU_LLM_MODEL" == "auto" && -n "$_YSU_LLM_RESOLVED_MODEL" ]]; then
    echo "$_YSU_LLM_RESOLVED_MODEL"
  elif [[ "$YSU_LLM_MODEL" != "auto" ]]; then
    echo "$YSU_LLM_MODEL"
  fi
}

_ysu_llm_query_async() {
  local cmd="$1"

  # Clean up any previous pending request
  if [[ -n "$_YSU_LLM_ASYNC_FILE" ]]; then
    rm -f "$_YSU_LLM_ASYNC_FILE" "${_YSU_LLM_ASYNC_FILE}.done" 2>/dev/null
  fi

  mkdir -p "$YSU_LLM_CACHE_DIR"
  local tmp_file
  tmp_file=$(mktemp "${YSU_LLM_CACHE_DIR}/.pending.XXXXXX")

  local effective_model
  effective_model=$(_ysu_get_effective_model)
  [[ -z "$effective_model" ]] && return

  local escaped_cmd
  escaped_cmd=$(_ysu_json_escape "$cmd")
  local system_prompt="You are a shell expert. Given a shell command, suggest a better alternative or optimization in one brief sentence. If there is no improvement, reply with exactly: none"
  local payload="{\"model\":\"${effective_model}\",\"messages\":[{\"role\":\"system\",\"content\":\"${system_prompt}\"},{\"role\":\"user\",\"content\":\"${escaped_cmd}\"}],\"max_tokens\":100,\"temperature\":0.3}"

  _YSU_LLM_ASYNC_FILE="$tmp_file"
  _YSU_LLM_ASYNC_CMD="$cmd"

  {
    local response auth_args=()
    [[ -n "$YSU_LLM_API_KEY" ]] && auth_args=(-H "Authorization: Bearer $YSU_LLM_API_KEY")

    response=$(curl -s --max-time 10 \
      -H "Content-Type: application/json" \
      "${auth_args[@]}" \
      -d "$payload" \
      "$YSU_LLM_API_URL" 2>/dev/null) || true

    local content=""
    [[ -n "$response" ]] && content=$(_ysu_json_extract_content "$response")

    # Trim whitespace
    content="${content#"${content%%[! ]*}"}"
    content="${content%"${content##*[! ]}"}"

    if [[ -n "$content" && "${(L)content}" != "none" && "${(L)content}" != "none." ]]; then
      echo "$content" > "$tmp_file"
    else
      : > "$tmp_file"
    fi
    touch "${tmp_file}.done"
  } &!
}

_ysu_llm_check_async() {
  [[ -z "$_YSU_LLM_ASYNC_FILE" ]] && return

  # Check if background process finished
  [[ ! -f "${_YSU_LLM_ASYNC_FILE}.done" ]] && return

  # Read result
  local result=""
  [[ -s "$_YSU_LLM_ASYNC_FILE" ]] && result=$(<"$_YSU_LLM_ASYNC_FILE")

  # Cache the result
  local cache_key
  cache_key=$(_ysu_llm_cache_key "$_YSU_LLM_ASYNC_CMD")
  local cache_file="${YSU_LLM_CACHE_DIR}/${cache_key}"
  if [[ -n "$result" ]]; then
    echo "$result" > "$cache_file"
    echo -e "$(_ysu_format "$YSU_LLM_PREFIX" "$result")"
  else
    : > "$cache_file"
  fi

  # Cleanup
  rm -f "$_YSU_LLM_ASYNC_FILE" "${_YSU_LLM_ASYNC_FILE}.done" 2>/dev/null
  _YSU_LLM_ASYNC_FILE=""
  _YSU_LLM_ASYNC_CMD=""
}

# ============================================================================
# Feature 4b: LLM multi-command analysis (sliding window)
# ============================================================================

_ysu_multi_push_cmd() {
  local cmd="$1"
  _YSU_CMD_HISTORY+=("$cmd")
  # Trim to window size
  while [[ ${#_YSU_CMD_HISTORY} -gt $YSU_LLM_WINDOW_SIZE ]]; do
    shift _YSU_CMD_HISTORY
  done
}

_ysu_multi_should_trigger() {
  # Need at least 3 commands in the window to analyze patterns
  [[ ${#_YSU_CMD_HISTORY} -ge 3 ]] || return 1
  return 0
}

_ysu_multi_query_async() {
  # Clean up any previous pending request
  if [[ -n "$_YSU_MULTI_ASYNC_FILE" ]]; then
    rm -f "$_YSU_MULTI_ASYNC_FILE" "${_YSU_MULTI_ASYNC_FILE}.done" 2>/dev/null
  fi

  mkdir -p "$YSU_LLM_CACHE_DIR"
  local tmp_file
  tmp_file=$(mktemp "${YSU_LLM_CACHE_DIR}/.multi.XXXXXX")

  local effective_model
  effective_model=$(_ysu_get_effective_model)
  [[ -z "$effective_model" ]] && return

  # Build the command sequence string
  local cmd_sequence=""
  local cmd
  for cmd in "${_YSU_CMD_HISTORY[@]}"; do
    cmd_sequence="${cmd_sequence}${cmd}"$'\n'
  done

  local cache_key
  cache_key=$(_ysu_llm_cache_key "$cmd_sequence")
  local cache_file="${YSU_LLM_CACHE_DIR}/multi_${cache_key}"

  # Check cache first
  if [[ -f "$cache_file" ]]; then
    local cached=""
    [[ -s "$cache_file" ]] && cached=$(<"$cache_file")
    [[ -n "$cached" ]] && echo -e "$(_ysu_format "$YSU_LLM_PREFIX" "$cached")"
    return
  fi

  local escaped_cmds
  escaped_cmds=$(_ysu_json_escape "$cmd_sequence")
  local system_prompt="You are a shell workflow expert. Given a sequence of recent shell commands, identify if there is a pattern or workflow that could be optimized. Suggest a single improvement (a combined command, a tool, or a better workflow) in one brief sentence. If there is no improvement, reply with exactly: none"
  local payload="{\"model\":\"${effective_model}\",\"messages\":[{\"role\":\"system\",\"content\":\"${system_prompt}\"},{\"role\":\"user\",\"content\":\"Recent commands:\\n${escaped_cmds}\"}],\"max_tokens\":150,\"temperature\":0.3}"

  _YSU_MULTI_ASYNC_FILE="$tmp_file"
  _YSU_MULTI_ASYNC_KEY="$cache_key"

  {
    local response auth_args=()
    [[ -n "$YSU_LLM_API_KEY" ]] && auth_args=(-H "Authorization: Bearer $YSU_LLM_API_KEY")

    response=$(curl -s --max-time 15 \
      -H "Content-Type: application/json" \
      "${auth_args[@]}" \
      -d "$payload" \
      "$YSU_LLM_API_URL" 2>/dev/null) || true

    local content=""
    [[ -n "$response" ]] && content=$(_ysu_json_extract_content "$response")

    # Trim whitespace
    content="${content#"${content%%[! ]*}"}"
    content="${content%"${content##*[! ]}"}"

    if [[ -n "$content" && "${(L)content}" != "none" && "${(L)content}" != "none." ]]; then
      echo "$content" > "$tmp_file"
    else
      : > "$tmp_file"
    fi
    touch "${tmp_file}.done"
  } &!
}

_ysu_multi_check_async() {
  [[ -z "$_YSU_MULTI_ASYNC_FILE" ]] && return

  # Check if background process finished
  [[ ! -f "${_YSU_MULTI_ASYNC_FILE}.done" ]] && return

  # Read result
  local result=""
  [[ -s "$_YSU_MULTI_ASYNC_FILE" ]] && result=$(<"$_YSU_MULTI_ASYNC_FILE")

  # Cache the result
  local cache_file="${YSU_LLM_CACHE_DIR}/multi_${_YSU_MULTI_ASYNC_KEY}"
  if [[ -n "$result" ]]; then
    echo "$result" > "$cache_file"
    echo -e "$(_ysu_format "$YSU_LLM_PREFIX" "$result")"
  else
    : > "$cache_file"
  fi

  # Cleanup
  rm -f "$_YSU_MULTI_ASYNC_FILE" "${_YSU_MULTI_ASYNC_FILE}.done" 2>/dev/null
  _YSU_MULTI_ASYNC_FILE=""
  _YSU_MULTI_ASYNC_KEY=""
}

# ============================================================================
# Feature 5: LLM configuration promo (low-frequency reminder)
# ============================================================================

_ysu_maybe_show_promo() {
  # Only show when LLM is disabled
  [[ "$YSU_LLM_ENABLED" != "false" ]] && return

  # Rate limit: max 3 per day using cache file
  local cache_dir="${YSU_LLM_CACHE_DIR:-$HOME/.cache/ysu}"
  mkdir -p "$cache_dir"
  local promo_file="$cache_dir/.promo_count"
  local today
  today=$(date +%Y-%m-%d)

  # Reset counter on new day
  if [[ "$_YSU_PROMO_DATE" != "$today" ]]; then
    _YSU_PROMO_DATE="$today"
    _YSU_PROMO_SHOWN_TODAY=0
    # Also check persistent file
    if [[ -f "$promo_file" ]]; then
      local saved_date saved_count
      saved_date=$(head -1 "$promo_file" 2>/dev/null)
      saved_count=$(tail -1 "$promo_file" 2>/dev/null)
      if [[ "$saved_date" == "$today" ]]; then
        _YSU_PROMO_SHOWN_TODAY="${saved_count:-0}"
      fi
    fi
  fi

  [[ $_YSU_PROMO_SHOWN_TODAY -ge 3 ]] && return

  # Show the promo
  (( _YSU_PROMO_SHOWN_TODAY++ ))
  printf '%s\n%s\n' "$today" "$_YSU_PROMO_SHOWN_TODAY" > "$promo_file"
  echo -e "$(_ysu_format "" "Enable AI-powered suggestions! Run ${_YSU_C_HINT}ysu config${_YSU_C_RESET} to set up.")"
}

# ============================================================================
# Hooks: collect in preexec, display in precmd
# ============================================================================

_ysu_preexec() {
  # Bail out if plugin is disabled
  [[ "$YSU_DISABLED" == "true" ]] && return

  # Ghostty shell integration doesn't pass $1; fall back to history
  local typed_command="${1:-${history[$HISTCMD]}}"

  # Trim leading whitespace
  typed_command="${typed_command#"${typed_command%%[! ]*}"}"

  # Skip empty commands
  [[ -z "$typed_command" ]] && return

  # Save full command for LLM evaluation in precmd
  _YSU_LLM_PENDING_CMD="$typed_command"

  # Push to multi-command history buffer
  if [[ "$YSU_LLM_ENABLED" == "true" && ("$YSU_LLM_MODE" == "multi" || "$YSU_LLM_MODE" == "both") ]]; then
    _ysu_multi_push_cmd "$typed_command"
  fi

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
  local _ysu_tip_time_before=$_YSU_LAST_TIP_TIME
  _ysu_check_aliases "$check_command"
  _ysu_check_modern "$check_command"

  # Priority 2: suggest sudo alias only when inner command had no suggestions
  if [[ ${#_YSU_MESSAGES} -eq 0 ]] && $_ysu_has_sudo; then
    _ysu_check_sudo_alias "$check_command"
  fi

  # Track whether any tips were shown for this command (for promo gating)
  typeset -g _YSU_CMD_HAD_TIPS=false
  [[ $_YSU_LAST_TIP_TIME -ne $_ysu_tip_time_before ]] && _YSU_CMD_HAD_TIPS=true

  _ysu_flush
}

_ysu_precmd() {
  local last_exit=$?

  # Bail out if plugin is disabled
  [[ "$YSU_DISABLED" == "true" ]] && return

  # Flush any remaining buffered messages (fallback)
  if [[ ${#_YSU_MESSAGES} -gt 0 ]]; then
    _ysu_flush
  fi

  # LLM: display completed async results from previous commands
  if [[ "$YSU_LLM_ENABLED" == "true" ]]; then
    [[ "$YSU_LLM_MODE" != "multi" ]] && _ysu_llm_check_async
    [[ "$YSU_LLM_MODE" != "single" ]] && _ysu_multi_check_async
  fi

  # LLM: evaluate triggers for the just-finished command
  if [[ "$YSU_LLM_ENABLED" == "true" && -n "$_YSU_LLM_PENDING_CMD" ]]; then
    # Single-command mode
    if [[ "$YSU_LLM_MODE" != "multi" ]]; then
      if _ysu_llm_should_trigger "$_YSU_LLM_PENDING_CMD" "$last_exit"; then
        local cache_key
        cache_key=$(_ysu_llm_cache_key "$_YSU_LLM_PENDING_CMD")
        local cache_file="${YSU_LLM_CACHE_DIR}/${cache_key}"

        if [[ -f "$cache_file" ]]; then
          local cached=""
          [[ -s "$cache_file" ]] && cached=$(<"$cache_file")
          [[ -n "$cached" ]] && echo -e "$(_ysu_format "$YSU_LLM_PREFIX" "$cached")"
        else
          _ysu_llm_query_async "$_YSU_LLM_PENDING_CMD"
        fi
      fi
    fi

    # Multi-command mode
    if [[ "$YSU_LLM_MODE" != "single" ]]; then
      if _ysu_multi_should_trigger; then
        _ysu_multi_query_async
      fi
    fi

    _YSU_LLM_PENDING_CMD=""
  fi

  # Show LLM promo when no tips were shown for this command
  if [[ "$_YSU_CMD_HAD_TIPS" == "false" ]]; then
    _ysu_maybe_show_promo
  fi
}

# Register hooks (append, don't overwrite)
autoload -Uz add-zsh-hook
add-zsh-hook preexec _ysu_preexec
add-zsh-hook precmd _ysu_precmd

# ============================================================================
# Interactive configuration: ysu command
# ============================================================================

_ysu_install_method() {
  local plugin_dir="${0:A:h}"
  if [[ "$plugin_dir" == *"/Cellar/"* ]] || [[ "$plugin_dir" == *"/homebrew/"* ]]; then
    echo "homebrew"
  elif [[ -n "$ZSH_CUSTOM" && "$plugin_dir" == "$ZSH_CUSTOM"* ]]; then
    echo "oh-my-zsh"
  elif [[ -n "${ZINIT[HOME_DIR]}" && "$plugin_dir" == "${ZINIT[HOME_DIR]}"* ]] || \
       [[ "$plugin_dir" == *"/.zinit/"* ]] || [[ "$plugin_dir" == *"/zinit/"* ]]; then
    echo "zinit"
  elif [[ -n "$ZPLUG_HOME" && "$plugin_dir" == "$ZPLUG_HOME"* ]]; then
    echo "zplug"
  elif [[ -n "$ANTIDOTE_HOME" && "$plugin_dir" == "$ANTIDOTE_HOME"* ]] || \
       [[ "$plugin_dir" == *"/antidote/"* ]]; then
    echo "antidote"
  elif [[ -d "$plugin_dir/.git" ]]; then
    echo "git"
  else
    echo "unknown"
  fi
}

ysu() {
  case "${1:-help}" in
    config) _ysu_config_wizard ;;
    cache)
      case "${2:-help}" in
        clear)
          rm -f "${YSU_LLM_CACHE_DIR}"/* 2>/dev/null
          rm -f "${YSU_LLM_CACHE_DIR}"/.pending.* 2>/dev/null
          echo "LLM cache cleared."
          ;;
        size)
          local count
          count=$(find "$YSU_LLM_CACHE_DIR" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
          echo "${count} cached suggestions"
          ;;
        *) echo "Usage: ysu cache [clear|size]" ;;
      esac
      ;;
    status) _ysu_status ;;
    doctor) _ysu_doctor ;;
    discover) _ysu_discover "${@:2}" ;;
    update)
      local method
      method=$(_ysu_install_method)
      case "$method" in
        homebrew)
          echo "Installed via Homebrew. Run:"
          echo "  brew upgrade you-should-use"
          ;;
        oh-my-zsh)
          echo "Installed via oh-my-zsh. Run:"
          echo "  git -C \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use pull"
          ;;
        zinit)
          echo "Installed via zinit. Run:"
          echo "  zinit update vangie/you-should-use"
          ;;
        zplug)
          echo "Installed via zplug. Run:"
          echo "  zplug update vangie/you-should-use"
          ;;
        antidote)
          echo "Installed via antidote. Run:"
          echo "  antidote update vangie/you-should-use"
          ;;
        git)
          echo "Updating you-should-use..."
          git -C "${0:A:h}" pull --ff-only && echo "Updated. Restart your shell: exec \$SHELL"
          ;;
        *) echo "Unknown install method. Update manually from https://github.com/vangie/you-should-use" ;;
      esac
      ;;
    uninstall)
      local method
      method=$(_ysu_install_method)
      case "$method" in
        homebrew)
          echo "Installed via Homebrew. Run:"
          echo "  brew uninstall you-should-use"
          ;;
        oh-my-zsh)
          echo "Installed via oh-my-zsh. To uninstall:"
          echo "  1. Remove 'you-should-use' from plugins=(...) in ~/.zshrc"
          echo "  2. rm -rf \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use"
          ;;
        zinit)
          echo "Installed via zinit. To uninstall:"
          echo "  1. Remove the zinit light/load line from ~/.zshrc"
          echo "  2. zinit delete vangie/you-should-use"
          ;;
        zplug)
          echo "Installed via zplug. To uninstall:"
          echo "  1. Remove the zplug line from ~/.zshrc"
          echo "  2. zplug clean"
          ;;
        antidote)
          echo "Installed via antidote. To uninstall:"
          echo "  1. Remove vangie/you-should-use from .zsh_plugins.txt"
          echo "  2. antidote update"
          ;;
        git)
          local plugin_dir="${0:A:h}"
          echo "Uninstalling you-should-use..."
          # Remove source line from rc files
          local rc_file="$HOME/.zshrc"
          if [[ -f "$rc_file" ]]; then
            local tmp_file
            tmp_file=$(mktemp)
            grep -vF "you-should-use" "$rc_file" > "$tmp_file" && mv "$tmp_file" "$rc_file"
            echo "Cleaned $rc_file"
          fi
          # Remove plugin directory
          rm -rf "$plugin_dir"
          echo "Removed $plugin_dir"
          # Remove config and cache
          rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/ysu"
          rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ysu"
          echo "Uninstalled. Restart your shell: exec \$SHELL"
          ;;
        *) echo "Unknown install method. Uninstall manually." ;;
      esac
      ;;
    *)
      echo "Usage: ysu <command>"
      echo "Commands:"
      echo "  config      Configure you-should-use interactively"
      echo "  cache       Manage LLM suggestion cache"
      echo "  status      Show current configuration and statistics"
      echo "  doctor      Run diagnostics and check for issues"
      echo "  discover    Analyze history and suggest aliases"
      echo "  update      Update you-should-use to the latest version"
      echo "  uninstall   Remove you-should-use from your system"
      ;;
  esac
}

_ysu_status() {
  local green="$_YSU_C_OK" red="$_YSU_C_ERR" yellow="$_YSU_C_HINT" cyan="$_YSU_C_COMMAND" bold="$_YSU_C_BOLD" reset="$_YSU_C_RESET"
  local check="${green}✓${reset}" cross="${red}✗${reset}"

  echo ""
  echo -e "${bold}📊 you-should-use status${reset}"
  echo "─────────────────────────"

  # Core Settings
  echo -e "${bold}Core Settings:${reset}"
  if [[ "$YSU_DISABLED" == "true" ]]; then
    echo -e "  Plugin:             ${cross} disabled (YSU_DISABLED=true)"
  fi
  echo -e "  Alias Reminders:    $([[ "$YSU_REMINDER_ENABLED" == "true" ]] && echo "${check} enabled" || echo "${cross} disabled")"
  echo -e "  Modern Suggestions: $([[ "$YSU_SUGGEST_ENABLED" == "true" ]] && echo "${check} enabled" || echo "${cross} disabled")"
  echo -e "  Prefix:             \"${YSU_PREFIX}\""
  echo -e "  Probability:        ${YSU_PROBABILITY}%"
  echo -e "  Cooldown:           ${YSU_COOLDOWN}s"
  echo -e "  Install Hints:      $([[ "$YSU_INSTALL_HINT" == "true" ]] && echo "${check} enabled" || echo "${cross} disabled")"
  echo -e "  Package Manager:    ${_YSU_PKG_MANAGER}$([[ "$_YSU_IS_WSL" == "true" ]] && echo " (WSL)")"
  if [[ "$YSU_MESSAGE_FORMAT" != "{prefix} {arrow} {message}" ]]; then
    echo -e "  Message Format:     ${YSU_MESSAGE_FORMAT}"
  fi
  if [[ -n "$YSU_IGNORE_ALIASES" ]]; then
    echo -e "  Ignored Aliases:    ${YSU_IGNORE_ALIASES}"
  fi
  if [[ -n "$YSU_IGNORE_COMMANDS" ]]; then
    echo -e "  Ignored Commands:   ${YSU_IGNORE_COMMANDS}"
  fi

  # LLM Settings
  echo ""
  echo -e "${bold}LLM Settings:${reset}"
  local llm_status
  if [[ "$YSU_LLM_ENABLED" == "true" ]]; then
    llm_status="${check} enabled"
    # Check if it was auto-detected via Ollama
    if [[ -n "$_YSU_OLLAMA_CHECKED" ]]; then
      # If config file doesn't explicitly set it, it was auto-detected
      local _ysu_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.zsh"
      if [[ -f "$_ysu_cfg" ]] && grep -q 'YSU_LLM_ENABLED' "$_ysu_cfg" 2>/dev/null; then
        llm_status="${llm_status} (user configured)"
      else
        llm_status="${llm_status} (auto-detected Ollama)"
      fi
    fi
  else
    llm_status="${cross} disabled"
  fi
  echo -e "  Enabled:            ${llm_status}"
  echo -e "  API URL:            ${YSU_LLM_API_URL}"
  if [[ "$YSU_LLM_MODEL" == "auto" ]]; then
    if [[ -n "$_YSU_LLM_RESOLVED_MODEL" ]]; then
      echo -e "  Model:              auto (${_YSU_LLM_RESOLVED_MODEL})"
    else
      echo -e "  Model:              auto (unresolved)"
    fi
  else
    echo -e "  Model:              ${YSU_LLM_MODEL}"
  fi
  if [[ -n "$YSU_LLM_API_KEY" ]]; then
    echo -e "  API Key:            ••••${YSU_LLM_API_KEY: -4}"
  else
    echo -e "  API Key:            (not set)"
  fi

  # Cache stats
  local cache_count=0
  if [[ -d "$YSU_LLM_CACHE_DIR" ]]; then
    cache_count=$(find "$YSU_LLM_CACHE_DIR" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo -e "  Mode:               ${YSU_LLM_MODE}"
  if [[ "$YSU_LLM_MODE" != "single" ]]; then
    echo -e "  Window Size:        ${YSU_LLM_WINDOW_SIZE} commands"
    echo -e "  History Buffer:     ${#_YSU_CMD_HISTORY} commands"
  fi
  echo -e "  Cache:              ${cache_count} entries"

  # Statistics
  echo ""
  echo -e "${bold}Statistics:${reset}"

  # Count aliases
  local alias_count=${#aliases}
  echo -e "  Aliases defined:    ${alias_count}"

  # Count modern tool mappings
  local modern_count=${#YSU_MODERN_COMMANDS}
  echo -e "  Modern mappings:    ${modern_count}"

  # Promo stats
  if [[ "$YSU_LLM_ENABLED" == "false" ]]; then
    echo -e "  Promo shown today:  ${_YSU_PROMO_SHOWN_TODAY}/3"
  fi

  # Config file
  echo ""
  echo -e "${bold}Config File:${reset}"
  local cfg_file="${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.zsh"
  if [[ -f "$cfg_file" ]]; then
    echo -e "  ${check} ${cfg_file}"
  else
    echo -e "  (using defaults — run ${_YSU_C_HINT}ysu config${_YSU_C_RESET} to customize)"
  fi
  echo ""
}

_ysu_discover() {
  local min_count=${1:-5}  # minimum occurrences to suggest
  local min_words=2        # minimum words in command to be worth aliasing
  local bold="$_YSU_C_BOLD" reset="$_YSU_C_RESET" cyan="$_YSU_C_COMMAND" yellow="$_YSU_C_HINT" green="$_YSU_C_OK"

  echo ""
  echo -e "${bold}🔍 Alias Discovery${reset}"
  echo "─────────────────────────"
  echo -e "Analyzing history for commands used >= ${min_count} times..."
  echo ""

  # Get history file
  local histfile="${HISTFILE:-$HOME/.zsh_history}"
  if [[ ! -f "$histfile" ]]; then
    echo "No history file found at ${histfile}"
    return 1
  fi

  # Get existing aliases and abbreviations for filtering
  local -A existing_aliases
  local alias_name alias_value
  for alias_name alias_value in ${(kv)aliases}; do
    existing_aliases[$alias_value]="$alias_name"
  done

  # Parse history: extract command prefixes (first 2-3 words), count them
  # Zsh history format: ": timestamp:0;command" or just "command"
  local -A cmd_counts
  local line cmd prefix
  while IFS= read -r line; do
    # Strip zsh extended history format
    cmd="${line#*;}"
    [[ -z "$cmd" ]] && continue
    # Skip very short commands
    local words=( ${(z)cmd} )
    (( ${#words} < min_words )) && continue
    # Use first 2 words as prefix (covers 90% of cases like "git checkout")
    prefix="${words[1]} ${words[2]}"
    # Skip if it starts with internal functions or common builtins
    [[ "$prefix" == _ysu_* || "$prefix" == "cd "* || "$prefix" == "echo "* ]] && continue
    cmd_counts[$prefix]=$(( ${cmd_counts[$prefix]:-0} + 1 ))
    # Also try 3-word prefix for things like "git checkout -b"
    if (( ${#words} >= 3 )); then
      local prefix3="${words[1]} ${words[2]} ${words[3]}"
      cmd_counts[$prefix3]=$(( ${cmd_counts[$prefix3]:-0} + 1 ))
    fi
  done < "$histfile"

  # Sort by count (descending) and display suggestions
  local found=0
  local prefix count
  for prefix count in ${(kv)cmd_counts}; do
    (( count < min_count )) && continue

    # Skip if already aliased
    [[ -n "${existing_aliases[$prefix]}" ]] && continue

    # Generate alias name suggestion
    local suggestion=$(_ysu_suggest_alias_name "$prefix")

    echo -e "  ${cyan}${prefix}${reset}  (used ${yellow}${count}${reset} times)"
    echo -e "    ${green}alias ${suggestion}='${prefix}'${reset}"
    echo ""
    ((found++))
  done | sort -t'(' -k2 -rn | head -30

  if (( found == 0 )); then
    echo "No alias suggestions found. Try lowering the threshold: ysu discover 3"
  fi
  echo ""
}

_ysu_suggest_alias_name() {
  local cmd="$1"
  local words=( ${(z)cmd} )
  local name=""
  local word
  for word in "${words[@]}"; do
    # Skip flags
    [[ "$word" == -* ]] && continue
    # Take first letter of each word
    name+="${word[1]}"
  done
  # If too short, use first letters of all words including flags
  if (( ${#name} < 2 )); then
    name=""
    for word in "${words[@]}"; do
      name+="${word[1]}"
    done
  fi
  echo "${(L)name}"
}

_ysu_doctor() {
  local green="$_YSU_C_OK" red="$_YSU_C_ERR" yellow="$_YSU_C_HINT" bold="$_YSU_C_BOLD" reset="$_YSU_C_RESET"
  local check="${green}✓${reset}" cross="${red}✗${reset}" warn="${yellow}!${reset}"
  local issues=0

  echo ""
  echo -e "${bold}🩺 you-should-use doctor${reset}"
  echo "─────────────────────────"

  # 1. Shell compatibility
  echo -e "${bold}Shell:${reset}"
  echo -e "  ${check} Zsh ${ZSH_VERSION}"
  if [[ -n "$ZSH_VERSION" ]]; then
    local major=${ZSH_VERSION%%.*}
    if (( major >= 5 )); then
      echo -e "  ${check} Zsh version >= 5.0 (required)"
    else
      echo -e "  ${cross} Zsh version < 5.0 — some features may not work"
      ((issues++))
    fi
  fi

  # 2. Plugin load
  echo ""
  echo -e "${bold}Plugin:${reset}"
  # Check if preexec/precmd hooks are registered
  if [[ "${preexec_functions[(r)_ysu_preexec]}" == "_ysu_preexec" ]]; then
    echo -e "  ${check} preexec hook registered"
  else
    echo -e "  ${cross} preexec hook NOT registered — alias reminders won't work"
    ((issues++))
  fi
  if [[ "${precmd_functions[(r)_ysu_precmd]}" == "_ysu_precmd" ]]; then
    echo -e "  ${check} precmd hook registered"
  else
    echo -e "  ${cross} precmd hook NOT registered — LLM results won't display"
    ((issues++))
  fi

  # Plugin load time
  local load_time
  load_time=$( TIMEFORMAT='%3R'; { time zsh -c "source '${0:A:h}/you-should-use.plugin.zsh'" ; } 2>&1 )
  echo -e "  Plugin load time:   ${load_time}s"
  # Compare as integer (ms)
  local ms=${load_time//./}
  ms=${ms##0}
  if (( ${ms:-0} > 500 )); then
    echo -e "  ${warn} Load time > 0.5s — consider disabling Ollama auto-detect if slow"
    ((issues++))
  fi

  # 3. Config conflicts
  echo ""
  echo -e "${bold}Config:${reset}"
  local cfg_file="${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.zsh"
  if [[ -f "$cfg_file" ]]; then
    echo -e "  ${check} Config file: ${cfg_file}"
    # Check for common issues
    if grep -q 'YSU_PROBABILITY=0' "$cfg_file" 2>/dev/null; then
      echo -e "  ${warn} YSU_PROBABILITY=0 — tips will never show"
      ((issues++))
    fi
    if grep -q 'YSU_REMINDER_ENABLED=false' "$cfg_file" 2>/dev/null && \
       grep -q 'YSU_SUGGEST_ENABLED=false' "$cfg_file" 2>/dev/null && \
       grep -q 'YSU_LLM_ENABLED=false' "$cfg_file" 2>/dev/null; then
      echo -e "  ${warn} All features disabled — plugin is doing nothing"
      ((issues++))
    fi
  else
    echo -e "  ${check} No config file (using defaults)"
  fi
  if (( YSU_PROBABILITY < 1 || YSU_PROBABILITY > 100 )); then
    echo -e "  ${cross} YSU_PROBABILITY=${YSU_PROBABILITY} — must be 1-100"
    ((issues++))
  fi
  if (( YSU_COOLDOWN < 0 )); then
    echo -e "  ${cross} YSU_COOLDOWN=${YSU_COOLDOWN} — must be >= 0"
    ((issues++))
  fi

  # 4. Package manager
  echo ""
  echo -e "${bold}Package Manager:${reset}"
  if [[ "$_YSU_PKG_MANAGER" != "unknown" ]]; then
    echo -e "  ${check} Detected: ${_YSU_PKG_MANAGER}"
  else
    echo -e "  ${warn} No package manager detected — install hints will be empty"
    ((issues++))
  fi

  # 5. LLM connection
  echo ""
  echo -e "${bold}LLM:${reset}"
  if [[ "$YSU_LLM_ENABLED" == "true" ]]; then
    echo -e "  ${check} LLM enabled"

    # Test connection
    local test_url="${YSU_LLM_API_URL%/chat/completions}"
    if [[ "$test_url" == *"localhost:11434"* || "$test_url" == *"127.0.0.1:11434"* ]]; then
      # Ollama — test /api/tags
      local ollama_resp
      ollama_resp=$(curl -s --max-time 3 "http://localhost:11434/api/tags" 2>/dev/null)
      if [[ -n "$ollama_resp" ]]; then
        echo -e "  ${check} Ollama reachable"
        local model=$(_ysu_get_effective_model)
        if [[ -n "$model" ]]; then
          echo -e "  ${check} Model: ${model}"
        else
          echo -e "  ${cross} No model resolved — run 'ollama pull qwen2.5-coder:7b'"
          ((issues++))
        fi
      else
        echo -e "  ${cross} Ollama not reachable at localhost:11434"
        ((issues++))
      fi
    else
      # Generic API test
      local api_resp
      api_resp=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer ${YSU_LLM_API_KEY}" \
        "${YSU_LLM_API_URL}" 2>/dev/null)
      if [[ "$api_resp" =~ ^[23] ]]; then
        echo -e "  ${check} API reachable (HTTP ${api_resp})"
      else
        echo -e "  ${cross} API not reachable: ${YSU_LLM_API_URL} (HTTP ${api_resp})"
        ((issues++))
      fi
    fi

    # Cache dir
    if [[ -d "$YSU_LLM_CACHE_DIR" && -w "$YSU_LLM_CACHE_DIR" ]]; then
      echo -e "  ${check} Cache dir writable: ${YSU_LLM_CACHE_DIR}"
    else
      echo -e "  ${cross} Cache dir not writable: ${YSU_LLM_CACHE_DIR}"
      ((issues++))
    fi
  else
    echo -e "  LLM disabled (not tested)"
  fi

  # 6. Dependencies
  echo ""
  echo -e "${bold}Dependencies:${reset}"
  for dep in curl jq md5 md5sum; do
    if command -v "$dep" &>/dev/null; then
      echo -e "  ${check} ${dep}"
    else
      if [[ "$dep" == "jq" ]]; then
        echo -e "  ${warn} ${dep} (optional — used for Ollama model detection)"
      elif [[ "$dep" == "md5sum" ]]; then
        # macOS has md5, Linux has md5sum — only warn if neither
        command -v md5 &>/dev/null || { echo -e "  ${warn} ${dep} (needed for LLM cache)"; ((issues++)); }
      else
        echo -e "  ${check} ${dep} not found (using fallback)"
      fi
    fi
  done

  # Summary
  echo ""
  if (( issues == 0 )); then
    echo -e "${green}${bold}No issues found!${reset}"
  else
    echo -e "${yellow}${bold}${issues} issue(s) found${reset}"
  fi
  echo ""
}

_ysu_config_wizard() {
  local _script="${0:A:h}/bin/ysu-config.sh"
  local _config_file="${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.zsh"
  export YSU_REMINDER_ENABLED YSU_SUGGEST_ENABLED YSU_LLM_ENABLED
  export YSU_PROBABILITY YSU_COOLDOWN
  export YSU_LLM_API_URL YSU_LLM_API_KEY YSU_LLM_MODEL YSU_LLM_MODE
  export YSU_INSTALL_HINT YSU_MESSAGE_FORMAT
  export YSU_THEME YSU_DARK_THEME YSU_LIGHT_THEME
  bash "$_script" --format zsh
  [[ -f "$_config_file" ]] && source "$_config_file"
  _ysu_init_colors
}
