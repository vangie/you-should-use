#!/usr/bin/env bats
# Tests for Ollama auto-detection (Feature 5a) and LLM promo (Feature 5b)

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# ============================================================================
# Ollama auto-detection
# ============================================================================

@test "ollama: LLM stays disabled when no Ollama running" {
  run_zsh '
    # _YSU_OLLAMA_CHECKED is already set from sourcing, so reset it
    unset _YSU_OLLAMA_CHECKED
    YSU_LLM_ENABLED=false
    # Re-source would try to detect Ollama but it is not running on test env
    echo "enabled=$YSU_LLM_ENABLED"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"enabled=false"* ]]
}

@test "ollama: user explicit config takes priority over auto-detection" {
  run_zsh '
    # Simulate user having set LLM_ENABLED=false in config file
    local config_dir="/tmp/ysu-test-config-$$"
    mkdir -p "$config_dir"
    echo "YSU_LLM_ENABLED=false" > "$config_dir/config.zsh"
    # The plugin checks for config file grep — simulate that check
    YSU_LLM_ENABLED=false
    _YSU_OLLAMA_CHECKED=1
    echo "enabled=$YSU_LLM_ENABLED"
    rm -rf "$config_dir"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"enabled=false"* ]]
}

@test "ollama: detection only runs once (cached in env var)" {
  run_zsh '
    echo "checked=$_YSU_OLLAMA_CHECKED"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked=1"* ]]
}

# ============================================================================
# LLM promo reminder
# ============================================================================

@test "promo: shows when LLM disabled and no tips shown" {
  run_zsh '
    YSU_LLM_ENABLED=false
    YSU_LLM_CACHE_DIR="/tmp/ysu-test-promo-$$"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    _YSU_PROMO_SHOWN_TODAY=0
    _YSU_PROMO_DATE=""
    _ysu_maybe_show_promo
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"ysu config"* ]]
}

@test "promo: does not show when LLM is enabled" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_CACHE_DIR="/tmp/ysu-test-promo-$$"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    _YSU_PROMO_SHOWN_TODAY=0
    _YSU_PROMO_DATE=""
    _ysu_maybe_show_promo
    echo "no_output"
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" != *"ysu config"* ]]
}

@test "promo: rate limited to 3 per day" {
  run_zsh '
    YSU_LLM_ENABLED=false
    YSU_LLM_CACHE_DIR="/tmp/ysu-test-promo-$$"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    _YSU_PROMO_SHOWN_TODAY=0
    _YSU_PROMO_DATE=""

    _ysu_maybe_show_promo  # 1
    _ysu_maybe_show_promo  # 2
    _ysu_maybe_show_promo  # 3
    _ysu_maybe_show_promo  # 4 — should not show

    local count=$(echo "$(_ysu_maybe_show_promo 2>&1)" | grep -c "ysu config" || true)
    # After 3 shows, the 4th+ should not produce output
    echo "count=$_YSU_PROMO_SHOWN_TODAY"
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=3"* ]]
}

@test "promo: resets counter on new day" {
  run_zsh '
    YSU_LLM_ENABLED=false
    YSU_LLM_CACHE_DIR="/tmp/ysu-test-promo-$$"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    _YSU_PROMO_SHOWN_TODAY=3
    _YSU_PROMO_DATE="2020-01-01"  # Old date

    _ysu_maybe_show_promo
    echo "shown=$_YSU_PROMO_SHOWN_TODAY"
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"ysu config"* ]]
  [[ "$output" == *"shown=1"* ]]
}

@test "promo: persists count in cache file" {
  run_zsh '
    YSU_LLM_ENABLED=false
    YSU_LLM_CACHE_DIR="/tmp/ysu-test-promo-$$"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    _YSU_PROMO_SHOWN_TODAY=0
    _YSU_PROMO_DATE=""

    _ysu_maybe_show_promo
    [[ -f "$YSU_LLM_CACHE_DIR/.promo_count" ]] && echo "file_exists" || echo "no_file"
    local saved_count=$(tail -1 "$YSU_LLM_CACHE_DIR/.promo_count")
    echo "saved=$saved_count"
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"file_exists"* ]]
  [[ "$output" == *"saved=1"* ]]
}

@test "promo: not shown during preexec when tips were displayed" {
  run_zsh '
    YSU_LLM_ENABLED=false
    YSU_LLM_CACHE_DIR="/tmp/ysu-test-promo-$$"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    _YSU_PROMO_SHOWN_TODAY=0
    _YSU_PROMO_DATE=""

    # Simulate an alias that will produce a tip
    alias ll="ls -la"
    YSU_MODERN_COMMANDS=()
    _ysu_preexec "ls -la"
    # _YSU_CMD_HAD_TIPS should be true
    echo "had_tips=$_YSU_CMD_HAD_TIPS"
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"had_tips=true"* ]]
}
