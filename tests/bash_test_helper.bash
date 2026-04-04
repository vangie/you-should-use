#!/usr/bin/env bash
# Test helper: sources the Bash plugin in an isolated environment
# Usage: source this file, then call test functions

# Prevent hooks from registering during tests
_YSU_TESTING=1

# Stub trap and PROMPT_COMMAND to prevent hook registration
_original_trap=$(trap -p DEBUG 2>/dev/null)
trap '' DEBUG  # Temporarily disable

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the plugin (will try to register hooks, but we stub them)
# We need to temporarily override trap and PROMPT_COMMAND
_saved_prompt_command="$PROMPT_COMMAND"
source "$PLUGIN_DIR/you-should-use.plugin.bash"
# Restore — we don't want hooks firing during tests
trap '' DEBUG
PROMPT_COMMAND="$_saved_prompt_command"

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
  YSU_IGNORE_SUGGESTIONS=""
  YSU_LLM_ENABLED=false
  YSU_LLM_API_URL="http://localhost:11434/v1/chat/completions"
  YSU_LLM_API_KEY=""
  YSU_LLM_MODEL="test-model"
  _YSU_LLM_RESOLVED_MODEL=""
  YSU_LLM_CACHE_DIR="/tmp/ysu-test-cache-$$"
  _YSU_LLM_PENDING_CMD=""
  _YSU_LLM_ASYNC_FILE=""
  _YSU_LLM_ASYNC_CMD=""
  _YSU_PROMO_SHOWN_TODAY=0
  _YSU_PROMO_DATE=""
  _YSU_CMD_HAD_TIPS=false
  YSU_INSTALL_HINT=true
  YSU_MESSAGE_FORMAT="{prefix} {arrow} {message}"
  YSU_LLM_MODE="single"
  YSU_LLM_WINDOW_SIZE=5
  _YSU_CMD_HISTORY=()
  _YSU_MULTI_ASYNC_FILE=""
  _YSU_MULTI_ASYNC_KEY=""
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
