#!/usr/bin/env bash
# you-should-use - Alias reminders & modern command suggestions for Bash
# https://github.com/vangie/you-should-use
# MIT License
#
# Requires: Bash 3.2+ (uses parallel arrays for Bash 3 compat)
# Source this file in your .bashrc

# Guard against double-loading
[[ -n "$_YSU_LOADED" ]] && return
_YSU_LOADED=1

# Source user config if it exists (before defaults so user values take priority)
_ysu_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ysu"
[[ -f "$_ysu_config_dir/config.bash" ]] && source "$_ysu_config_dir/config.bash"

# ============================================================================
# Configuration (override these in your .bashrc BEFORE sourcing the plugin)
# ============================================================================

# Feature toggles
: "${YSU_REMINDER_ENABLED:=true}"
: "${YSU_SUGGEST_ENABLED:=true}"
: "${YSU_LLM_ENABLED:=false}"

# Display settings
: "${YSU_PREFIX:=💡}"
: "${YSU_REMINDER_PREFIX:=}"
: "${YSU_SUGGEST_PREFIX:=}"
: "${YSU_LLM_PREFIX:=🤖}"

# Frequency control
: "${YSU_PROBABILITY:=100}"
: "${YSU_COOLDOWN:=0}"

# Exclusions
: "${YSU_IGNORE_ALIASES:=}"
: "${YSU_IGNORE_COMMANDS:=}"
: "${YSU_INSTALL_HINT:=true}"

# Message template
: "${YSU_MESSAGE_FORMAT:={prefix} {arrow} {message}}"

# Theme settings
: "${YSU_THEME:=dark}"
: "${YSU_DARK_THEME:=tokyo-night}"
: "${YSU_LIGHT_THEME:=solarized}"

# Available themes (dark: tokyo-night, dracula, monokai, catppuccin-mocha)
#                  (light: solarized, catppuccin-latte, github)
_ysu_init_colors() {
  local theme_name
  if [[ "$YSU_THEME" == "light" ]]; then
    theme_name="$YSU_LIGHT_THEME"
  else
    theme_name="$YSU_DARK_THEME"
  fi

  local arrow highlight command dim hint ok err bold
  case "$theme_name" in
    tokyo-night)      arrow='\e[1;93m' highlight='\e[1;31m' command='\e[1;36m' dim='\e[3m' hint='\e[1;33m' ok='\e[32m' err='\e[31m' bold='\e[1m' ;;
    dracula)          arrow='\e[38;5;141m' highlight='\e[1;38;5;212m' command='\e[38;5;117m' dim='\e[3;38;5;103m' hint='\e[38;5;84m' ok='\e[32m' err='\e[31m' bold='\e[1m' ;;
    monokai)          arrow='\e[38;5;208m' highlight='\e[1;38;5;197m' command='\e[38;5;148m' dim='\e[3;38;5;242m' hint='\e[38;5;186m' ok='\e[32m' err='\e[31m' bold='\e[1m' ;;
    catppuccin-mocha) arrow='\e[38;5;180m' highlight='\e[1;38;5;211m' command='\e[38;5;153m' dim='\e[3;38;5;103m' hint='\e[38;5;223m' ok='\e[32m' err='\e[31m' bold='\e[1m' ;;
    solarized)        arrow='\e[1;33m' highlight='\e[1;31m' command='\e[1;34m' dim='\e[3;2m' hint='\e[1;35m' ok='\e[32m' err='\e[31m' bold='\e[1m' ;;
    catppuccin-latte) arrow='\e[38;5;136m' highlight='\e[1;38;5;124m' command='\e[38;5;25m' dim='\e[3;38;5;145m' hint='\e[38;5;133m' ok='\e[32m' err='\e[31m' bold='\e[1m' ;;
    github)           arrow='\e[38;5;130m' highlight='\e[1;38;5;124m' command='\e[38;5;24m' dim='\e[3;38;5;246m' hint='\e[38;5;90m' ok='\e[32m' err='\e[31m' bold='\e[1m' ;;
    *)                arrow='\e[1;93m' highlight='\e[1;31m' command='\e[1;36m' dim='\e[3m' hint='\e[1;33m' ok='\e[32m' err='\e[31m' bold='\e[1m' ;;
  esac

  _YSU_C_ARROW="${YSU_COLOR_ARROW:-$arrow}"
  _YSU_C_HIGHLIGHT="${YSU_COLOR_HIGHLIGHT:-$highlight}"
  _YSU_C_COMMAND="${YSU_COLOR_COMMAND:-$command}"
  _YSU_C_DIM="${YSU_COLOR_DIM:-$dim}"
  _YSU_C_HINT="${YSU_COLOR_HINT:-$hint}"
  _YSU_C_OK="${YSU_COLOR_OK:-$ok}"
  _YSU_C_ERR="${YSU_COLOR_ERR:-$err}"
  _YSU_C_BOLD="${YSU_COLOR_BOLD:-$bold}"
  _YSU_C_RESET='\e[0m'
}
_ysu_init_colors

# LLM settings
: "${YSU_LLM_API_URL:=http://localhost:11434/v1/chat/completions}"
: "${YSU_LLM_API_KEY:=}"
: "${YSU_LLM_MODEL:=auto}"
: "${YSU_LLM_CACHE_DIR:=$HOME/.cache/ysu}"
: "${YSU_LLM_MODE:=single}"
: "${YSU_LLM_WINDOW_SIZE:=5}"

# ============================================================================
# Ollama auto-detection (runs once at plugin load, not every command)
# ============================================================================

_YSU_LLM_RESOLVED_MODEL=""

if [[ -z "$_YSU_OLLAMA_CHECKED" ]]; then
  _YSU_OLLAMA_CHECKED=1
  if [[ "$YSU_LLM_ENABLED" == "false" ]]; then
    _ysu_user_set_llm=false
    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.bash" ]]; then
      grep -q 'YSU_LLM_ENABLED' "${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.bash" 2>/dev/null && _ysu_user_set_llm=true
    fi
    if [[ "$_ysu_user_set_llm" == "false" ]]; then
      _ysu_ollama_tags=$(curl -s --max-time 2 "http://localhost:11434/api/tags" 2>/dev/null)
      if [[ -n "$_ysu_ollama_tags" ]]; then
        if [[ "$YSU_LLM_MODEL" == "auto" ]]; then
          _ysu_first_model=""
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
          if echo "$_ysu_ollama_tags" | grep -q "\"${YSU_LLM_MODEL}\"" 2>/dev/null; then
            _YSU_LLM_RESOLVED_MODEL="$YSU_LLM_MODEL"
            YSU_LLM_ENABLED=true
          fi
        fi
      fi
      unset _ysu_ollama_tags _ysu_first_model
    fi
    unset _ysu_user_set_llm
  fi
