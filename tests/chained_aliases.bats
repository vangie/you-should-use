#!/usr/bin/env bats
# Tests for chained alias resolution

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

@test "chained: resolves single-level alias chain" {
  run_zsh '
    alias g="git"
    alias gp="g push"
    _ysu_check_aliases "git push"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"gp"* ]]
}

@test "chained: resolves multi-level alias chain" {
  run_zsh '
    alias g="git"
    alias gp="g push"
    alias gpf="gp --force"
    _ysu_check_aliases "git push --force"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"gpf"* ]]
}

@test "chained: prefers deeper chain (more specific match)" {
  run_zsh '
    alias g="git"
    alias gp="g push"
    _ysu_check_aliases "git push origin main"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  # gp expands to "git push" which is more specific than g="git"
  [[ "$output" == *"gp"* ]]
}

@test "chained: simple alias still works without chain" {
  run_zsh '
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"g"* ]]
}

@test "chained: expand function handles infinite loop protection" {
  run_zsh '
    # This would be an unusual config but should not hang
    alias a="b"
    alias b="a"
    # Just verify it completes without hanging
    result=$(_ysu_expand_alias "a")
    echo "completed=$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"completed="* ]]
}
