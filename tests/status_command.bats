#!/usr/bin/env bats
# Tests for ysu status subcommand

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# Strip ANSI escape codes from output for easier matching
strip_ansi() {
  echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# ---- Basic output ----

@test "ysu status shows header" {
  run_zsh '_ysu_status'
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"you-should-use status"* ]]
}

@test "ysu status shows Core Settings section" {
  run_zsh '_ysu_status'
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Core Settings:"* ]]
}

@test "ysu status shows LLM Settings section" {
  run_zsh '_ysu_status'
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"LLM Settings:"* ]]
}

@test "ysu status shows Statistics section" {
  run_zsh '_ysu_status'
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Statistics:"* ]]
}

@test "ysu status shows Config File section" {
  run_zsh '_ysu_status'
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Config File:"* ]]
}

# ---- Core settings values ----

@test "ysu status shows alias reminders enabled" {
  run_zsh '
    YSU_REMINDER_ENABLED=true
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Alias Reminders:"*"enabled"* ]]
}

@test "ysu status shows alias reminders disabled" {
  run_zsh '
    YSU_REMINDER_ENABLED=false
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Alias Reminders:"*"disabled"* ]]
}

@test "ysu status shows probability" {
  run_zsh '
    YSU_PROBABILITY=75
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Probability:"*"75%"* ]]
}

@test "ysu status shows cooldown" {
  run_zsh '
    YSU_COOLDOWN=30
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Cooldown:"*"30s"* ]]
}

# ---- LLM settings ----

@test "ysu status shows LLM disabled" {
  run_zsh '
    YSU_LLM_ENABLED=false
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Enabled:"*"disabled"* ]]
}

@test "ysu status shows LLM enabled" {
  run_zsh '
    YSU_LLM_ENABLED=true
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Enabled:"*"enabled"* ]]
}

@test "ysu status shows specific model name" {
  run_zsh '
    YSU_LLM_MODEL="my-model"
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Model:"*"my-model"* ]]
}

@test "ysu status shows auto with resolved model" {
  run_zsh '
    YSU_LLM_MODEL="auto"
    _YSU_LLM_RESOLVED_MODEL="llama3.1:8b"
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Model:"*"auto (llama3.1:8b)"* ]]
}

@test "ysu status shows auto unresolved when no model resolved" {
  run_zsh '
    YSU_LLM_MODEL="auto"
    _YSU_LLM_RESOLVED_MODEL=""
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Model:"*"auto (unresolved)"* ]]
}

@test "ysu status shows API key masked" {
  run_zsh '
    YSU_LLM_API_KEY="sk-abcdef1234567890"
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"API Key:"*"••••7890"* ]]
}

@test "ysu status shows API key not set" {
  run_zsh '
    YSU_LLM_API_KEY=""
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"API Key:"*"(not set)"* ]]
}

# ---- Statistics ----

@test "ysu status shows cache entries count" {
  run_zsh '
    mkdir -p "$YSU_LLM_CACHE_DIR"
    echo "test1" > "$YSU_LLM_CACHE_DIR/abc123"
    echo "test2" > "$YSU_LLM_CACHE_DIR/def456"
    _ysu_status
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Cache:"*"2 entries"* ]]
}

@test "ysu status shows 0 cache entries when empty" {
  run_zsh '
    rm -rf "$YSU_LLM_CACHE_DIR"
    mkdir -p "$YSU_LLM_CACHE_DIR"
    _ysu_status
    rm -rf "$YSU_LLM_CACHE_DIR"
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Cache:"*"0 entries"* ]]
}

@test "ysu status shows modern mappings count" {
  run_zsh '
    YSU_MODERN_COMMANDS=(cat "bat:test" ls "eza:test" find "fd:test")
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Modern mappings:"*"3"* ]]
}

@test "ysu status shows promo count when LLM disabled" {
  run_zsh '
    YSU_LLM_ENABLED=false
    _YSU_PROMO_SHOWN_TODAY=2
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"Promo shown today:"*"2/3"* ]]
}

@test "ysu status hides promo count when LLM enabled" {
  run_zsh '
    YSU_LLM_ENABLED=true
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" != *"Promo shown today:"* ]]
}

# ---- ysu command routing ----

@test "ysu status subcommand is recognized" {
  run_zsh 'ysu status'
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"you-should-use status"* ]]
}

@test "ysu help lists status command" {
  run_zsh 'ysu help'
  [ "$status" -eq 0 ]
  [[ "$output" == *"status"* ]]
}

# ---- Config file detection ----

@test "ysu status shows no config file" {
  run_zsh '
    # Use a non-existent config location
    export XDG_CONFIG_HOME="/tmp/ysu-test-nonexistent-$$"
    _ysu_status
  '
  [ "$status" -eq 0 ]
  clean=$(strip_ansi "$output")
  [[ "$clean" == *"none"*"using defaults"* ]]
}
