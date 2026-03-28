#!/usr/bin/env bats
# Tests for custom message templates feature

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# ---- Default format ----

@test "message format: default contains prefix, arrow, and message" {
  run_zsh '
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"➜"* ]]
  [[ "$output" == *"You should use"* ]]
}

# ---- Custom format ----

@test "message format: custom format without arrow" {
  run_zsh '
    YSU_MESSAGE_FORMAT="[{prefix}] {message}"
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  # Should have prefix in brackets
  [[ "$output" == *"["* ]]
  [[ "$output" == *"]"* ]]
  [[ "$output" == *"You should use"* ]]
}

@test "message format: custom format with only message" {
  run_zsh '
    YSU_MESSAGE_FORMAT="{message}"
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"You should use"* ]]
  [[ "$output" == *"g"* ]]
}

@test "message format: custom format preserves prefix content" {
  run_zsh '
    YSU_PREFIX="HINT"
    YSU_MESSAGE_FORMAT="{prefix}: {message}"
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"HINT:"* ]]
}

@test "message format: works with modern suggestions too" {
  run_zsh '
    YSU_MESSAGE_FORMAT=">> {message}"
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    _ysu_check_modern "top"
    _ysu_get_messages
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *">>"* ]]
    [[ "$output" == *"htop"* ]]
  else
    skip "htop not installed"
  fi
}

@test "message format: default value is correct" {
  run_zsh '
    echo "$YSU_MESSAGE_FORMAT"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"{prefix} {arrow} {message}"* ]]
}
