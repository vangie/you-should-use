#!/usr/bin/env bats
# Tests for Alias Discovery (Zsh)

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

@test "discover: _ysu_suggest_alias_name generates initials" {
  run_zsh 'echo "$(_ysu_suggest_alias_name "git checkout")"'
  [ "$status" -eq 0 ]
  [[ "$output" == "gc" ]]
}

@test "discover: _ysu_suggest_alias_name skips flags" {
  run_zsh 'echo "$(_ysu_suggest_alias_name "git checkout -b")"'
  [ "$status" -eq 0 ]
  [[ "$output" == "gc" ]]
}

@test "discover: ysu help lists discover" {
  run_zsh 'ysu help'
  [ "$status" -eq 0 ]
  [[ "$output" == *"discover"* ]]
}

@test "discover: _ysu_discover shows header" {
  run_zsh '
    HISTFILE="/dev/null"
    _ysu_discover
  '
  [[ "$output" == *"Alias Discovery"* ]]
}

@test "discover: handles missing history file" {
  run_zsh '
    HISTFILE="/nonexistent/file"
    _ysu_discover
  '
  [[ "$output" == *"No history file"* ]]
}

@test "discover: finds frequent commands" {
  run_zsh '
    tmp=$(mktemp)
    for i in {1..10}; do echo "git push origin main" >> "$tmp"; done
    for i in {1..3}; do echo "docker compose up" >> "$tmp"; done
    HISTFILE="$tmp"
    _ysu_discover 5
    rm "$tmp"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"git push"* ]]
}
