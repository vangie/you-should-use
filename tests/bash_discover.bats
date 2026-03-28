#!/usr/bin/env bats
# Tests for Bash: Alias Discovery

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_bash() {
  run bash -c "
    source '$PLUGIN_DIR/tests/bash_test_helper.bash'
    _ysu_reset
    $1
  "
}

@test "bash: _ysu_suggest_alias_name generates initials" {
  run_bash 'echo "$(_ysu_suggest_alias_name "git checkout")"'
  [ "$status" -eq 0 ]
  [[ "$output" == "gc" ]]
}

@test "bash: _ysu_suggest_alias_name skips flags" {
  run_bash 'echo "$(_ysu_suggest_alias_name "git checkout -b")"'
  [ "$status" -eq 0 ]
  [[ "$output" == "gc" ]]
}

@test "bash: _ysu_suggest_alias_name handles single word with flags" {
  run_bash 'echo "$(_ysu_suggest_alias_name "ls -la")"'
  [ "$status" -eq 0 ]
  [[ "$output" == "l-" ]]
}

@test "bash: ysu help lists discover" {
  run_bash 'ysu help'
  [ "$status" -eq 0 ]
  [[ "$output" == *"discover"* ]]
}

@test "bash: _ysu_discover shows header" {
  run_bash '
    HISTFILE="/dev/null"
    _ysu_discover
  '
  [[ "$output" == *"Alias Discovery"* ]]
}

@test "bash: _ysu_discover handles missing history file" {
  run_bash '
    HISTFILE="/nonexistent/file"
    _ysu_discover
  '
  [[ "$output" == *"No history file"* ]]
}

@test "bash: _ysu_discover with custom threshold" {
  # Create a temp history file
  run_bash '
    tmp=$(mktemp)
    for i in $(seq 1 10); do echo "git push origin main" >> "$tmp"; done
    for i in $(seq 1 3); do echo "docker compose up" >> "$tmp"; done
    HISTFILE="$tmp"
    _ysu_discover 5
    rm "$tmp"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"git push"* ]]
}
