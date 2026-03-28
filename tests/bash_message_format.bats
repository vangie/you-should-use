#!/usr/bin/env bats
# Tests for Bash: Message Format Templates

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_bash() {
  run bash -c "
    source '$PLUGIN_DIR/tests/bash_test_helper.bash'
    _ysu_reset
    $1
  "
}

@test "bash: default format includes prefix, arrow, message" {
  run_bash '
    result=$(_ysu_format "" "test message")
    echo -e "$result" | sed "s/\x1b\[[0-9;]*m//g"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"💡"* ]]
  [[ "$output" == *"➜"* ]]
  [[ "$output" == *"test message"* ]]
}

@test "bash: custom format without arrow" {
  run_bash '
    YSU_MESSAGE_FORMAT="[{prefix}] {message}"
    result=$(_ysu_format "" "hello world")
    echo -e "$result" | sed "s/\x1b\[[0-9;]*m//g"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"[💡]"* ]]
  [[ "$output" == *"hello world"* ]]
  [[ "$output" != *"➜"* ]]
}

@test "bash: message-only format" {
  run_bash '
    YSU_MESSAGE_FORMAT="{message}"
    result=$(_ysu_format "" "just the message")
    echo -e "$result" | sed "s/\x1b\[[0-9;]*m//g"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"just the message"* ]]
  [[ "$output" != *"💡"* ]]
}

@test "bash: prefix includes extra prefix" {
  run_bash '
    result=$(_ysu_format "EXTRA" "msg")
    echo -e "$result" | sed "s/\x1b\[[0-9;]*m//g"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"💡EXTRA"* ]]
}

@test "bash: format applies to modern suggestions" {
  run_bash '
    YSU_MESSAGE_FORMAT=">> {message}"
    YSU_MODERN_KEYS=(mytool)
    YSU_MODERN_VALS=("bash:Always here")
    _ysu_check_modern "mytool"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *">>"* ]]
  [[ "$output" == *"bash"* ]]
}

@test "bash: default message format value" {
  run_bash '
    echo "$YSU_MESSAGE_FORMAT"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"{prefix} {arrow} {message}"* ]]
}
