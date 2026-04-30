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

# ---- Auto-decay ----

@test "auto-decay: shows suggestion normally under threshold" {
  run_zsh '
    YSU_AUTO_DECAY_THRESHOLD=10
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    _ysu_check_modern "top"
    echo "count=$(_ysu_message_count)"
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"count=1"* ]]
  else
    skip "htop not installed"
  fi
}

@test "auto-decay: suppresses suggestion after threshold" {
  run_zsh '
    YSU_AUTO_DECAY_THRESHOLD=3
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    # Simulate 4 prior shows (count=4 > threshold=3, not on 50th boundary)
    local dfile=$(_ysu_decay_file "top" "htop")
    mkdir -p "${dfile%/*}"
    echo 4 > "$dfile"
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

@test "auto-decay: shows with low-freq hint on 50th boundary" {
  run_zsh '
    YSU_AUTO_DECAY_THRESHOLD=3
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    # count=52 → since_threshold=49, next increment makes 53 → since=50 → 50%50==0 → show
    # Actually: count is read before increment. Let me set count=52:
    # After increment: count=53, since=53-3=50, 50%50=0 → show
    # But _ysu_decay_should_show reads the file BEFORE increment happens in _ysu_check_modern
    # In _ysu_check_modern: first increment (writes 53), then should_show reads 53
    # Wait no - _ysu_decay_increment writes, then _ysu_decay_should_show reads.
    # So set file to 52, increment makes 53, should_show reads 53, since=50, 50%50=0 → show
    local dfile=$(_ysu_decay_file "top" "htop")
    mkdir -p "${dfile%/*}"
    echo 52 > "$dfile"
    _ysu_check_modern "top"
    echo "count=$(_ysu_message_count)"
    _ysu_get_messages
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"count=1"* ]]
    [[ "$output" == *"ysu ignore"* ]]
  else
    skip "htop not installed"
  fi
}

@test "auto-decay: reset on adoption" {
  run_zsh '
    YSU_AUTO_DECAY_THRESHOLD=3
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    local dfile=$(_ysu_decay_file "top" "htop")
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

@test "auto-decay: disabled when threshold is 0" {
  run_zsh '
    YSU_AUTO_DECAY_THRESHOLD=0
    YSU_MODERN_COMMANDS=(top "htop:Interactive process viewer")
    local dfile=$(_ysu_decay_file "top" "htop")
    mkdir -p "${dfile%/*}"
    echo 999 > "$dfile"
    _ysu_check_modern "top"
    echo "count=$(_ysu_message_count)"
  '
  if command -v htop &>/dev/null; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"count=1"* ]]
  else
    skip "htop not installed"
  fi
}
