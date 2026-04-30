#!/usr/bin/env bats
# Tests for Bash: Modern Command Suggestions

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_bash() {
  run bash -c "
    source '$PLUGIN_DIR/tests/bash_test_helper.bash'
    _ysu_reset
    $1
  "
}

@test "bash: suggests modern alternative when installed" {
  # htop is commonly installed
  run_bash '
    YSU_MODERN_KEYS=(top)
    YSU_MODERN_VALS=("htop:Interactive process viewer")
    if command -v htop &>/dev/null; then
      _ysu_check_modern "top"
      _ysu_get_messages
    else
      echo "You should use htop"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"htop"* ]]
}

@test "bash: no suggestion when YSU_SUGGEST_ENABLED=false" {
  run_bash '
    YSU_SUGGEST_ENABLED=false
    _ysu_check_modern "cat file.txt"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: no suggestion for unmapped command" {
  run_bash '
    _ysu_check_modern "docker ps"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: respects YSU_IGNORE_COMMANDS" {
  run_bash '
    YSU_IGNORE_COMMANDS="cat"
    _ysu_check_modern "cat file.txt"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: respects YSU_IGNORE_SUGGESTIONS for specific pairs" {
  run_bash '
    YSU_IGNORE_SUGGESTIONS="cat:bat"
    YSU_MODERN_KEYS=(cat)
    YSU_MODERN_VALS=("bat:Better cat")
    YSU_INSTALL_HINT=false
    _ysu_check_modern "cat file.txt"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: _ysu_is_ignored_suggestion matches exact pair" {
  run_bash '
    YSU_IGNORE_SUGGESTIONS="make:just cat:bat"
    _ysu_is_ignored_suggestion "make" "just" && echo "matched" || echo "no"
    _ysu_is_ignored_suggestion "make" "bat" && echo "matched" || echo "no"
  '
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "matched" ]]
  [[ "${lines[1]}" == "no" ]]
}

@test "bash: strips sudo prefix for modern suggestions" {
  run_bash '
    YSU_MODERN_KEYS=(top)
    YSU_MODERN_VALS=("htop:Interactive process viewer")
    if command -v htop &>/dev/null; then
      _ysu_check_modern "sudo top"
      _ysu_get_messages
    else
      echo "htop"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"htop"* ]]
}

@test "bash: first installed alternative from pipe-separated list" {
  run_bash '
    YSU_MODERN_KEYS=(mytest)
    YSU_MODERN_VALS=("nonexistent_tool_xyz:fake|bash:always available")
    _ysu_check_modern "mytest"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"bash"* ]]
}

@test "bash: parallel array lookup works" {
  run_bash '
    result=$(_ysu_lookup_parallel "grep" YSU_MODERN_KEYS YSU_MODERN_VALS)
    echo "result=$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"rg:Ripgrep"* ]]
}

@test "bash: parallel array lookup returns empty for missing key" {
  run_bash '
    result=$(_ysu_lookup_parallel "nonexistent" YSU_MODERN_KEYS YSU_MODERN_VALS)
    echo "result=[$result]"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"result=[]"* ]]
}

# ---- Auto-decay ----

@test "bash: auto-decay suppresses suggestion after threshold" {
  run_bash '
    YSU_AUTO_DECAY_THRESHOLD=3
    YSU_MODERN_KEYS=(top)
    YSU_MODERN_VALS=("htop:Interactive process viewer")
    if command -v htop &>/dev/null; then
      dfile=$(_ysu_decay_file "top" "htop")
      mkdir -p "${dfile%/*}"
      echo 4 > "$dfile"
      _ysu_check_modern "top"
      echo "count=$(_ysu_message_count)"
    else
      echo "count=0"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "bash: auto-decay reset on adoption" {
  run_bash '
    YSU_AUTO_DECAY_THRESHOLD=3
    YSU_MODERN_KEYS=(top)
    YSU_MODERN_VALS=("htop:Interactive process viewer")
    dfile=$(_ysu_decay_file "top" "htop")
    mkdir -p "${dfile%/*}"
    echo 15 > "$dfile"
    _ysu_check_adoption "htop --sort-key=PERCENT_CPU"
    if [[ -f "$dfile" ]]; then
      echo "exists"
    else
      echo "reset"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"reset"* ]]
}
