#!/usr/bin/env zsh
# you-should-use - Alias reminders & modern command suggestions
# https://github.com/vangie/you-should-use
# MIT License

# Source user config if it exists (before defaults so user values take priority)
local _ysu_config="${XDG_CONFIG_HOME:-$HOME/.config}/ysu/config.zsh"
[[ -f "$_ysu_config" ]] && source "$_ysu_config"

# ============================================================================
# Configuration (override these in your .zshrc BEFORE sourcing the plugin)
# ============================================================================

# Feature toggles
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

# LLM settings (OpenAI-compatible API — works with Ollama, OpenAI, etc.)
: ${YSU_LLM_API_URL:="http://localhost:11434/v1/chat/completions"}
: ${YSU_LLM_API_KEY:=""}
: ${YSU_LLM_MODEL:="auto"}
: ${YSU_LLM_CACHE_DIR:="$HOME/.cache/ysu"}

# ============================================================================
# Ollama auto-detection (runs once at plugin load, not every command)
# ============================================================================

typeset -g _YSU_LLM_RESOLVED_MODEL=""

if [[ -z "$_YSU_OLLAMA_CHECKED" ]]; then
  typeset -g _YSU_OLLAMA_CHECKED=1
  # Only auto-detect if user hasn't explicitly configured LLM
  if [[ "$YSU_LLM_ENABLED" == "false" && -z "${YSU_LLM_ENABLED+set_by_user}" ]]; then
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
typeset -g _YSU_LLM_PENDING_CMD=""
typeset -g _YSU_LLM_ASYNC_FILE=""
typeset -g _YSU_LLM_ASYNC_CMD=""
typeset -g _YSU_PROMO_SHOWN_TODAY=0
typeset -g _YSU_PROMO_DATE=""

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
      "You should use \e[1;31m${found_alias}\e[0m instead of \e[1;36m${found_expanded}\e[0m"
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
        "You should use \e[1;31m${modern_cmd}\e[0m instead of \e[1;36m${first_word}\e[0m — \e[3m${description}\e[0m"
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
        "You should use \e[1;31m${alias_name} ${inner_command}\e[0m instead of \e[1;36msudo ${inner_command}\e[0m"
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
  echo -e "$(_ysu_format "" "Enable AI-powered suggestions! Run \e[1;33mysu config\e[0m to set up.")"
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

  # Save full command for LLM evaluation in precmd
  _YSU_LLM_PENDING_CMD="$typed_command"

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

  # Flush any remaining buffered messages (fallback)
  if [[ ${#_YSU_MESSAGES} -gt 0 ]]; then
    _ysu_flush
  fi

  # LLM: display completed async result from previous command
  [[ "$YSU_LLM_ENABLED" == "true" ]] && _ysu_llm_check_async

  # LLM: evaluate triggers for the just-finished command
  if [[ "$YSU_LLM_ENABLED" == "true" && -n "$_YSU_LLM_PENDING_CMD" ]]; then
    if _ysu_llm_should_trigger "$_YSU_LLM_PENDING_CMD" "$last_exit"; then
      local cache_key
      cache_key=$(_ysu_llm_cache_key "$_YSU_LLM_PENDING_CMD")
      local cache_file="${YSU_LLM_CACHE_DIR}/${cache_key}"

      if [[ -f "$cache_file" ]]; then
        # Cache hit — show immediately (or skip if empty = no suggestion)
        local cached=""
        [[ -s "$cache_file" ]] && cached=$(<"$cache_file")
        [[ -n "$cached" ]] && echo -e "$(_ysu_format "$YSU_LLM_PREFIX" "$cached")"
      else
        # Cache miss — fire async request
        _ysu_llm_query_async "$_YSU_LLM_PENDING_CMD"
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
    *)
      echo "Usage: ysu <command>"
      echo "Commands:"
      echo "  config    Configure you-should-use interactively"
      echo "  cache     Manage LLM suggestion cache"
      echo "  status    Show current configuration and statistics"
      ;;
  esac
}

_ysu_status() {
  local green='\e[32m' red='\e[31m' yellow='\e[1;33m' cyan='\e[1;36m' bold='\e[1m' reset='\e[0m'
  local check="${green}✓${reset}" cross="${red}✗${reset}"

  echo ""
  echo -e "${bold}📊 you-should-use status${reset}"
  echo "─────────────────────────"

  # Core Settings
  echo -e "${bold}Core Settings:${reset}"
  echo -e "  Alias Reminders:    $([[ "$YSU_REMINDER_ENABLED" == "true" ]] && echo "${check} enabled" || echo "${cross} disabled")"
  echo -e "  Modern Suggestions: $([[ "$YSU_SUGGEST_ENABLED" == "true" ]] && echo "${check} enabled" || echo "${cross} disabled")"
  echo -e "  Prefix:             \"${YSU_PREFIX}\""
  echo -e "  Probability:        ${YSU_PROBABILITY}%"
  echo -e "  Cooldown:           ${YSU_COOLDOWN}s"
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
    echo -e "  ${cross} (none — using defaults)"
  fi
  echo ""
}

_ysu_config_wizard() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ysu"
  local config_file="$config_dir/config.zsh"
  local choice

  while true; do
    echo ""
    echo "\e[1mYou Should Use — Configuration\e[0m"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1) Alias Reminders:       $([[ "$YSU_REMINDER_ENABLED" == "true" ]] && echo '\e[32m✓ enabled\e[0m' || echo '\e[31m✗ disabled\e[0m')"
    echo "  2) Modern Suggestions:    $([[ "$YSU_SUGGEST_ENABLED" == "true" ]] && echo '\e[32m✓ enabled\e[0m' || echo '\e[31m✗ disabled\e[0m')"
    echo "  3) LLM Suggestions:       $([[ "$YSU_LLM_ENABLED" == "true" ]] && echo '\e[32m✓ enabled\e[0m' || echo '\e[31m✗ disabled\e[0m')"
    echo "  4) Tip Probability:       ${YSU_PROBABILITY}%"
    echo "  5) Cooldown:              ${YSU_COOLDOWN}s"
    echo "  6) LLM Settings           →"
    echo ""
    echo -n "  Select (1-6, s=save, q=quit): "
    read -r choice

    case "$choice" in
      1) [[ "$YSU_REMINDER_ENABLED" == "true" ]] && YSU_REMINDER_ENABLED=false || YSU_REMINDER_ENABLED=true ;;
      2) [[ "$YSU_SUGGEST_ENABLED" == "true" ]] && YSU_SUGGEST_ENABLED=false || YSU_SUGGEST_ENABLED=true ;;
      3) [[ "$YSU_LLM_ENABLED" == "true" ]] && YSU_LLM_ENABLED=false || YSU_LLM_ENABLED=true ;;
      4) echo -n "  Probability (1-100): "; read -r YSU_PROBABILITY ;;
      5) echo -n "  Cooldown (seconds): "; read -r YSU_COOLDOWN ;;
      6) _ysu_config_llm ;;
      s|S) _ysu_config_save "$config_dir" "$config_file" ;;
      q|Q) echo "  Settings applied to current session."; return ;;
    esac
  done
}

_ysu_config_llm() {
  local choice
  while true; do
    echo ""
    echo "\e[1mLLM Settings\e[0m"
    echo "━━━━━━━━━━━━"
    echo "  a) API URL:   $YSU_LLM_API_URL"
    echo "  b) API Key:   $([[ -n "$YSU_LLM_API_KEY" ]] && echo "••••${YSU_LLM_API_KEY: -4}" || echo '(not set)')"
    echo "  c) Model:     $YSU_LLM_MODEL"
    echo ""
    echo -n "  Select (a-c, q=back): "
    read -r choice

    case "$choice" in
      a) echo -n "  API URL: "; read -r YSU_LLM_API_URL ;;
      b) echo -n "  API Key: "; read -r YSU_LLM_API_KEY ;;
      c) echo -n "  Model: "; read -r YSU_LLM_MODEL ;;
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
EOF
  echo "  Saved to $config_file"
}