fi

# Resolve model for non-auto-detect cases
if [[ "$YSU_LLM_ENABLED" == "true" && -z "$_YSU_LLM_RESOLVED_MODEL" ]]; then
  if [[ "$YSU_LLM_MODEL" == "auto" ]]; then
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
    unset _ysu_tags
  else
    _YSU_LLM_RESOLVED_MODEL="$YSU_LLM_MODEL"
  fi
fi

# ============================================================================
# Modern command alternatives mapping (parallel arrays, Bash 3 compatible)
# ============================================================================

if [[ -z "${YSU_MODERN_KEYS+x}" ]]; then
  YSU_MODERN_KEYS=(
    cat ls find grep du top ps diff sed curl ping dig man cd df xxd make wget time history cloc tree traceroute tmux vim
  )
  YSU_MODERN_VALS=(
    "bat:Syntax highlighting, line numbers, git integration|glow:Terminal Markdown renderer"
    "eza:Modern file listing with icons, git status, tree view|lsd:LSDeluxe - colorful ls with icons"
    "fd:Simpler syntax, faster, respects .gitignore"
    "rg:Ripgrep - faster, respects .gitignore, better defaults|ag:The Silver Searcher - fast code search"
    "dust:Intuitive disk usage with visual chart|ncdu:NCurses disk usage analyzer"
    "btop:Beautiful resource monitor with mouse support|htop:Interactive process viewer"
    "procs:Modern process viewer with tree display"
    "delta:Syntax highlighting, side-by-side view, git integration|colordiff:Colorized diff output"
    "sd:Simpler syntax, uses regex by default"
    "httpie:Human-friendly HTTP client (command: http)|curlie:Curl with httpie-like interface"
    "gping:Ping with a graph"
    "dog:DNS client with colorful output"
    "tldr:Simplified, community-driven man pages"
    "zoxide:Smarter cd that learns your habits (command: z)"
    "duf:Disk usage with colorful output and device overview"
    "hexyl:Colorful hex viewer with modern UI"
    "just:Simpler command runner, no tabs required"
    "xh:Fast, friendly HTTP client (like httpie but faster)"
    "hyperfine:Benchmarking tool with statistical analysis"
    "mcfly:Intelligent shell history search with neural network|atuin:Magical shell history with sync"
    "tokei:Fast code line counter with language breakdown"
    "broot:Interactive directory tree with fuzzy search"
    "mtr:Combined traceroute and ping with live display"
    "zellij:Modern terminal multiplexer with intuitive UI"
    "nvim:Neovim - modernized Vim fork"
  )
fi

# Context-aware suggestions: suggest tools based on command + file extension
# Parallel arrays: YSU_CONTEXT_KEYS[i] = "command:.ext", YSU_CONTEXT_VALS[i] = "tool:description"
if [[ -z "${YSU_CONTEXT_KEYS+x}" ]]; then
  YSU_CONTEXT_KEYS=("diff:.json" "diff:.yaml" "diff:.yml")
  YSU_CONTEXT_VALS=(
    "jd:JSON diff and patch tool"
    "jd:JSON diff and patch tool (also handles YAML)"
    "jd:JSON diff and patch tool (also handles YAML)"
  )
fi

# ============================================================================
# Platform detection for install hints
# ============================================================================

_ysu_detect_pkg_manager() {
  # WSL detection
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    _YSU_IS_WSL=true
  else
    _YSU_IS_WSL=false
  fi

  if command -v brew &>/dev/null; then
    _YSU_PKG_MANAGER="brew"
    _YSU_PKG_INSTALL="brew install"
  elif command -v apt &>/dev/null; then
    _YSU_PKG_MANAGER="apt"
    _YSU_PKG_INSTALL="sudo apt install"
  elif command -v pacman &>/dev/null; then
    _YSU_PKG_MANAGER="pacman"
    _YSU_PKG_INSTALL="sudo pacman -S"
  elif command -v dnf &>/dev/null; then
    _YSU_PKG_MANAGER="dnf"
    _YSU_PKG_INSTALL="sudo dnf install"
  elif command -v zypper &>/dev/null; then
    _YSU_PKG_MANAGER="zypper"
    _YSU_PKG_INSTALL="sudo zypper install"
  elif command -v apk &>/dev/null; then
    _YSU_PKG_MANAGER="apk"
    _YSU_PKG_INSTALL="apk add"
  elif command -v pkg &>/dev/null; then
    _YSU_PKG_MANAGER="pkg"
    _YSU_PKG_INSTALL="pkg install"
  else
    _YSU_PKG_MANAGER="unknown"
    _YSU_PKG_INSTALL=""
  fi
}
_ysu_detect_pkg_manager

# Package name overrides per manager (parallel arrays)
_YSU_PKG_OVERRIDE_KEYS_brew=(rg ag delta)
_YSU_PKG_OVERRIDE_VALS_brew=(ripgrep the_silver_searcher git-delta)

_YSU_PKG_OVERRIDE_KEYS_apt=(rg ag delta fd dust)
_YSU_PKG_OVERRIDE_VALS_apt=(ripgrep silversearcher-ag git-delta fd-find du-dust)

_YSU_PKG_OVERRIDE_KEYS_pacman=(rg ag delta)
_YSU_PKG_OVERRIDE_VALS_pacman=(ripgrep the_silver_searcher git-delta)

_YSU_PKG_OVERRIDE_KEYS_dnf=(rg ag delta)
_YSU_PKG_OVERRIDE_VALS_dnf=(ripgrep the_silver_searcher git-delta)

_ysu_get_pkg_name() {
  local tool="$1"
  local keys_var="_YSU_PKG_OVERRIDE_KEYS_${_YSU_PKG_MANAGER}"
  local vals_var="_YSU_PKG_OVERRIDE_VALS_${_YSU_PKG_MANAGER}"
  # Use eval for indirect array access (Bash 3.2 compat)
  local keys_count
  eval "keys_count=\${#${keys_var}[@]}" 2>/dev/null || { echo "$tool"; return; }
  local i
  for (( i=0; i<keys_count; i++ )); do
    local k v
    eval "k=\${${keys_var}[$i]}"
    if [[ "$k" == "$tool" ]]; then
      eval "v=\${${vals_var}[$i]}"
      echo "$v"
      return
    fi
  done
  echo "$tool"
}

