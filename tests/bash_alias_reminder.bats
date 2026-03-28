#!/usr/bin/env bats
# Tests for Bash: Alias Reminders

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Helper: run a bash test script and capture output
run_bash() {
  run bash -c "
    source '$PLUGIN_DIR/tests/bash_test_helper.bash'
    _ysu_reset
    $1
  "
}

@test "bash: detects alias and suggests it" {
  run_bash '
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"You should use"* ]]
  [[ "$output" == *"g"* ]]
  [[ "$output" == *"git"* ]]
}

@test "bash: no suggestion when user already types the alias" {
  run_bash '
    alias g="git"
    _ysu_check_aliases "g status"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: no suggestion when no matching alias exists" {
  run_bash '
    alias g="git"
    _ysu_check_aliases "docker ps"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: prefers longer alias match" {
  run_bash '
    alias g="git"
    alias gs="git status"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"gs"* ]]
}

@test "bash: ignores aliases in YSU_IGNORE_ALIASES" {
  run_bash '
    alias g="git"
    YSU_IGNORE_ALIASES="g"
    _ysu_check_aliases "git status"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: no suggestion when YSU_REMINDER_ENABLED=false" {
  run_bash '
    alias g="git"
    YSU_REMINDER_ENABLED=false
    _ysu_check_aliases "git status"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: handles multiple aliases for same expansion" {
  run_bash '
    alias g="git"
    alias gi="git"
    _ysu_check_aliases "git status"
    count=$(_ysu_message_count)
    echo "count=$count"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=1"* ]]
}

@test "bash: strips sudo prefix for alias matching" {
  run_bash '
    alias apt="apt-get"
    _ysu_check_aliases "sudo apt-get install foo"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"You should use"* ]]
  [[ "$output" == *"apt"* ]]
}
