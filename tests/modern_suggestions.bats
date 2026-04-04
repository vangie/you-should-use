#!/usr/bin/env bats
# Tests for Feature 2: Modern Command Suggestions

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# ---- Basic modern command suggestion ----

@test "suggests modern alternative when installed" {
  run_zsh '
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    _ysu_check_modern "top"
    _ysu_get_messages
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"htop"* ]]
    [[ "$output" == *"top"* ]]
  else
    skip "htop not installed"
  fi
}

@test "no suggestion when modern command not installed" {
  run_zsh '
    YSU_MODERN_COMMANDS=(cat "nonexistent_tool_xyz:Fake tool")
    _ysu_check_modern "cat README.md"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "no suggestion when command has no mapping" {
  run_zsh '
    _ysu_check_modern "echo hello"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

# ---- Feature toggle ----

@test "no suggestion when YSU_SUGGEST_ENABLED=false" {
  run_zsh '
    YSU_SUGGEST_ENABLED=false
    YSU_MODERN_COMMANDS=(cat "bat:Better cat")
    _ysu_check_modern "cat README.md"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

# ---- Ignore list ----

@test "ignores commands in YSU_IGNORE_COMMANDS" {
  run_zsh '
    YSU_IGNORE_COMMANDS="cat"
    YSU_MODERN_COMMANDS=(cat "bat:Better cat")
    _ysu_check_modern "cat README.md"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "ignores specific suggestion via YSU_IGNORE_SUGGESTIONS" {
  run_zsh '
    YSU_IGNORE_SUGGESTIONS="cat:bat"
    YSU_MODERN_COMMANDS=(cat "bat:Better cat")
    YSU_INSTALL_HINT=false
    _ysu_check_modern "cat README.md"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "YSU_IGNORE_SUGGESTIONS does not suppress other commands" {
  run_zsh '
    YSU_IGNORE_SUGGESTIONS="cat:bat"
    YSU_MODERN_COMMANDS=(cat "bat:Better cat" ls "eza:Modern ls")
    _ysu_check_modern "ls -la"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  if command -v eza &>/dev/null; then
    [[ "$output" == *"eza"* ]]
  fi
}

@test "_ysu_is_ignored_suggestion matches exact pair" {
  run_zsh '
    YSU_IGNORE_SUGGESTIONS="make:just cat:bat"
    _ysu_is_ignored_suggestion "make" "just" && echo "matched" || echo "no"
    _ysu_is_ignored_suggestion "cat" "bat" && echo "matched" || echo "no"
    _ysu_is_ignored_suggestion "make" "bat" && echo "matched" || echo "no"
    _ysu_is_ignored_suggestion "cat" "just" && echo "matched" || echo "no"
  '
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "matched" ]]
  [[ "${lines[1]}" == "matched" ]]
  [[ "${lines[2]}" == "no" ]]
  [[ "${lines[3]}" == "no" ]]
}

# ---- Multiple alternatives (pipe-separated) ----

@test "suggests first installed alternative from pipe-separated list" {
  run_zsh '
    YSU_MODERN_COMMANDS=(top "nonexistent_xyz:Fake|htop:Interactive process viewer")
    _ysu_check_modern "top"
    _ysu_get_messages
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"htop"* ]]
  else
    skip "htop not installed"
  fi
}

# ---- Skip when aliased to modern command ----

@test "skips suggestion when command is aliased to modern alternative" {
  run_zsh '
    alias top="htop"
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    _ysu_check_modern "top"
    echo "count=$(_ysu_message_count)"
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"count=0"* ]]
  else
    skip "htop not installed"
  fi
}

@test "still suggests when aliased to a different command" {
  run_zsh '
    alias top="less"
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    _ysu_check_modern "top"
    _ysu_get_messages
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"htop"* ]]
  else
    skip "htop not installed"
  fi
}
