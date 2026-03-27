#!/usr/bin/env bats
# Tests for sudo prefix stripping

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

@test "sudo: detects alias behind sudo" {
  run_zsh '
    alias g="git"
    # Simulate preexec with sudo prefix
    typed_command="sudo git status"
    check_command="${typed_command#sudo }"
    _ysu_check_aliases "$check_command"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"g"* ]]
  [[ "$output" == *"git"* ]]
}

@test "sudo: detects modern command behind sudo" {
  run_zsh '
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    typed_command="sudo top"
    check_command="${typed_command#sudo }"
    _ysu_check_modern "$check_command"
    _ysu_get_messages
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"htop"* ]]
  else
    skip "htop not installed"
  fi
}

@test "sudo: does not suggest sudo alias when command has sudo prefix" {
  run_zsh '
    alias _="sudo"
    _ysu_preexec "sudo ls"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "sudo: bare sudo with no args produces no suggestion" {
  run_zsh '
    alias _="sudo"
    _ysu_preexec "sudo"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "sudo: no false match on commands starting with sudo prefix" {
  run_zsh '
    alias g="git"
    _ysu_check_aliases "sudoku"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "sudo: non-sudo commands still work normally" {
  run_zsh '
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"g"* ]]
}
