#!/usr/bin/env bats
# Tests for Feature 1: Alias Reminders

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Helper: run a zsh test script and capture output
run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# ---- Basic alias detection ----

@test "detects alias and suggests it" {
  run_zsh '
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"You should use"* ]]
  [[ "$output" == *"g"* ]]
  [[ "$output" == *"git"* ]]
}

@test "no suggestion when user already types the alias" {
  run_zsh '
    alias g="git"
    _ysu_check_aliases "g status"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "no suggestion when no matching alias exists" {
  run_zsh '
    alias g="git"
    _ysu_check_aliases "docker ps"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

# ---- Longer/more specific alias preferred ----

@test "prefers longer alias match" {
  run_zsh '
    alias g="git"
    alias gs="git status"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"gs"* ]]
}

# ---- Global aliases ----

@test "detects global alias" {
  run_zsh '
    alias -g NUL="/dev/null"
    _ysu_check_aliases "cat foo > /dev/null"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"NUL"* ]]
}

# ---- Ignore list ----

@test "ignores aliases in YSU_IGNORE_ALIASES" {
  run_zsh '
    alias g="git"
    YSU_IGNORE_ALIASES="g"
    _ysu_check_aliases "git status"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

# ---- Feature toggle ----

@test "no suggestion when YSU_REMINDER_ENABLED=false" {
  run_zsh '
    alias g="git"
    YSU_REMINDER_ENABLED=false
    _ysu_check_aliases "git status"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

# ---- Multiple aliases for same command ----

@test "handles multiple aliases for same expansion" {
  run_zsh '
    alias g="git"
    alias gi="git"
    _ysu_check_aliases "git status"
    count=$(_ysu_message_count)
    echo "count=$count"
  '
  [ "$status" -eq 0 ]
  # Should produce exactly 1 message (best match)
  [[ "$output" == *"count=1"* ]]
}
