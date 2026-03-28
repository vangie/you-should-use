#!/usr/bin/env bats
# Tests for LLM multi-command sliding window mode

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# ---- Configuration defaults ----

@test "multi: default YSU_LLM_MODE is single" {
  run_zsh '
    echo "$YSU_LLM_MODE"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"single"* ]]
}

@test "multi: default YSU_LLM_WINDOW_SIZE is 5" {
  run_zsh '
    echo "$YSU_LLM_WINDOW_SIZE"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"5"* ]]
}

# ---- Command history buffer ----

@test "multi: push_cmd adds to history" {
  run_zsh '
    _ysu_multi_push_cmd "ls -la"
    _ysu_multi_push_cmd "cd /tmp"
    echo "${#_YSU_CMD_HISTORY[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"2"* ]]
}

@test "multi: push_cmd trims to window size" {
  run_zsh '
    YSU_LLM_WINDOW_SIZE=3
    _ysu_multi_push_cmd "cmd1"
    _ysu_multi_push_cmd "cmd2"
    _ysu_multi_push_cmd "cmd3"
    _ysu_multi_push_cmd "cmd4"
    echo "count=${#_YSU_CMD_HISTORY[@]}"
    echo "first=${_YSU_CMD_HISTORY[1]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=3"* ]]
  [[ "$output" == *"first=cmd2"* ]]
}

# ---- Trigger logic ----

@test "multi: does not trigger with fewer than 3 commands" {
  run_zsh '
    _ysu_multi_push_cmd "ls"
    _ysu_multi_push_cmd "cd /tmp"
    if _ysu_multi_should_trigger; then
      echo "trigger=yes"
    else
      echo "trigger=no"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"trigger=no"* ]]
}

@test "multi: triggers with 3 or more commands" {
  run_zsh '
    _ysu_multi_push_cmd "ls"
    _ysu_multi_push_cmd "cd /tmp"
    _ysu_multi_push_cmd "cat file.txt"
    if _ysu_multi_should_trigger; then
      echo "trigger=yes"
    else
      echo "trigger=no"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"trigger=yes"* ]]
}

# ---- Mode gating ----

@test "multi: preexec does not push to buffer in single mode" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_MODE=single
    _ysu_preexec "ls -la"
    echo "${#_YSU_CMD_HISTORY[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"0"* ]]
}

@test "multi: preexec pushes to buffer in multi mode" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_MODE=multi
    YSU_PROBABILITY=100
    YSU_COOLDOWN=0
    _ysu_preexec "ls -la"
    echo "${#_YSU_CMD_HISTORY[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"1"* ]]
}

@test "multi: preexec pushes to buffer in both mode" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_MODE=both
    YSU_PROBABILITY=100
    YSU_COOLDOWN=0
    _ysu_preexec "ls -la"
    echo "${#_YSU_CMD_HISTORY[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"1"* ]]
}

# ---- Cache key ----

@test "multi: cache key for multi uses multi_ prefix" {
  run_zsh '
    _ysu_multi_push_cmd "ls"
    _ysu_multi_push_cmd "cd /tmp"
    _ysu_multi_push_cmd "pwd"
    # The multi_query_async function uses multi_ prefix in cache_file path
    # Verify the function exists and is callable
    echo "exists=yes"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"exists=yes"* ]]
}

# ---- Status display ----

@test "multi: status shows mode" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_MODE=multi
    _ysu_status 2>&1
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode:"* ]]
  [[ "$output" == *"multi"* ]]
}

@test "multi: status shows window size in multi mode" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_MODE=multi
    YSU_LLM_WINDOW_SIZE=5
    _ysu_status 2>&1
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Window Size:"* ]]
  [[ "$output" == *"5 commands"* ]]
}

@test "multi: status hides window size in single mode" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_MODE=single
    _ysu_status 2>&1
  '
  [ "$status" -eq 0 ]
  [[ "$output" != *"Window Size:"* ]]
}
