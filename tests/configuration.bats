#!/usr/bin/env bats
# Tests for configuration options

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# ---- Custom prefix ----

@test "uses custom YSU_PREFIX" {
  run_zsh '
    YSU_PREFIX="[TEST]"
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"[TEST]"* ]]
}

@test "uses custom YSU_REMINDER_PREFIX" {
  run_zsh '
    YSU_REMINDER_PREFIX=" ALIAS"
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"ALIAS"* ]]
}

# ---- Cooldown ----

@test "cooldown suppresses rapid tips" {
  run_zsh '
    YSU_COOLDOWN=60
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_record_tip
    # Second check should be suppressed by cooldown via _ysu_should_show
    if _ysu_should_show; then
      echo "shown"
    else
      echo "suppressed"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"suppressed"* ]]
}

@test "no cooldown when YSU_COOLDOWN=0" {
  run_zsh '
    YSU_COOLDOWN=0
    _ysu_record_tip
    if _ysu_should_show; then
      echo "shown"
    else
      echo "suppressed"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"shown"* ]]
}

# ---- Probability ----

@test "probability=0 suppresses all tips" {
  run_zsh '
    YSU_PROBABILITY=0
    result=0
    for i in {1..20}; do
      if _ysu_should_show; then
        result=1
        break
      fi
    done
    echo "result=$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"result=0"* ]]
}

@test "probability=100 always shows tips" {
  run_zsh '
    YSU_PROBABILITY=100
    result=1
    for i in {1..20}; do
      if ! _ysu_should_show; then
        result=0
        break
      fi
    done
    echo "result=$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"result=1"* ]]
}

# ---- Ignore lists ----

@test "YSU_IGNORE_ALIASES with multiple entries" {
  run_zsh '
    alias g="git"
    alias d="docker"
    YSU_IGNORE_ALIASES="g d"
    _ysu_check_aliases "git status"
    _ysu_check_aliases "docker ps"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "YSU_IGNORE_COMMANDS with multiple entries" {
  run_zsh '
    YSU_IGNORE_COMMANDS="cat ls"
    YSU_MODERN_COMMANDS=(cat "bat:Better cat" ls "eza:Better ls")
    _ysu_check_modern "cat file"
    _ysu_check_modern "ls -la"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

# ---- Output format ----

@test "output contains arrow separator" {
  run_zsh '
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"➜"* ]]
}

@test "modern suggestion includes description" {
  run_zsh '
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    _ysu_check_modern "top"
    _ysu_get_messages
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"Interactive process viewer"* ]]
  else
    skip "htop not installed"
  fi
}

# ---- Reminder Half-life ----

@test "halflife=0 always shows tips (default)" {
  run_zsh '
    YSU_REMINDER_HALFLIFE=0
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"g"* ]]
}

@test "halflife suppresses immediately repeated tip" {
  run_zsh '
    YSU_REMINDER_HALFLIFE=3600
    YSU_LLM_CACHE_DIR="$(mktemp -d)"
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_flush
    # Second call should be suppressed (0 seconds elapsed)
    _ysu_check_aliases "git status"
    echo "count=$(_ysu_message_count)"
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "halflife does not affect different commands" {
  run_zsh '
    YSU_REMINDER_HALFLIFE=3600
    YSU_LLM_CACHE_DIR="$(mktemp -d)"
    alias g="git"
    alias d="docker"
    _ysu_check_aliases "git status"
    _ysu_flush
    # Different command should still show
    _ysu_check_aliases "docker ps"
    echo "count=$(_ysu_message_count)"
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=1"* ]]
}
