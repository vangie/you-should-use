#!/usr/bin/env bats
# Tests for LLM-powered suggestions (Feature 4)

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# ============================================================================
# JSON escape
# ============================================================================

@test "llm: json escape handles double quotes" {
  run_zsh '
    result=$(_ysu_json_escape "echo \"hello\"")
    echo "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *'\"'* ]]
}

@test "llm: json escape handles backslashes" {
  run_zsh '
    result=$(_ysu_json_escape "path\\to\\file")
    [[ "$result" == *"\\\\"* ]] && echo "escaped" || echo "not_escaped"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"escaped"* ]]
}

# ============================================================================
# Cache key
# ============================================================================

@test "llm: cache key is deterministic" {
  run_zsh '
    key1=$(_ysu_llm_cache_key "find . -name foo")
    key2=$(_ysu_llm_cache_key "find . -name foo")
    [[ "$key1" == "$key2" ]] && echo "match" || echo "mismatch"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"match"* ]]
}

@test "llm: cache key differs for different commands" {
  run_zsh '
    key1=$(_ysu_llm_cache_key "find . -name foo")
    key2=$(_ysu_llm_cache_key "grep -r bar .")
    [[ "$key1" != "$key2" ]] && echo "different" || echo "same"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"different"* ]]
}

# ============================================================================
# Trigger conditions
# ============================================================================

@test "llm: triggers on non-zero exit code" {
  run_zsh '
    _ysu_llm_should_trigger "ls /nonexistent" 1 && echo "triggered" || echo "skipped"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"triggered"* ]]
}

@test "llm: triggers on pipe commands" {
  run_zsh '
    _ysu_llm_should_trigger "cat file | grep foo" 0 && echo "triggered" || echo "skipped"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"triggered"* ]]
}

@test "llm: triggers on redirect commands" {
  run_zsh '
    _ysu_llm_should_trigger "echo hello > file.txt" 0 && echo "triggered" || echo "skipped"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"triggered"* ]]
}

@test "llm: triggers on complex args (>=4 words)" {
  run_zsh '
    _ysu_llm_should_trigger "find . -name foo -type f" 0 && echo "triggered" || echo "skipped"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"triggered"* ]]
}

@test "llm: does not trigger on simple successful command" {
  run_zsh '
    _ysu_llm_should_trigger "ls -la" 0 && echo "triggered" || echo "skipped"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
}

@test "llm: does not trigger on simple command with exit 0" {
  run_zsh '
    _ysu_llm_should_trigger "git status" 0 && echo "triggered" || echo "skipped"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
}

# ============================================================================
# LLM disabled by default
# ============================================================================

@test "llm: disabled by default" {
  run_zsh '
    echo "enabled=$YSU_LLM_ENABLED"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"enabled=false"* ]]
}

@test "llm: preexec saves command for llm when enabled" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_MODERN_COMMANDS=()
    _ysu_preexec "find . -name test"
    echo "pending=$_YSU_LLM_PENDING_CMD"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending=find . -name test"* ]]
}

# ============================================================================
# Cache read/write
# ============================================================================

@test "llm: cache hit shows suggestion immediately" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_CACHE_DIR="/tmp/ysu-test-cache-$$"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    local key=$(_ysu_llm_cache_key "find . -name foo -type f")
    echo "Use fd instead of find for faster searches" > "$YSU_LLM_CACHE_DIR/$key"
    _YSU_LLM_PENDING_CMD="find . -name foo -type f"
    _ysu_precmd
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"fd"* ]]
  [[ "$output" == *"faster"* ]]
}

@test "llm: empty cache file means no suggestion (negative cache)" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_CACHE_DIR="/tmp/ysu-test-cache-$$"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    local key=$(_ysu_llm_cache_key "echo hello")
    : > "$YSU_LLM_CACHE_DIR/$key"
    _YSU_LLM_PENDING_CMD="echo hello"
    _ysu_precmd
    echo "no_output"
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  # Should not contain any tip arrow
  [[ "$output" != *"➜"* ]]
}

# ============================================================================
# Async result display
# ============================================================================

@test "llm: async result displayed when done marker exists" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_CACHE_DIR="/tmp/ysu-test-cache-$$"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    local tmp="/tmp/ysu-test-async-$$"
    echo "Try using ripgrep (rg) for faster recursive search" > "$tmp"
    touch "${tmp}.done"
    _YSU_LLM_ASYNC_FILE="$tmp"
    _YSU_LLM_ASYNC_CMD="grep -r pattern ."
    _ysu_llm_check_async
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"ripgrep"* ]]
}

@test "llm: async result not displayed when done marker missing" {
  run_zsh '
    YSU_LLM_ENABLED=true
    local tmp="/tmp/ysu-test-async-$$"
    echo "some suggestion" > "$tmp"
    _YSU_LLM_ASYNC_FILE="$tmp"
    _YSU_LLM_ASYNC_CMD="some command"
    _ysu_llm_check_async
    echo "no_output"
    rm -f "$tmp"
  '
  [ "$status" -eq 0 ]
  [[ "$output" != *"➜"* ]]
}

# ============================================================================
# JSON extract (integration-style, needs jq or python3)
# ============================================================================

@test "llm: json extract content from openai response" {
  if ! command -v jq &>/dev/null && ! command -v python3 &>/dev/null; then
    skip "neither jq nor python3 installed"
  fi
  run_zsh '
    json="{\"choices\":[{\"message\":{\"content\":\"Use fd instead of find\"}}]}"
    result=$(_ysu_json_extract_content "$json")
    echo "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Use fd instead of find"* ]]
}
