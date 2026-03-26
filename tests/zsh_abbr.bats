#!/usr/bin/env bats
# Tests for zsh-abbr compatibility

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

@test "zsh-abbr: detects regular user abbreviation" {
  run_zsh '
    typeset -gA ABBR_REGULAR_USER_ABBREVIATIONS
    ABBR_REGULAR_USER_ABBREVIATIONS=(g "git")
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"g"* ]]
  [[ "$output" == *"git"* ]]
}

@test "zsh-abbr: detects global user abbreviation" {
  run_zsh '
    typeset -gA ABBR_GLOBAL_USER_ABBREVIATIONS
    ABBR_GLOBAL_USER_ABBREVIATIONS=(NUL "/dev/null")
    _ysu_check_aliases "cat foo > /dev/null"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"NUL"* ]]
}

@test "zsh-abbr: no match when user already types abbreviation" {
  run_zsh '
    typeset -gA ABBR_REGULAR_USER_ABBREVIATIONS
    ABBR_REGULAR_USER_ABBREVIATIONS=(g "git")
    _ysu_check_aliases "g status"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "zsh-abbr: ignored abbreviations are skipped" {
  run_zsh '
    typeset -gA ABBR_REGULAR_USER_ABBREVIATIONS
    ABBR_REGULAR_USER_ABBREVIATIONS=(g "git")
    YSU_IGNORE_ALIASES="g"
    _ysu_check_aliases "git status"
    echo "count=$(_ysu_message_count)"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=0"* ]]
}

@test "zsh-abbr: prefers more specific match over alias" {
  run_zsh '
    alias g="git"
    typeset -gA ABBR_REGULAR_USER_ABBREVIATIONS
    ABBR_REGULAR_USER_ABBREVIATIONS=(gs "git status")
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"gs"* ]]
}

@test "zsh-abbr: no error when zsh-abbr not loaded" {
  run_zsh '
    # Do NOT set ABBR_REGULAR_USER_ABBREVIATIONS
    alias g="git"
    _ysu_check_aliases "git status"
    _ysu_get_messages
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"g"* ]]
}
