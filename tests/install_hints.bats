#!/usr/bin/env bats
# Tests for install command hints feature

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# ---- Install hint when tool not installed ----

@test "install hint: shows install command when modern tool not installed" {
  run_zsh '
    YSU_MODERN_COMMANDS=(cat "nonexistent_tool_xyz:A better cat")
    YSU_INSTALL_COMMANDS=(nonexistent_tool_xyz "brew install nonexistent_tool_xyz")
    _ysu_check_modern "cat README.md"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Try"* ]]
  [[ "$output" == *"nonexistent_tool_xyz"* ]]
  [[ "$output" == *"brew install nonexistent_tool_xyz"* ]]
  [[ "$output" == *"install:"* ]]
}

@test "install hint: no hint when YSU_INSTALL_HINT=false" {
  run_zsh '
    YSU_INSTALL_HINT=false
    YSU_MODERN_COMMANDS=(cat "nonexistent_tool_xyz:A better cat")
    YSU_INSTALL_COMMANDS=(nonexistent_tool_xyz "brew install nonexistent_tool_xyz")
    _ysu_check_modern "cat README.md"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "install hint: no hint when no install command defined" {
  run_zsh '
    YSU_MODERN_COMMANDS=(cat "nonexistent_tool_xyz:A better cat")
    YSU_INSTALL_COMMANDS=()
    _ysu_check_modern "cat README.md"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "install hint: prefers installed tool over install hint" {
  run_zsh '
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    YSU_INSTALL_COMMANDS=(htop "brew install htop")
    _ysu_check_modern "top"
    _ysu_get_messages
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"You should use"* ]]
    [[ "$output" != *"install:"* ]]
  else
    [ "$status" -eq 0 ]
    [[ "$output" == *"install:"* ]]
  fi
}

@test "install hint: shows first alternative from pipe-separated list" {
  run_zsh '
    YSU_MODERN_COMMANDS=(cat "nonexistent_a:Tool A|nonexistent_b:Tool B")
    YSU_INSTALL_COMMANDS=(nonexistent_a "brew install a" nonexistent_b "brew install b")
    _ysu_check_modern "cat README.md"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"nonexistent_a"* ]]
  [[ "$output" == *"brew install a"* ]]
}

@test "install hint: default mappings include bat" {
  run_zsh '
    echo "${YSU_INSTALL_COMMANDS[bat]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"install"* ]]
  [[ "$output" == *"bat"* ]]
}

@test "install hint: default mappings include ripgrep" {
  run_zsh '
    echo "${YSU_INSTALL_COMMANDS[rg]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"install"* ]]
  [[ "$output" == *"ripgrep"* ]]
}