# Install command hints (parallel arrays)
# Auto-generated based on detected package manager
if [[ -z "${YSU_INSTALL_KEYS+x}" ]]; then
  YSU_INSTALL_KEYS=(
    bat eza lsd fd rg ag dust ncdu btop htop procs delta colordiff sd httpie curlie gping dog tldr zoxide duf hexyl just xh hyperfine mcfly atuin glow tokei broot mtr zellij
  )
  YSU_INSTALL_VALS=()
  if [[ -n "$_YSU_PKG_INSTALL" ]]; then
    for _ysu_t in "${YSU_INSTALL_KEYS[@]}"; do
      YSU_INSTALL_VALS+=("${_YSU_PKG_INSTALL} $(_ysu_get_pkg_name "$_ysu_t")")
    done
    unset _ysu_t
  fi
fi

# ============================================================================
# Internal state
# ============================================================================

_YSU_LAST_TIP_TIME=0
_YSU_MESSAGES=()
_YSU_LLM_PENDING_CMD=""
_YSU_LLM_ASYNC_FILE=""
_YSU_LLM_ASYNC_CMD=""
_YSU_PROMO_SHOWN_TODAY=0
_YSU_PROMO_DATE=""
_YSU_CMD_HISTORY=()
_YSU_MULTI_ASYNC_FILE=""
_YSU_MULTI_ASYNC_KEY=""
_YSU_CMD_HAD_TIPS=false
# Guard for DEBUG trap (prevent multiple fires per user command)
_YSU_PREEXEC_READY=true

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
  _YSU_MESSAGES+=("$msg")
}

_ysu_flush() {
  local msg
  for msg in "${_YSU_MESSAGES[@]}"; do
    echo -e "$msg"
  done
  _YSU_MESSAGES=()
}

_ysu_now() {
  date +%s
}

_ysu_should_show() {
  # Check cooldown
  if [[ $YSU_COOLDOWN -gt 0 ]]; then
    local now
    now=$(_ysu_now)
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
  _YSU_LAST_TIP_TIME=$(_ysu_now)
}

_ysu_is_ignored_alias() {
  local alias_name="$1"
  local ignored
  for ignored in $YSU_IGNORE_ALIASES; do
    [[ "$ignored" == "$alias_name" ]] && return 0
  done
  return 1
}

_ysu_is_ignored_command() {
  local cmd="$1"
  local ignored
  for ignored in $YSU_IGNORE_COMMANDS; do
    [[ "$ignored" == "$cmd" ]] && return 0
  done
  return 1
}

