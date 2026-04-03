#!/usr/bin/env bats
# Tests for Bash: Multi-command LLM mode

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_bash() {
  run bash -c "
    source '$PLUGIN_DIR/tests/bash_test_helper.bash'
    _ysu_reset
    $1
  "
}

@test "bash: default LLM mode is single" {
  run_bash 'echo "$YSU_LLM_MODE"'
  [ "$status" -eq 0 ]
  [[ "$output" == "single" ]]
}

@test "bash: default window size is 5" {
  run_bash 'echo "$YSU_LLM_WINDOW_SIZE"'
  [ "$status" -eq 0 ]
  [[ "$output" == "5" ]]
}

@test "bash: push_cmd adds to history" {
  run_bash '
    _ysu_multi_push_cmd "ls -la"
    _ysu_multi_push_cmd "cd /tmp"
    echo "${#_YSU_CMD_HISTORY[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "2" ]]
}

@test "bash: push_cmd trims to window size" {
  run_bash '
    YSU_LLM_WINDOW_SIZE=3
    _ysu_multi_push_cmd "cmd1"
    _ysu_multi_push_cmd "cmd2"
    _ysu_multi_push_cmd "cmd3"
    _ysu_multi_push_cmd "cmd4"
    echo "count=${#_YSU_CMD_HISTORY[@]}"
    echo "first=${_YSU_CMD_HISTORY[0]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=3"* ]]
  [[ "$output" == *"first=cmd2"* ]]
}

@test "bash: multi_should_trigger requires 3+ commands" {
  run_bash '
    _ysu_multi_push_cmd "cmd1"
    _ysu_multi_push_cmd "cmd2"
    if _ysu_multi_should_trigger; then
      echo "triggered"
    else
      echo "not triggered"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"not triggered"* ]]
}

@test "bash: multi_should_trigger fires with 3 commands" {
  run_bash '
    _ysu_multi_push_cmd "cmd1"
    _ysu_multi_push_cmd "cmd2"
    _ysu_multi_push_cmd "cmd3"
    if _ysu_multi_should_trigger; then
      echo "triggered"
    else
      echo "not triggered"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"triggered"* ]]
}

@test "bash: cache key generation works" {
  run_bash '
    key=$(_ysu_llm_cache_key "test command")
    echo "key=$key"
    [ -n "$key" ]
  '
  [ "$status" -eq 0 ]
  [[ "$output" == key=* ]]
}

# ============================================================================
# Env var prefix stripping
# ============================================================================

@test "bash: strip_env_prefix removes single VAR=value" {
  run_bash '
    result=$(_ysu_strip_env_prefix "TASKS=0104 make run")
    echo "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "make run" ]]
}

@test "bash: strip_env_prefix removes multiple VAR=value" {
  run_bash '
    result=$(_ysu_strip_env_prefix "CC=gcc CFLAGS=-O2 make build")
    echo "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "make build" ]]
}

@test "bash: strip_env_prefix leaves plain commands unchanged" {
  run_bash '
    result=$(_ysu_strip_env_prefix "git status")
    echo "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "git status" ]]
}

@test "bash: llm_should_trigger on non-zero exit" {
  run_bash '
    if _ysu_llm_should_trigger "git push" "1"; then
      echo "triggered"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"triggered"* ]]
}

@test "bash: llm_should_trigger on pipes" {
  run_bash '
    if _ysu_llm_should_trigger "cat file | grep foo" "0"; then
      echo "triggered"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"triggered"* ]]
}

@test "bash: llm_should_trigger on complex args" {
  run_bash '
    if _ysu_llm_should_trigger "find . -name foo -type f" "0"; then
      echo "triggered"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"triggered"* ]]
}

@test "bash: llm_should_trigger skips simple commands" {
  run_bash '
    if _ysu_llm_should_trigger "ls -la" "0"; then
      echo "triggered"
    else
      echo "skipped"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
}
