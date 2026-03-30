#!/usr/bin/env bats
# Tests for Bash: Configuration and defaults

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_bash() {
  run bash -c "
    source '$PLUGIN_DIR/tests/bash_test_helper.bash'
    _ysu_reset
    $1
  "
}

@test "bash: default YSU_REMINDER_ENABLED is true" {
  run_bash 'echo "$YSU_REMINDER_ENABLED"'
  [ "$status" -eq 0 ]
  [[ "$output" == "true" ]]
}

@test "bash: default YSU_SUGGEST_ENABLED is true" {
  run_bash 'echo "$YSU_SUGGEST_ENABLED"'
  [ "$status" -eq 0 ]
  [[ "$output" == "true" ]]
}

@test "bash: default YSU_LLM_ENABLED is false" {
  run_bash 'echo "$YSU_LLM_ENABLED"'
  [ "$status" -eq 0 ]
  [[ "$output" == "false" ]]
}

@test "bash: default probability is 100" {
  run_bash 'echo "$YSU_PROBABILITY"'
  [ "$status" -eq 0 ]
  [[ "$output" == "100" ]]
}

@test "bash: default cooldown is 0" {
  run_bash 'echo "$YSU_COOLDOWN"'
  [ "$status" -eq 0 ]
  [[ "$output" == "0" ]]
}

@test "bash: default prefix" {
  run_bash 'echo "$YSU_PREFIX"'
  [ "$status" -eq 0 ]
  [[ "$output" == "💡" ]]
}

@test "bash: default install hint is true" {
  run_bash 'echo "$YSU_INSTALL_HINT"'
  [ "$status" -eq 0 ]
  [[ "$output" == "true" ]]
}

@test "bash: modern commands mapping has correct count" {
  run_bash 'echo "${#YSU_MODERN_KEYS[@]}"'
  [ "$status" -eq 0 ]
  [[ "$output" == "25" ]]
}

@test "bash: install commands mapping has correct count" {
  run_bash 'echo "${#YSU_INSTALL_KEYS[@]}"'
  [ "$status" -eq 0 ]
  [[ "$output" == "32" ]]
}

@test "bash: should_show respects probability" {
  run_bash '
    YSU_PROBABILITY=0
    if _ysu_should_show; then
      echo "shown"
    else
      echo "hidden"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "hidden" ]]
}

@test "bash: should_show respects cooldown" {
  run_bash '
    YSU_COOLDOWN=9999
    _YSU_LAST_TIP_TIME=$(date +%s)
    if _ysu_should_show; then
      echo "shown"
    else
      echo "hidden"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "hidden" ]]
}

@test "bash: json_escape handles special characters" {
  run_bash '
    result=$(_ysu_json_escape "hello \"world\" \\path")
    echo "$result"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *'hello \"world\" \\path'* ]]
}

@test "bash: get_effective_model returns resolved model for auto" {
  run_bash '
    YSU_LLM_MODEL="auto"
    _YSU_LLM_RESOLVED_MODEL="llama3"
    echo "$(_ysu_get_effective_model)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "llama3" ]]
}

@test "bash: get_effective_model returns specific model" {
  run_bash '
    YSU_LLM_MODEL="gpt-4"
    echo "$(_ysu_get_effective_model)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "gpt-4" ]]
}

@test "bash: sudo alias suggestion works" {
  run_bash '
    alias please="sudo"
    _ysu_check_sudo_alias "apt-get update"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"please"* ]]
  [[ "$output" == *"sudo"* ]]
}
