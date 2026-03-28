#!/usr/bin/env bats
# Tests for Bash: Install Hints

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_bash() {
  run bash -c "
    source '$PLUGIN_DIR/tests/bash_test_helper.bash'
    _ysu_reset
    $1
  "
}

@test "bash: shows install command when modern tool not installed" {
  run_bash '
    YSU_MODERN_KEYS=(mytool)
    YSU_MODERN_VALS=("nonexistent_tool_abc:A great tool")
    YSU_INSTALL_KEYS=(nonexistent_tool_abc)
    YSU_INSTALL_VALS=("brew install nonexistent_tool_abc")
    _ysu_check_modern "mytool"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Try"* ]]
  [[ "$output" == *"nonexistent_tool_abc"* ]]
  [[ "$output" == *"brew install nonexistent_tool_abc"* ]]
}

@test "bash: no install hint when YSU_INSTALL_HINT=false" {
  run_bash '
    YSU_INSTALL_HINT=false
    YSU_MODERN_KEYS=(mytool)
    YSU_MODERN_VALS=("nonexistent_tool_abc:A great tool")
    YSU_INSTALL_KEYS=(nonexistent_tool_abc)
    YSU_INSTALL_VALS=("brew install nonexistent_tool_abc")
    _ysu_check_modern "mytool"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: no install hint when no install mapping exists" {
  run_bash '
    YSU_MODERN_KEYS=(mytool)
    YSU_MODERN_VALS=("nonexistent_tool_xyz:A great tool")
    YSU_INSTALL_KEYS=()
    YSU_INSTALL_VALS=()
    _ysu_check_modern "mytool"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: prefers installed tool over install hint" {
  run_bash '
    YSU_MODERN_KEYS=(mytool)
    YSU_MODERN_VALS=("bash:Always here|nonexistent_xyz:Not here")
    _ysu_check_modern "mytool"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"You should use"* ]]
  [[ "$output" == *"bash"* ]]
  [[ "$output" != *"install"* ]]
}

@test "bash: first uninstalled alternative shown in install hint" {
  run_bash '
    YSU_MODERN_KEYS=(mytool)
    YSU_MODERN_VALS=("nonexistent_a:Tool A|nonexistent_b:Tool B")
    YSU_INSTALL_KEYS=(nonexistent_a nonexistent_b)
    YSU_INSTALL_VALS=("brew install a" "brew install b")
    _ysu_check_modern "mytool"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"nonexistent_a"* ]]
  [[ "$output" == *"brew install a"* ]]
}

@test "bash: default bat install mapping" {
  run_bash '
    result=$(_ysu_lookup_parallel "bat" YSU_INSTALL_KEYS YSU_INSTALL_VALS)
    echo "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew install bat"* ]]
}

@test "bash: default rg install mapping" {
  run_bash '
    result=$(_ysu_lookup_parallel "rg" YSU_INSTALL_KEYS YSU_INSTALL_VALS)
    echo "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew install ripgrep"* ]]
}
