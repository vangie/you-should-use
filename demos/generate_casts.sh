#!/usr/bin/env bash
# Generate asciicast v2 files for README demos
# Each .cast file is a JSON header + newline-delimited event lines

DEMOS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Helper: write a typing sequence
# Args: file, start_time, text
# Returns: end time via global var CURSOR
type_chars() {
  local file="$1" t="$2" text="$3"
  CURSOR="$t"
  for (( i=0; i<${#text}; i++ )); do
    local ch="${text:$i:1}"
    # Escape special JSON chars
    case "$ch" in
      '"') ch='\\"' ;;
      '\\') ch='\\\\' ;;
      $'\t') ch='\\t' ;;
    esac
    printf '[%.3f, "o", "%s"]\n' "$CURSOR" "$ch" >> "$file"
    CURSOR=$(echo "$CURSOR + 0.06 + ($RANDOM % 40) * 0.001" | bc)
  done
}

# Helper: write output line
write_output() {
  local file="$1" t="$2" text="$3"
  # Escape for JSON
  text=$(echo "$text" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '[%.3f, "o", "%s\\r\\n"]\n' "$t" "$text" >> "$file"
}

# Helper: write raw output (already escaped)
write_raw() {
  local file="$1" t="$2" text="$3"
  printf '[%.3f, "o", "%s\\r\\n"]\n' "$t" "$text" >> "$file"
}

write_prompt() {
  local file="$1" t="$2"
  printf '[%.3f, "o", "\\u001b[1;32m❯\\u001b[0m "]\n' "$t" >> "$file"
}

# ============================================================================
# Demo 1: Alias Reminders
# ============================================================================
CAST="$DEMOS_DIR/alias-reminders.cast"
cat > "$CAST" << 'EOF'
{"version": 2, "width": 72, "height": 14, "env": {"TERM": "xterm-256color", "SHELL": "/bin/zsh"}, "title": "you-should-use: Alias Reminders"}
EOF

T=0.5
write_prompt "$CAST" "$T"
T=$(echo "$T + 0.3" | bc)
type_chars "$CAST" "$T" "git status"
T=$(echo "$CURSOR + 0.3" | bc)
printf '[%.3f, "o", "\\r\\n"]\n' "$T" >> "$CAST"

# Show git status output (abbreviated)
T=$(echo "$T + 0.2" | bc)
write_output "$CAST" "$T" "On branch main"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "nothing to commit, working tree clean"

# Show the plugin reminder
T=$(echo "$T + 0.1" | bc)
write_raw "$CAST" "$T" "💡 \\u001b[1;93m➜\\u001b[0m You should use \\u001b[1;31mgst\\u001b[0m instead of \\u001b[1;36mgit status\\u001b[0m"

# Second command
T=$(echo "$T + 1.5" | bc)
write_prompt "$CAST" "$T"
T=$(echo "$T + 0.3" | bc)
type_chars "$CAST" "$T" "git log --oneline -5"
T=$(echo "$CURSOR + 0.3" | bc)
printf '[%.3f, "o", "\\r\\n"]\n' "$T" >> "$CAST"

T=$(echo "$T + 0.2" | bc)
write_output "$CAST" "$T" "dda5a7a Fix fish syntax error"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "d32eff6 Use friendly tone for missing config"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "b4eed40 Fix Ollama auto-detection"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "b00551f Add auto model selection"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "a802cc6 Add ysu status subcommand"

T=$(echo "$T + 0.1" | bc)
write_raw "$CAST" "$T" "💡 \\u001b[1;93m➜\\u001b[0m You should use \\u001b[1;31mglol\\u001b[0m instead of \\u001b[1;36mgit log --oneline\\u001b[0m"

# Third command
T=$(echo "$T + 1.5" | bc)
write_prompt "$CAST" "$T"
T=$(echo "$T + 0.3" | bc)
type_chars "$CAST" "$T" "git diff"
T=$(echo "$CURSOR + 0.3" | bc)
printf '[%.3f, "o", "\\r\\n"]\n' "$T" >> "$CAST"

T=$(echo "$T + 0.2" | bc)
write_raw "$CAST" "$T" "💡 \\u001b[1;93m➜\\u001b[0m You should use \\u001b[1;31mgd\\u001b[0m instead of \\u001b[1;36mgit diff\\u001b[0m"

T=$(echo "$T + 1.5" | bc)
write_prompt "$CAST" "$T"

# ============================================================================
# Demo 2: Modern Tool Suggestions
# ============================================================================
CAST="$DEMOS_DIR/modern-suggestions.cast"
cat > "$CAST" << 'EOF'
{"version": 2, "width": 80, "height": 16, "env": {"TERM": "xterm-256color", "SHELL": "/bin/zsh"}, "title": "you-should-use: Modern Tool Suggestions"}
EOF

T=0.5
write_prompt "$CAST" "$T"
T=$(echo "$T + 0.3" | bc)
type_chars "$CAST" "$T" "cat README.md"
T=$(echo "$CURSOR + 0.3" | bc)
printf '[%.3f, "o", "\\r\\n"]\n' "$T" >> "$CAST"

T=$(echo "$T + 0.2" | bc)
write_output "$CAST" "$T" "# you-should-use"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" ""
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "A shell plugin that helps you work smarter..."

T=$(echo "$T + 0.1" | bc)
write_raw "$CAST" "$T" "💡 \\u001b[1;93m➜\\u001b[0m You should use \\u001b[1;31mbat\\u001b[0m instead of \\u001b[1;36mcat\\u001b[0m — \\u001b[3mSyntax highlighting, line numbers, git integration\\u001b[0m"

T=$(echo "$T + 1.5" | bc)
write_prompt "$CAST" "$T"
T=$(echo "$T + 0.3" | bc)
type_chars "$CAST" "$T" "find . -name '*.zsh'"
T=$(echo "$CURSOR + 0.3" | bc)
printf '[%.3f, "o", "\\r\\n"]\n' "$T" >> "$CAST"

T=$(echo "$T + 0.2" | bc)
write_output "$CAST" "$T" "./you-should-use.plugin.zsh"

T=$(echo "$T + 0.1" | bc)
write_raw "$CAST" "$T" "💡 \\u001b[1;93m➜\\u001b[0m You should use \\u001b[1;31mfd\\u001b[0m instead of \\u001b[1;36mfind\\u001b[0m — \\u001b[3mSimpler syntax, faster, respects .gitignore\\u001b[0m"

T=$(echo "$T + 1.5" | bc)
write_prompt "$CAST" "$T"
T=$(echo "$T + 0.3" | bc)
type_chars "$CAST" "$T" "ls -la"
T=$(echo "$CURSOR + 0.3" | bc)
printf '[%.3f, "o", "\\r\\n"]\n' "$T" >> "$CAST"

T=$(echo "$T + 0.2" | bc)
write_output "$CAST" "$T" "total 48"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "drwxr-xr-x  12 user  staff   384 Mar 28 08:00 ."
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "-rw-r--r--   1 user  staff  1080 Mar 28 08:00 LICENSE"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "-rw-r--r--   1 user  staff  4271 Mar 28 08:00 README.md"

T=$(echo "$T + 0.1" | bc)
write_raw "$CAST" "$T" "💡 \\u001b[1;93m➜\\u001b[0m You should use \\u001b[1;31meza\\u001b[0m instead of \\u001b[1;36mls\\u001b[0m — \\u001b[3mModern file listing with icons, git status, tree view\\u001b[0m"

T=$(echo "$T + 1.5" | bc)
write_prompt "$CAST" "$T"

# ============================================================================
# Demo 3: ysu status
# ============================================================================
CAST="$DEMOS_DIR/ysu-status.cast"
cat > "$CAST" << 'EOF'
{"version": 2, "width": 72, "height": 28, "env": {"TERM": "xterm-256color", "SHELL": "/bin/zsh"}, "title": "you-should-use: Status Dashboard"}
EOF

T=0.5
write_prompt "$CAST" "$T"
T=$(echo "$T + 0.3" | bc)
type_chars "$CAST" "$T" "ysu status"
T=$(echo "$CURSOR + 0.3" | bc)
printf '[%.3f, "o", "\\r\\n"]\n' "$T" >> "$CAST"

T=$(echo "$T + 0.2" | bc)
write_output "$CAST" "$T" ""
T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "\\u001b[1m📊 you-should-use status\\u001b[0m"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "─────────────────────────"

T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "\\u001b[1mCore Settings:\\u001b[0m"
T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "  \\u001b[32m✓\\u001b[0m Alias Reminders:    \\u001b[32m✓\\u001b[0m enabled"
T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "  \\u001b[32m✓\\u001b[0m Modern Suggestions: \\u001b[32m✓\\u001b[0m enabled"
T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "  Prefix:             \\\"💡\\\""
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "  Probability:        100%"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "  Cooldown:           0s"

T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" ""
T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "\\u001b[1mLLM Settings:\\u001b[0m"
T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "  Enabled:            \\u001b[32m✓\\u001b[0m enabled (auto-detected Ollama)"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "  API URL:            http://localhost:11434/v1"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "  Model:              auto (llama3.1:8b)"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "  API Key:            (not set)"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "  Cache:              12 entries"

T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" ""
T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "\\u001b[1mStatistics:\\u001b[0m"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "  Aliases defined:    142"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "  Modern mappings:    14"

T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" ""
T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "\\u001b[1mConfig File:\\u001b[0m"
T=$(echo "$T + 0.05" | bc)
write_raw "$CAST" "$T" "  \\u001b[32m✓\\u001b[0m ~/.config/ysu/config.zsh"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" ""

T=$(echo "$T + 2.0" | bc)
write_prompt "$CAST" "$T"

# ============================================================================
# Demo 4: LLM Suggestions
# ============================================================================
CAST="$DEMOS_DIR/llm-suggestions.cast"
cat > "$CAST" << 'EOF'
{"version": 2, "width": 80, "height": 16, "env": {"TERM": "xterm-256color", "SHELL": "/bin/zsh"}, "title": "you-should-use: AI-Powered Suggestions"}
EOF

T=0.5
write_prompt "$CAST" "$T"
T=$(echo "$T + 0.3" | bc)
type_chars "$CAST" "$T" "grep -r 'TODO' src/ | sort | head -10"
T=$(echo "$CURSOR + 0.3" | bc)
printf '[%.3f, "o", "\\r\\n"]\n' "$T" >> "$CAST"

T=$(echo "$T + 0.2" | bc)
write_output "$CAST" "$T" "src/main.js:  // TODO: refactor auth logic"
T=$(echo "$T + 0.05" | bc)
write_output "$CAST" "$T" "src/utils.js: // TODO: add input validation"

T=$(echo "$T + 0.1" | bc)
write_raw "$CAST" "$T" "💡 \\u001b[1;93m➜\\u001b[0m You should use \\u001b[1;31mrg\\u001b[0m instead of \\u001b[1;36mgrep\\u001b[0m — \\u001b[3mRipgrep - faster, respects .gitignore\\u001b[0m"

T=$(echo "$T + 0.8" | bc)
write_raw "$CAST" "$T" "🤖 \\u001b[1;93m➜\\u001b[0m \\u001b[1;33mrg TODO src/ | sort | head -10\\u001b[0m — rg is faster and ignores .gitignore entries by default"

T=$(echo "$T + 2.0" | bc)
write_prompt "$CAST" "$T"
T=$(echo "$T + 0.3" | bc)
type_chars "$CAST" "$T" "find . -name '*.log' -mtime +7 -delete"
T=$(echo "$CURSOR + 0.3" | bc)
printf '[%.3f, "o", "\\r\\n"]\n' "$T" >> "$CAST"

T=$(echo "$T + 0.1" | bc)
write_raw "$CAST" "$T" "💡 \\u001b[1;93m➜\\u001b[0m You should use \\u001b[1;31mfd\\u001b[0m instead of \\u001b[1;36mfind\\u001b[0m — \\u001b[3mSimpler syntax, faster, respects .gitignore\\u001b[0m"

T=$(echo "$T + 0.8" | bc)
write_raw "$CAST" "$T" "🤖 \\u001b[1;93m➜\\u001b[0m \\u001b[1;33mfd -e log --changed-before 7d -x rm\\u001b[0m — fd uses simpler syntax and is much faster"

T=$(echo "$T + 2.0" | bc)
write_prompt "$CAST" "$T"

echo "Generated all 4 cast files in $DEMOS_DIR"
