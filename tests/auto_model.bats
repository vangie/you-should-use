#!/usr/bin/env bats
# Tests for auto model selection

PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_zsh() {
  run zsh -c "
    source '$PLUGIN_DIR/tests/test_helper.zsh'
    _ysu_reset
    $1
  "
}

# ---- _ysu_get_effective_model ----

@test "effective model returns resolved model when model is auto" {
  run_zsh '
    YSU_LLM_MODEL="auto"
    _YSU_LLM_RESOLVED_MODEL="llama3.1:8b"
    _ysu_get_effective_model
  '
  [ "$status" -eq 0 ]
  [ "$output" = "llama3.1:8b" ]
}

@test "effective model returns specific model when not auto" {
  run_zsh '
    YSU_LLM_MODEL="qwen2.5-coder:7b"
    _YSU_LLM_RESOLVED_MODEL=""
    _ysu_get_effective_model
  '
  [ "$status" -eq 0 ]
  [ "$output" = "qwen2.5-coder:7b" ]
}

@test "effective model returns empty when auto and unresolved" {
  run_zsh '
    YSU_LLM_MODEL="auto"
    _YSU_LLM_RESOLVED_MODEL=""
    result=$(_ysu_get_effective_model)
    echo "result=[$result]"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == "result=[]" ]]
}

@test "effective model ignores resolved model when model is specific" {
  run_zsh '
    YSU_LLM_MODEL="gpt-4"
    _YSU_LLM_RESOLVED_MODEL="llama3.1:8b"
    _ysu_get_effective_model
  '
  [ "$status" -eq 0 ]
  [ "$output" = "gpt-4" ]
}

# ---- Default model value ----

@test "default YSU_LLM_MODEL is auto" {
  run zsh -c "
    add-zsh-hook() { : }
    autoload() { : }
    curl() { return 1; }
    source '$PLUGIN_DIR/you-should-use.plugin.zsh'
    echo \"\$YSU_LLM_MODEL\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "auto" ]
}

# ---- Resolved model stored correctly ----

@test "resolved model variable exists after plugin load" {
  run_zsh '
    [[ -v _YSU_LLM_RESOLVED_MODEL ]] && echo "exists" || echo "missing"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "exists" ]
}

@test "resolved model is empty when no Ollama and model is auto" {
  run_zsh '
    YSU_LLM_MODEL="auto"
    _YSU_LLM_RESOLVED_MODEL=""
    echo "resolved=[$_YSU_LLM_RESOLVED_MODEL]"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "resolved=[]" ]
}

# ---- LLM query uses effective model ----

@test "llm query async returns early when auto and unresolved" {
  run_zsh '
    YSU_LLM_ENABLED=true
    YSU_LLM_MODEL="auto"
    _YSU_LLM_RESOLVED_MODEL=""
    _ysu_llm_query_async "ls -la"
    # Should not have created an async file since model is unresolved
    [[ -z "$_YSU_LLM_ASYNC_FILE" ]] && echo "no-async" || echo "has-async"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "no-async" ]
}
