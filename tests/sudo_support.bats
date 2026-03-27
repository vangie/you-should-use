#!/usr/bin/env bats
# Tests for sudo prefix stripping and three-tier sudo priority

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# Helper: count tip lines (➜) in output
count_tips() {
  echo "$output" | grep -c "➜" || true
}

# ============================================================================
# Basic sudo handling
# ============================================================================

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

# ============================================================================
# Three-tier sudo priority
# ============================================================================

@test "sudo priority 1: inner command alias takes priority over sudo alias" {
  run_zsh '
    alias _="sudo"
    alias g="git"
    YSU_MODERN_COMMANDS=()
    _ysu_preexec "sudo git status"
  '
  [ "$status" -eq 0 ]
  # Should show inner alias suggestion (g), not sudo alias (_)
  [ "$(count_tips)" -eq 1 ]
  [[ "$output" == *"g"* ]]
  [[ "$output" != *"_ git"* ]]
}

@test "sudo priority 1: modern tool suggestion takes priority over sudo alias" {
  run_zsh '
    alias _="sudo"
    YSU_MODERN_COMMANDS=(cat "bat:Syntax highlighting")
    _ysu_preexec "sudo cat file.txt"
  '
  if command -v bat &>/dev/null; then
    [ "$status" -eq 0 ]
    # Should show modern tool suggestion (bat), not sudo alias (_)
    [ "$(count_tips)" -eq 1 ]
    [[ "$output" == *"bat"* ]]
    [[ "$output" != *"_ cat"* ]]
  else
    skip "bat not installed"
  fi
}

@test "sudo priority 2: sudo alias suggested when inner command has no suggestion" {
  run_zsh '
    alias _="sudo"
    YSU_MODERN_COMMANDS=()
    _ysu_preexec "sudo ls"
  '
  [ "$status" -eq 0 ]
  # No inner suggestion for ls → suggest _ ls instead of sudo ls
  [ "$(count_tips)" -eq 1 ]
  [[ "$output" == *"_ ls"* ]]
  [[ "$output" == *"sudo ls"* ]]
}

@test "sudo priority 2: sudo alias with trailing space also works" {
  run_zsh '
    alias sudo="sudo "
    alias _="sudo"
    YSU_MODERN_COMMANDS=()
    _ysu_preexec "sudo ls"
  '
  [ "$status" -eq 0 ]
  [ "$(count_tips)" -eq 1 ]
  [[ "$output" == *"_ ls"* ]]
}

@test "sudo priority 3: no suggestion when no alias and no modern tool" {
  run_zsh '
    YSU_MODERN_COMMANDS=()
    _ysu_preexec "sudo ls"
  '
  [ "$status" -eq 0 ]
  [ "$(count_tips)" -eq 0 ]
}

@test "sudo priority: max one suggestion per command" {
  run_zsh '
    alias _="sudo"
    alias g="git"
    YSU_MODERN_COMMANDS=()
    _ysu_preexec "sudo git status"
  '
  [ "$status" -eq 0 ]
  # Inner alias found (g for git), so sudo alias (_ for sudo) should NOT also appear
  [ "$(count_tips)" -eq 1 ]
}

@test "sudo priority: ignored sudo alias is not suggested" {
  run_zsh '
    alias _="sudo"
    YSU_IGNORE_ALIASES="_"
    YSU_MODERN_COMMANDS=()
    _ysu_preexec "sudo ls"
  '
  [ "$status" -eq 0 ]
  [ "$(count_tips)" -eq 0 ]
}
