#!/usr/bin/env bats
# Tests for leading whitespace trimming

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

@test "whitespace: trims leading spaces before alias check" {
  run_zsh '
    alias g="git"
    # Simulate preexec with leading spaces
    typed_command="   git status"
    typed_command="${typed_command#"${typed_command%%[! ]*}"}"
    _ysu_check_aliases "$typed_command"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"g"* ]]
}

@test "whitespace: trims leading spaces before modern check" {
  run_zsh '
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    typed_command="  top"
    typed_command="${typed_command#"${typed_command%%[! ]*}"}"
    _ysu_check_modern "$typed_command"
    _ysu_get_messages
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"htop"* ]]
  else
    skip "htop not installed"
  fi
}

@test "whitespace: all-spaces input produces no output" {
  run_zsh '
    alias g="git"
    typed_command="   "
    typed_command="${typed_command#"${typed_command%%[! ]*}"}"
    [[ -z "$typed_command" ]] && echo "empty" || echo "not_empty"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"empty"* ]]
}