# Look up a value in parallel arrays by key
# Usage: _ysu_lookup_parallel KEY KEYS_ARRAY_NAME VALS_ARRAY_NAME
# Prints the value if found, empty string otherwise
_ysu_lookup_parallel() {
  local key="$1"
  local -a keys_ref
  local -a vals_ref
  eval "keys_ref=(\"\${${2}[@]}\")"
  eval "vals_ref=(\"\${${3}[@]}\")"
  local i
  for (( i=0; i<${#keys_ref[@]}; i++ )); do
    if [[ "${keys_ref[$i]}" == "$key" ]]; then
      echo "${vals_ref[$i]}"
      return 0
    fi
  done
  return 1
}

# ============================================================================
# Feature 1: Alias Reminders
# ============================================================================

_ysu_check_aliases() {
  [[ "$YSU_REMINDER_ENABLED" != "true" ]] && return

  local typed_command="$1"

  # Strip sudo prefix
  if [[ "$typed_command" == sudo\ * || "$typed_command" == "sudo" ]]; then
    typed_command="${typed_command#sudo}"
    typed_command="${typed_command# }"
  fi
  [[ -z "$typed_command" ]] && return

  local first_word="${typed_command%% *}"
  local found_alias=""
  local found_value=""

  # Parse bash aliases
  local line alias_name alias_value
  while IFS= read -r line; do
    # alias output format: alias name='value'
    [[ "$line" =~ ^alias\ ([^=]+)=\'(.*)\'$ ]] || continue
    alias_name="${BASH_REMATCH[1]}"
    alias_value="${BASH_REMATCH[2]}"

    _ysu_is_ignored_alias "$alias_name" && continue
    [[ "$first_word" == "$alias_name" ]] && continue

    # Check if the typed command starts with the alias value
    if [[ "$typed_command" == "${alias_value}"* ]]; then
      if [[ -z "$found_value" ]] || [[ ${#alias_value} -gt ${#found_value} ]]; then
        found_alias="$alias_name"
        found_value="$alias_value"
      fi
    fi
  done < <(alias 2>/dev/null)

  if [[ -n "$found_alias" ]]; then
    _ysu_buffer "$YSU_REMINDER_PREFIX" \
      "You should use ${_YSU_C_HIGHLIGHT}${found_alias}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${found_value}${_YSU_C_RESET}"
    _ysu_record_tip
  fi
}

# ============================================================================
# Feature 2: Modern Command Suggestions
# ============================================================================

_ysu_check_modern() {
  [[ "$YSU_SUGGEST_ENABLED" != "true" ]] && return

  local typed_command="$1"

  # Strip sudo prefix
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
    for _arg in $_args; do
      _ext="${_arg##*.}"
      [[ "$_ext" != "$_arg" && -n "$_ext" ]] || continue
      _ctx_key="${first_word}:.${_ext}"
      _ctx_entry=$(_ysu_lookup_parallel "$_ctx_key" YSU_CONTEXT_KEYS YSU_CONTEXT_VALS) || continue
      _ctx_cmd="${_ctx_entry%%:*}"
      _ctx_desc="${_ctx_entry#*:}"
      if command -v "$_ctx_cmd" &>/dev/null; then
        _ysu_buffer "$YSU_SUGGEST_PREFIX" \
          "You should use ${_YSU_C_HIGHLIGHT}${_ctx_cmd}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${first_word}${_YSU_C_RESET} — ${_YSU_C_DIM}${_ctx_desc}${_YSU_C_RESET}"
        _ysu_record_tip
        return
      elif [[ "$YSU_INSTALL_HINT" == "true" ]]; then
        local _ctx_install
        _ctx_install=$(_ysu_lookup_parallel "$_ctx_cmd" YSU_INSTALL_KEYS YSU_INSTALL_VALS) || true
        if [[ -n "$_ctx_install" ]]; then
          _ysu_buffer "$YSU_SUGGEST_PREFIX" \
            "Try ${_YSU_C_HIGHLIGHT}${_ctx_cmd}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${first_word}${_YSU_C_RESET} — ${_YSU_C_DIM}${_ctx_desc}${_YSU_C_RESET} (install: ${_YSU_C_HINT}${_ctx_install}${_YSU_C_RESET})"
          _ysu_record_tip
        fi
        return
      fi
    done
  fi

  # Look up the command in our mapping
  local mapping
  mapping=$(_ysu_lookup_parallel "$first_word" YSU_MODERN_KEYS YSU_MODERN_VALS) || return

  # Support multiple alternatives separated by |
  local _first_uninstalled="" _first_uninstalled_desc="" _first_uninstalled_install=""
  local IFS_SAVE="$IFS"
  IFS='|'
  local entries=($mapping)
  IFS="$IFS_SAVE"

  local entry modern_cmd description
  for entry in "${entries[@]}"; do
    modern_cmd="${entry%%:*}"
    description="${entry#*:}"

    if command -v "$modern_cmd" &>/dev/null; then
      # Skip if first_word is already aliased to this modern command
      local alias_val=""
      alias_val=$(alias "$first_word" 2>/dev/null | sed "s/^alias ${first_word}='\\(.*\\)'$/\\1/")
      [[ "${alias_val%% *}" == "$modern_cmd" ]] && return

      _ysu_buffer "$YSU_SUGGEST_PREFIX" \
        "You should use ${_YSU_C_HIGHLIGHT}${modern_cmd}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${first_word}${_YSU_C_RESET} — ${_YSU_C_DIM}${description}${_YSU_C_RESET}"
      _ysu_record_tip
      return
    elif [[ -z "$_first_uninstalled" ]]; then
      _first_uninstalled="$modern_cmd"
      _first_uninstalled_desc="$description"
      _first_uninstalled_install=$(_ysu_lookup_parallel "$modern_cmd" YSU_INSTALL_KEYS YSU_INSTALL_VALS) || true
    fi
  done

  # No installed alternative found — show install hint for the first one
  if [[ "$YSU_INSTALL_HINT" == "true" && -n "$_first_uninstalled" && -n "$_first_uninstalled_install" ]]; then
    _ysu_buffer "$YSU_SUGGEST_PREFIX" \
      "Try ${_YSU_C_HIGHLIGHT}${_first_uninstalled}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}${first_word}${_YSU_C_RESET} — ${_YSU_C_DIM}${_first_uninstalled_desc}${_YSU_C_RESET} (install: ${_YSU_C_HINT}${_first_uninstalled_install}${_YSU_C_RESET})"
    _ysu_record_tip
  fi
}

# ============================================================================
# Feature 3: Sudo alias suggestion
# ============================================================================

_ysu_check_sudo_alias() {
  local inner_command="$1"
  local line alias_name alias_value
  while IFS= read -r line; do
    [[ "$line" =~ ^alias\ ([^=]+)=\'(.*)\'$ ]] || continue
    alias_name="${BASH_REMATCH[1]}"
    alias_value="${BASH_REMATCH[2]}"
    _ysu_is_ignored_alias "$alias_name" && continue
    [[ "$alias_name" == "sudo" ]] && continue
    if [[ "$alias_value" == "sudo" || "$alias_value" == "sudo " ]]; then
      _ysu_buffer "$YSU_REMINDER_PREFIX" \
        "You should use ${_YSU_C_HIGHLIGHT}${alias_name} ${inner_command}${_YSU_C_RESET} instead of ${_YSU_C_COMMAND}sudo ${inner_command}${_YSU_C_RESET}"
      _ysu_record_tip
      return
    fi
  done < <(alias 2>/dev/null)
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
  local -a words=($cmd)
  [[ ${#words[@]} -ge 4 ]] && return 0

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

  (
    local response auth_args=""
    [[ -n "$YSU_LLM_API_KEY" ]] && auth_args="-H \"Authorization: Bearer $YSU_LLM_API_KEY\""

    response=$(curl -s --max-time 10 \
      -H "Content-Type: application/json" \
      ${auth_args:+"$auth_args"} \
      -d "$payload" \
      "$YSU_LLM_API_URL" 2>/dev/null) || true

    local content=""
    [[ -n "$response" ]] && content=$(_ysu_json_extract_content "$response")

    # Trim whitespace
    content="${content#"${content%%[! ]*}"}"
    content="${content%"${content##*[! ]}"}"
    local lower_content
    lower_content=$(echo "$content" | tr '[:upper:]' '[:lower:]')

    if [[ -n "$content" && "$lower_content" != "none" && "$lower_content" != "none." ]]; then
      echo "$content" > "$tmp_file"
    else
      : > "$tmp_file"
    fi
    touch "${tmp_file}.done"
  ) &
  disown 2>/dev/null
}

_ysu_llm_check_async() {
  [[ -z "$_YSU_LLM_ASYNC_FILE" ]] && return

  [[ ! -f "${_YSU_LLM_ASYNC_FILE}.done" ]] && return

  local result=""
  [[ -s "$_YSU_LLM_ASYNC_FILE" ]] && result=$(< "$_YSU_LLM_ASYNC_FILE")

  local cache_key
  cache_key=$(_ysu_llm_cache_key "$_YSU_LLM_ASYNC_CMD")
  local cache_file="${YSU_LLM_CACHE_DIR}/${cache_key}"
  if [[ -n "$result" ]]; then
    echo "$result" > "$cache_file"
    echo -e "$(_ysu_format "$YSU_LLM_PREFIX" "$result")"
  else
    : > "$cache_file"
  fi

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
  while [[ ${#_YSU_CMD_HISTORY[@]} -gt $YSU_LLM_WINDOW_SIZE ]]; do
    _YSU_CMD_HISTORY=("${_YSU_CMD_HISTORY[@]:1}")
  done
}

_ysu_multi_should_trigger() {
  [[ ${#_YSU_CMD_HISTORY[@]} -ge 3 ]] || return 1
  return 0
}

_ysu_multi_query_async() {
  if [[ -n "$_YSU_MULTI_ASYNC_FILE" ]]; then
    rm -f "$_YSU_MULTI_ASYNC_FILE" "${_YSU_MULTI_ASYNC_FILE}.done" 2>/dev/null
  fi

  mkdir -p "$YSU_LLM_CACHE_DIR"
  local tmp_file
  tmp_file=$(mktemp "${YSU_LLM_CACHE_DIR}/.multi.XXXXXX")

  local effective_model
  effective_model=$(_ysu_get_effective_model)
  [[ -z "$effective_model" ]] && return

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
    [[ -s "$cache_file" ]] && cached=$(< "$cache_file")
    [[ -n "$cached" ]] && echo -e "$(_ysu_format "$YSU_LLM_PREFIX" "$cached")"
    return
  fi

  local escaped_cmds
  escaped_cmds=$(_ysu_json_escape "$cmd_sequence")
  local system_prompt="You are a shell workflow expert. Given a sequence of recent shell commands, identify if there is a pattern or workflow that could be optimized. Suggest a single improvement (a combined command, a tool, or a better workflow) in one brief sentence. If there is no improvement, reply with exactly: none"
  local payload="{\"model\":\"${effective_model}\",\"messages\":[{\"role\":\"system\",\"content\":\"${system_prompt}\"},{\"role\":\"user\",\"content\":\"Recent commands:\\n${escaped_cmds}\"}],\"max_tokens\":150,\"temperature\":0.3}"

  _YSU_MULTI_ASYNC_FILE="$tmp_file"
  _YSU_MULTI_ASYNC_KEY="$cache_key"

  (
    local response auth_args=""
    [[ -n "$YSU_LLM_API_KEY" ]] && auth_args="-H \"Authorization: Bearer $YSU_LLM_API_KEY\""

    response=$(curl -s --max-time 15 \
      -H "Content-Type: application/json" \
      ${auth_args:+"$auth_args"} \
      -d "$payload" \
      "$YSU_LLM_API_URL" 2>/dev/null) || true

    local content=""
    [[ -n "$response" ]] && content=$(_ysu_json_extract_content "$response")

    content="${content#"${content%%[! ]*}"}"
    content="${content%"${content##*[! ]}"}"
    local lower_content
    lower_content=$(echo "$content" | tr '[:upper:]' '[:lower:]')

    if [[ -n "$content" && "$lower_content" != "none" && "$lower_content" != "none." ]]; then
      echo "$content" > "$tmp_file"
    else
      : > "$tmp_file"
    fi
    touch "${tmp_file}.done"
  ) &
  disown 2>/dev/null
}

_ysu_multi_check_async() {
  [[ -z "$_YSU_MULTI_ASYNC_FILE" ]] && return
  [[ ! -f "${_YSU_MULTI_ASYNC_FILE}.done" ]] && return

  local result=""
  [[ -s "$_YSU_MULTI_ASYNC_FILE" ]] && result=$(< "$_YSU_MULTI_ASYNC_FILE")

  local cache_file="${YSU_LLM_CACHE_DIR}/multi_${_YSU_MULTI_ASYNC_KEY}"
  if [[ -n "$result" ]]; then
    echo "$result" > "$cache_file"
    echo -e "$(_ysu_format "$YSU_LLM_PREFIX" "$result")"
  else
    : > "$cache_file"
  fi

  rm -f "$_YSU_MULTI_ASYNC_FILE" "${_YSU_MULTI_ASYNC_FILE}.done" 2>/dev/null
  _YSU_MULTI_ASYNC_FILE=""
  _YSU_MULTI_ASYNC_KEY=""
}

# ============================================================================
# Feature 5: LLM configuration promo
# ============================================================================

_ysu_maybe_show_promo() {
  [[ "$YSU_LLM_ENABLED" != "false" ]] && return

  local cache_dir="${YSU_LLM_CACHE_DIR:-$HOME/.cache/ysu}"
  mkdir -p "$cache_dir"
  local promo_file="$cache_dir/.promo_count"
  local today
  today=$(date +%Y-%m-%d)

  if [[ "$_YSU_PROMO_DATE" != "$today" ]]; then
    _YSU_PROMO_DATE="$today"
    _YSU_PROMO_SHOWN_TODAY=0
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

  (( _YSU_PROMO_SHOWN_TODAY++ ))
  printf '%s\n%s\n' "$today" "$_YSU_PROMO_SHOWN_TODAY" > "$promo_file"
  echo -e "$(_ysu_format "" "Enable AI-powered suggestions! Run ${_YSU_C_HINT}ysu config${_YSU_C_RESET} to set up.")"
}

# ============================================================================
# Hooks: DEBUG trap (preexec) + PROMPT_COMMAND (precmd)
# ============================================================================

_ysu_preexec() {
  # Only fire once per user command (guard against subshells/pipelines)
  [[ "$_YSU_PREEXEC_READY" != "true" ]] && return
  _YSU_PREEXEC_READY=false

  local typed_command="$1"

  # Trim leading whitespace
  typed_command="${typed_command#"${typed_command%%[! ]*}"}"
  [[ -z "$typed_command" ]] && return

  # Skip our own internal commands
  [[ "$typed_command" == _ysu_* ]] && return

  # Save full command for LLM evaluation in precmd
  _YSU_LLM_PENDING_CMD="$typed_command"

  # Push to multi-command history buffer
  if [[ "$YSU_LLM_ENABLED" == "true" && ("$YSU_LLM_MODE" == "multi" || "$YSU_LLM_MODE" == "both") ]]; then
    _ysu_multi_push_cmd "$typed_command"
  fi

  # Strip sudo prefix for matching
  local check_command="$typed_command"
  local _ysu_has_sudo=false
  if [[ "$check_command" == sudo\ * || "$check_command" == "sudo" ]]; then
    check_command="${check_command#sudo}"
    check_command="${check_command# }"
    _ysu_has_sudo=true
  fi

  [[ -z "$check_command" ]] && return

  _ysu_should_show || return

  local _ysu_tip_time_before=$_YSU_LAST_TIP_TIME
  _ysu_check_aliases "$check_command"
  _ysu_check_modern "$check_command"

  # Priority 2: suggest sudo alias only when inner command had no suggestions
  if [[ ${#_YSU_MESSAGES[@]} -eq 0 ]] && "$_ysu_has_sudo"; then
    _ysu_check_sudo_alias "$check_command"
  fi

  _YSU_CMD_HAD_TIPS=false
  [[ $_YSU_LAST_TIP_TIME -ne $_ysu_tip_time_before ]] && _YSU_CMD_HAD_TIPS=true

  _ysu_flush
}

_ysu_precmd() {
  local last_exit=$?

  # Re-arm the preexec guard
  _YSU_PREEXEC_READY=true

  # Flush any remaining buffered messages
  if [[ ${#_YSU_MESSAGES[@]} -gt 0 ]]; then
    _ysu_flush
  fi

  # LLM: display completed async results
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
          [[ -s "$cache_file" ]] && cached=$(< "$cache_file")
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

  # Show LLM promo when no tips were shown
  if [[ "$_YSU_CMD_HAD_TIPS" == "false" ]]; then
    _ysu_maybe_show_promo
  fi
}

# Register hooks
# DEBUG trap for preexec (fires before each command)
trap '_ysu_preexec "$BASH_COMMAND"' DEBUG
# PROMPT_COMMAND for precmd (fires before prompt is displayed)
if [[ -n "$PROMPT_COMMAND" ]]; then
  PROMPT_COMMAND="_ysu_precmd;$PROMPT_COMMAND"
else
  PROMPT_COMMAND="_ysu_precmd"
fi

# ============================================================================
# Interactive configuration: ysu command
# ============================================================================

_ysu_install_method() {
  local plugin_dir
  plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "$plugin_dir" == *"/Cellar/"* ]] || [[ "$plugin_dir" == *"/homebrew/"* ]]; then
    echo "homebrew"
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
    discover) shift; _ysu_discover "$@" ;;
    update)
      local method
      method=$(_ysu_install_method)
      case "$method" in
        homebrew)
          echo "Installed via Homebrew. Run:"
          echo "  brew upgrade you-should-use"
          ;;
        git)
          local plugin_dir
          plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
          echo "Updating you-should-use..."
          git -C "$plugin_dir" pull --ff-only && echo "Updated. Restart your shell: exec \$SHELL"
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
        git)
          local plugin_dir
          plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
          echo "Uninstalling you-should-use..."
          local rc_file="$HOME/.bashrc"
          if [[ -f "$rc_file" ]]; then
            local tmp_file
            tmp_file=$(mktemp)
            grep -vF "you-should-use" "$rc_file" > "$tmp_file" && mv "$tmp_file" "$rc_file"
            echo "Cleaned $rc_file"
          fi
          rm -rf "$plugin_dir"
          echo "Removed $plugin_dir"
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
  local green="$_YSU_C_OK" red="$_YSU_C_ERR" bold="$_YSU_C_BOLD" reset="$_YSU_C_RESET"
  local check="${green}✓${reset}" cross="${red}✗${reset}"

  echo ""
  echo -e "${bold}📊 you-should-use status${reset}"
  echo "─────────────────────────"

  echo -e "${bold}Core Settings:${reset}"
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

  echo ""
  echo -e "${bold}LLM Settings:${reset}"
  local llm_status
  if [[ "$YSU_LLM_ENABLED" == "true" ]]; then
    llm_status="${check} enabled"
    if [[ -n "$_YSU_OLLAMA_CHECKED" ]]; then
      local _ysu_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.bash"
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

  local cache_count=0
  if [[ -d "$YSU_LLM_CACHE_DIR" ]]; then
    cache_count=$(find "$YSU_LLM_CACHE_DIR" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo -e "  Mode:               ${YSU_LLM_MODE}"
  if [[ "$YSU_LLM_MODE" != "single" ]]; then
    echo -e "  Window Size:        ${YSU_LLM_WINDOW_SIZE} commands"
    echo -e "  History Buffer:     ${#_YSU_CMD_HISTORY[@]} commands"
  fi
  echo -e "  Cache:              ${cache_count} entries"

  echo ""
  echo -e "${bold}Statistics:${reset}"

  local alias_count
  alias_count=$(alias 2>/dev/null | wc -l | tr -d ' ')
  echo -e "  Aliases defined:    ${alias_count}"

  local modern_count=${#YSU_MODERN_KEYS[@]}
  echo -e "  Modern mappings:    ${modern_count}"

  if [[ "$YSU_LLM_ENABLED" == "false" ]]; then
    echo -e "  Promo shown today:  ${_YSU_PROMO_SHOWN_TODAY}/3"
  fi

  echo ""
  echo -e "${bold}Config File:${reset}"
  local cfg_file="${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.bash"
  if [[ -f "$cfg_file" ]]; then
    echo -e "  ${check} ${cfg_file}"
  else
    echo -e "  (using defaults — run ${_YSU_C_HINT}ysu config${_YSU_C_RESET} to customize)"
  fi
  echo ""
}

_ysu_discover() {
  local min_count=${1:-5}
  local min_words=2
  local bold="$_YSU_C_BOLD" reset="$_YSU_C_RESET" cyan="$_YSU_C_COMMAND" yellow="$_YSU_C_HINT" green="$_YSU_C_OK"

  echo ""
  echo -e "${bold}🔍 Alias Discovery${reset}"
  echo "─────────────────────────"
  echo -e "Analyzing history for commands used >= ${min_count} times..."
  echo ""

  # Get history file
  local histfile="${HISTFILE:-$HOME/.bash_history}"
  if [[ ! -f "$histfile" ]]; then
    echo "No history file found at ${histfile}"
    return 1
  fi

  # Get existing aliases for filtering
  local existing_aliases
  existing_aliases=$(alias 2>/dev/null | sed "s/^alias //" | cut -d= -f2 | tr -d "'")

  # Count command prefixes (2 and 3 word)
  # Using sort | uniq -c | sort -rn for efficiency (portable)
  local results
  results=$(
    while IFS= read -r line; do
      # Skip empty lines
      [[ -z "$line" ]] && continue
      # Split into words
      read -ra words <<< "$line"
      local wc=${#words[@]}
      (( wc < min_words )) && continue
      # 2-word prefix
      local p2="${words[0]} ${words[1]}"
      [[ "$p2" == _ysu_* || "$p2" == "cd "* || "$p2" == "echo "* ]] && continue
      echo "$p2"
      # 3-word prefix
      if (( wc >= 3 )); then
        echo "${words[0]} ${words[1]} ${words[2]}"
      fi
    done < "$histfile" | sort | uniq -c | sort -rn
  )

  # Display suggestions
  local found=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Parse "  count prefix"
    local count prefix
    count=$(echo "$line" | awk '{print $1}')
    prefix=$(echo "$line" | awk '{$1=""; print}' | sed 's/^ //')
    (( count < min_count )) && continue

    # Skip if already aliased
    echo "$existing_aliases" | grep -qF "$prefix" && continue

    local suggestion
    suggestion=$(_ysu_suggest_alias_name "$prefix")
    echo -e "  ${cyan}${prefix}${reset}  (used ${yellow}${count}${reset} times)"
    echo -e "    ${green}alias ${suggestion}='${prefix}'${reset}"
    echo ""
    ((found++))
    (( found >= 30 )) && break
  done <<< "$results"

  if (( found == 0 )); then
    echo "No alias suggestions found. Try lowering the threshold: ysu discover 3"
  fi
  echo ""
}

_ysu_suggest_alias_name() {
  local cmd="$1"
  local name=""
  local word
  read -ra words <<< "$cmd"
  for word in "${words[@]}"; do
    # Skip flags
    [[ "$word" == -* ]] && continue
    name+="${word:0:1}"
  done
  if [[ ${#name} -lt 2 ]]; then
    name=""
    for word in "${words[@]}"; do
      name+="${word:0:1}"
    done
  fi
  echo "${name}" | tr '[:upper:]' '[:lower:]'
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
  echo -e "  ${check} Bash ${BASH_VERSION}"
  local major="${BASH_VERSINFO[0]}"
  if (( major >= 3 )); then
    echo -e "  ${check} Bash version >= 3.2 (required)"
  else
    echo -e "  ${cross} Bash version < 3.2 — plugin may not work"
    ((issues++))
  fi

  # 2. Plugin load
  echo ""
  echo -e "${bold}Plugin:${reset}"
  if [[ "$_YSU_LOADED" == "1" ]]; then
    echo -e "  ${check} Plugin loaded"
  else
    echo -e "  ${cross} Plugin not loaded"
    ((issues++))
  fi

  # Check DEBUG trap
  local current_trap
  current_trap=$(trap -p DEBUG 2>/dev/null)
  if [[ "$current_trap" == *"_ysu_preexec"* ]]; then
    echo -e "  ${check} DEBUG trap registered"
  else
    echo -e "  ${cross} DEBUG trap NOT registered — alias reminders won't work"
    ((issues++))
  fi

  # Check PROMPT_COMMAND
  if [[ "$PROMPT_COMMAND" == *"_ysu_precmd"* ]]; then
    echo -e "  ${check} PROMPT_COMMAND registered"
  else
    echo -e "  ${cross} PROMPT_COMMAND NOT registered — LLM results won't display"
    ((issues++))
  fi

  # Plugin load time
  local t0 t1 ms
  t0=$(date +%s%N 2>/dev/null || echo 0)
  bash -c "source '${BASH_SOURCE[0]:-}'" 2>/dev/null
  t1=$(date +%s%N 2>/dev/null || echo 0)
  if [[ "$t0" != "0" && "$t1" != "0" ]]; then
    ms=$(( (t1 - t0) / 1000000 ))
    echo -e "  Plugin load time:   ${ms}ms"
    if (( ms > 500 )); then
      echo -e "  ${warn} Load time > 500ms — consider disabling Ollama auto-detect if slow"
      ((issues++))
    fi
  fi

  # 3. Config conflicts
  echo ""
  echo -e "${bold}Config:${reset}"
  local cfg_file="${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.bash"
  if [[ -f "$cfg_file" ]]; then
    echo -e "  ${check} Config file: ${cfg_file}"
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

    if [[ "$YSU_LLM_API_URL" == *"localhost:11434"* || "$YSU_LLM_API_URL" == *"127.0.0.1:11434"* ]]; then
      local ollama_resp
      ollama_resp=$(curl -s --max-time 3 "http://localhost:11434/api/tags" 2>/dev/null)
      if [[ -n "$ollama_resp" ]]; then
        echo -e "  ${check} Ollama reachable"
        local model
        model=$(_ysu_get_effective_model)
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
  local dep
  for dep in curl jq; do
    if command -v "$dep" &>/dev/null; then
      echo -e "  ${check} ${dep}"
    else
      if [[ "$dep" == "jq" ]]; then
        echo -e "  ${warn} ${dep} (optional — used for Ollama model detection)"
      else
        echo -e "  ${cross} ${dep} (required for LLM)"
        ((issues++))
      fi
    fi
  done
  # md5/md5sum
  if command -v md5sum &>/dev/null || command -v md5 &>/dev/null; then
    echo -e "  ${check} md5/md5sum"
  else
    echo -e "  ${warn} md5/md5sum (needed for LLM cache)"
    ((issues++))
  fi

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
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ysu"
  local config_file="$config_dir/config.bash"
  local choice

  while true; do
    echo ""
    echo -e "${_YSU_C_BOLD}You Should Use — Configuration${_YSU_C_RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  1) Alias Reminders:       $([[ "$YSU_REMINDER_ENABLED" == "true" ]] && echo "${_YSU_C_OK}✓ enabled${_YSU_C_RESET}" || echo "${_YSU_C_ERR}✗ disabled${_YSU_C_RESET}")"
    echo -e "  2) Modern Suggestions:    $([[ "$YSU_SUGGEST_ENABLED" == "true" ]] && echo "${_YSU_C_OK}✓ enabled${_YSU_C_RESET}" || echo "${_YSU_C_ERR}✗ disabled${_YSU_C_RESET}")"
    echo -e "  3) LLM Suggestions:       $([[ "$YSU_LLM_ENABLED" == "true" ]] && echo "${_YSU_C_OK}✓ enabled${_YSU_C_RESET}" || echo "${_YSU_C_ERR}✗ disabled${_YSU_C_RESET}")"
    echo "  4) Tip Probability:       ${YSU_PROBABILITY}%"
    echo "  5) Cooldown:              ${YSU_COOLDOWN}s"
    echo "  6) LLM Settings           →"
    echo "  7) Theme Settings         →"
    echo ""
    echo -ne "  \e[7m 1-7 \e[0m select  \e[7m q \e[0m quit: "
    read -r choice

    case "$choice" in
      1) [[ "$YSU_REMINDER_ENABLED" == "true" ]] && YSU_REMINDER_ENABLED=false || YSU_REMINDER_ENABLED=true ;;
      2) [[ "$YSU_SUGGEST_ENABLED" == "true" ]] && YSU_SUGGEST_ENABLED=false || YSU_SUGGEST_ENABLED=true ;;
      3) [[ "$YSU_LLM_ENABLED" == "true" ]] && YSU_LLM_ENABLED=false || YSU_LLM_ENABLED=true ;;
      4) read -rp "  Probability (1-100): " YSU_PROBABILITY ;;
      5) read -rp "  Cooldown (seconds): " YSU_COOLDOWN ;;
      6) _ysu_config_llm ;;
      7) _ysu_config_theme || { _ysu_config_save "$config_dir" "$config_file"; return; } ;;
      q|Q) _ysu_config_save "$config_dir" "$config_file"; return ;;
      *) continue ;;
    esac
    _ysu_config_save "$config_dir" "$config_file"
  done
}

_ysu_config_theme() {
  local _dark_themes=("tokyo-night" "dracula" "monokai" "catppuccin-mocha")
  local _light_themes=("solarized" "catppuccin-latte" "github")
  local _key _cur_theme _i _redraw=0
  while true; do
    [[ "$YSU_THEME" == "light" ]] && _cur_theme="$YSU_LIGHT_THEME" || _cur_theme="$YSU_DARK_THEME"
    if (( _redraw )); then
      printf '\r\e[10A\e[J'
    fi
    _redraw=1
    echo ""
    echo -e "${_YSU_C_BOLD}Theme Settings${_YSU_C_RESET}"
    echo "━━━━━━━━━━━━━━"
    echo -e "  Mode:   ${_YSU_C_BOLD}${YSU_THEME}${_YSU_C_RESET}"
    echo -e "  Theme:  ${_YSU_C_BOLD}${_cur_theme}${_YSU_C_RESET}"
    echo ""
    echo "  Preview:"
    echo -e "  ${_YSU_C_DIM}💡 Found alias:${_YSU_C_RESET} ${_YSU_C_COMMAND}git commit${_YSU_C_RESET} ${_YSU_C_ARROW}→${_YSU_C_RESET} ${_YSU_C_HIGHLIGHT}gc${_YSU_C_RESET}"
    echo -e "  ${_YSU_C_DIM}💡 Modern:${_YSU_C_RESET} ${_YSU_C_COMMAND}cat${_YSU_C_RESET} ${_YSU_C_ARROW}→${_YSU_C_RESET} ${_YSU_C_HIGHLIGHT}bat${_YSU_C_RESET} ${_YSU_C_HINT}(Syntax-highlighted cat)${_YSU_C_RESET}"
    echo ""
    echo -ne "  \e[7m ↑↓/jk \e[0m mode  \e[7m ←→/hl \e[0m theme  \e[7m b \e[0m back  \e[7m q \e[0m quit"
    IFS= read -rsn1 _key
    if [[ "$_key" == $'\e' ]]; then
      read -rsn2 _key
    fi
    case "$_key" in
      '[A'|k|K|'[B'|j|J)
        [[ "$YSU_THEME" == "dark" ]] && YSU_THEME=light || YSU_THEME=dark
        _ysu_init_colors
        ;;
      '[C'|l|L)
        if [[ "$YSU_THEME" == "dark" ]]; then
          for _i in "${!_dark_themes[@]}"; do
            [[ "${_dark_themes[$_i]}" == "$YSU_DARK_THEME" ]] && break
          done
          _i=$(( (_i + 1) % ${#_dark_themes[@]} ))
          YSU_DARK_THEME="${_dark_themes[$_i]}"
        else
          for _i in "${!_light_themes[@]}"; do
            [[ "${_light_themes[$_i]}" == "$YSU_LIGHT_THEME" ]] && break
          done
          _i=$(( (_i + 1) % ${#_light_themes[@]} ))
          YSU_LIGHT_THEME="${_light_themes[$_i]}"
        fi
        _ysu_init_colors
        ;;
      '[D'|h|H)
        if [[ "$YSU_THEME" == "dark" ]]; then
          for _i in "${!_dark_themes[@]}"; do
            [[ "${_dark_themes[$_i]}" == "$YSU_DARK_THEME" ]] && break
          done
          _i=$(( (_i - 1 + ${#_dark_themes[@]}) % ${#_dark_themes[@]} ))
          YSU_DARK_THEME="${_dark_themes[$_i]}"
        else
          for _i in "${!_light_themes[@]}"; do
            [[ "${_light_themes[$_i]}" == "$YSU_LIGHT_THEME" ]] && break
          done
          _i=$(( (_i - 1 + ${#_light_themes[@]}) % ${#_light_themes[@]} ))
          YSU_LIGHT_THEME="${_light_themes[$_i]}"
        fi
        _ysu_init_colors
        ;;
      b|B) echo ""; return 0 ;;
      q|Q) echo ""; return 1 ;;
    esac
  done
}

_ysu_config_llm() {
  local choice
  while true; do
    echo ""
    echo -e "${_YSU_C_BOLD}LLM Settings${_YSU_C_RESET}"
    echo "━━━━━━━━━━━━"
    echo "  a) API URL:   $YSU_LLM_API_URL"
    echo -e "  b) API Key:   $([[ -n "$YSU_LLM_API_KEY" ]] && echo "••••${YSU_LLM_API_KEY: -4}" || echo '(not set)')"
    echo "  c) Model:     $YSU_LLM_MODEL"
    echo ""
    echo -ne "  \e[7m a-c \e[0m select  \e[7m q \e[0m back: "
    read -r choice

    case "$choice" in
      a) read -erp "  API URL: " -i "$YSU_LLM_API_URL" YSU_LLM_API_URL ;;
      b) read -erp "  API Key: " -i "$YSU_LLM_API_KEY" YSU_LLM_API_KEY ;;
      c) read -erp "  Model: " -i "$YSU_LLM_MODEL" YSU_LLM_MODEL ;;
      q|Q) return ;;
    esac
  done
}

_ysu_config_save() {
  local config_dir="$1" config_file="$2"
  mkdir -p "$config_dir"
  cat > "$config_file" <<EOF
# You Should Use — Configuration (generated by ysu config)
YSU_REMINDER_ENABLED=$YSU_REMINDER_ENABLED
YSU_SUGGEST_ENABLED=$YSU_SUGGEST_ENABLED
YSU_LLM_ENABLED=$YSU_LLM_ENABLED
YSU_PROBABILITY=$YSU_PROBABILITY
YSU_COOLDOWN=$YSU_COOLDOWN
YSU_LLM_API_URL="$YSU_LLM_API_URL"
YSU_LLM_API_KEY="$YSU_LLM_API_KEY"
YSU_LLM_MODEL="$YSU_LLM_MODEL"
YSU_LLM_MODE="$YSU_LLM_MODE"
YSU_INSTALL_HINT=$YSU_INSTALL_HINT
YSU_MESSAGE_FORMAT="$YSU_MESSAGE_FORMAT"
YSU_THEME="$YSU_THEME"
YSU_DARK_THEME="$YSU_DARK_THEME"
YSU_LIGHT_THEME="$YSU_LIGHT_THEME"
EOF
}
