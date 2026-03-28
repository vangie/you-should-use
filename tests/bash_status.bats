#!/usr/bin/env bats
# Tests for Bash: Status command

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_bash() {
  run bash -c "
    source '$PLUGIN_DIR/tests/bash_test_helper.bash'
    _ysu_reset
    $1
  "
}

@test "bash: ysu status shows core settings" {
  run_bash '_ysu_status'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Core Settings"* ]]
  [[ "$output" == *"Alias Reminders"* ]]
  [[ "$output" == *"Modern Suggestions"* ]]
}

@test "bash: ysu status shows LLM settings" {
  run_bash '_ysu_status'
  [ "$status" -eq 0 ]
  [[ "$output" == *"LLM Settings"* ]]
  [[ "$output" == *"disabled"* ]]
}

@test "bash: ysu status shows statistics" {
  run_bash '_ysu_status'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Statistics"* ]]
  [[ "$output" == *"Modern mappings"* ]]
}

@test "bash: ysu status shows config file section" {
  run_bash '_ysu_status'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Config File"* ]]
}

@test "bash: ysu help shows usage" {
  run_bash 'ysu help'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ysu"* ]]
  [[ "$output" == *"config"* ]]
  [[ "$output" == *"cache"* ]]
  [[ "$output" == *"status"* ]]
}

@test "bash: ysu status shows package manager" {
  run_bash '_ysu_status'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Package Manager"* ]]
}

@test "bash: platform detection sets _YSU_PKG_MANAGER" {
  run_bash 'echo "$_YSU_PKG_MANAGER"'
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
  [[ "$output" != "unknown" ]]
}

@test "bash: platform detection sets _YSU_PKG_INSTALL" {
  run_bash 'echo "$_YSU_PKG_INSTALL"'
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
}

@test "bash: _ysu_get_pkg_name resolves overrides" {
  run_bash 'echo "$(_ysu_get_pkg_name rg)"'
  [ "$status" -eq 0 ]
  [[ "$output" == "ripgrep" ]]
}

@test "bash: _ysu_get_pkg_name returns tool name when no override" {
  run_bash 'echo "$(_ysu_get_pkg_name bat)"'
  [ "$status" -eq 0 ]
  [[ "$output" == "bat" ]]
}

@test "bash: ysu status shows multi-command info when mode is both" {
  run_bash '
    YSU_LLM_MODE="both"
    _ysu_multi_push_cmd "cmd1"
    _ysu_multi_push_cmd "cmd2"
    _ysu_status
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Window Size"* ]]
  [[ "$output" == *"History Buffer"* ]]
}
