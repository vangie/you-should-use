#!/usr/bin/env zsh
# Test helper: sources the plugin in an isolated zsh environment
# Usage: source this file, then call test functions

# Stub add-zsh-hook and autoload so the plugin loads without errors
add-zsh-hook() { : }
autoload() { : }

# Provide EPOCHSECONDS if not available
[[ -z "$EPOCHSECONDS" ]] && EPOCHSECONDS=$(date +%s)

# Source the plugin
PLUGIN_DIR="${0:A:h}/.."
source "$PLUGIN_DIR/you-should-use.plugin.zsh"

# Reset state for clean tests
_ysu_reset() {
  _YSU_MESSAGES=()
  _YSU_LAST_TIP_TIME=0
  YSU_REMINDER_ENABLED=true
  YSU_SUGGEST_ENABLED=true
  YSU_PREFIX="💡"
  YSU_REMINDER_PREFIX=""
  YSU_SUGGEST_PREFIX=""
  YSU_PROBABILITY=100
  YSU_COOLDOWN=0
  YSU_IGNORE_ALIASES=""
  YSU_IGNORE_COMMANDS=""
  YSU_LLM_ENABLED=false
  YSU_LLM_API_URL="http://localhost:11434/v1/chat/completions"
  YSU_LLM_API_KEY=""
  YSU_LLM_MODEL="test-model"
  YSU_LLM_CACHE_DIR="/tmp/ysu-test-cache-$$"
  _YSU_LLM_PENDING_CMD=""
  _YSU_LLM_ASYNC_FILE=""
  _YSU_LLM_ASYNC_CMD=""
}

# Get buffered messages as plain text (strip ANSI codes)
_ysu_get_messages() {
  local msg
  for msg in "${_YSU_MESSAGES[@]}"; do
    echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g'
  done
}

# Get message count
_ysu_message_count() {
  echo ${#_YSU_MESSAGES[@]}
}
