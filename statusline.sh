#!/bin/bash
# Claude Code custom status line
# Receives JSON context via stdin
# ponytail: one jq fork (was 8), no bc, git only inside a branch; same visible output.

input=$(cat)

# --- Extract data from JSON (one jq call, one NUL-terminated value per field) ---
{
  IFS= read -r -d '' MODEL
  IFS= read -r -d '' CURRENT_DIR
  IFS= read -r -d '' CW_INPUT
  IFS= read -r -d '' CW_OUTPUT
  IFS= read -r -d '' CW_CACHE_CREATE
  IFS= read -r -d '' CW_CACHE_READ
  IFS= read -r -d '' CTX_PCT
} < <(printf '%s\n' "$input" | jq --raw-output0 '
  (.model.display_name // "unknown"),
  (.workspace.current_dir // ""),
  (.context_window.current_usage.input_tokens // 0),
  (.context_window.current_usage.output_tokens // 0),
  (.context_window.current_usage.cache_creation_input_tokens // 0),
  (.context_window.current_usage.cache_read_input_tokens // 0),
  (.context_window.used_percentage // 0)' 2>/dev/null)
DIR_NAME="${CURRENT_DIR##*/}"

# Total tokens used
CTX_USED=$(( CW_INPUT + CW_OUTPUT + CW_CACHE_CREATE + CW_CACHE_READ ))

# Format token count (e.g. 39200 -> 39.2k, 1500000 -> 1.5M); truncates like bc scale=1
format_tokens() {
  local tokens=$1
  if [ "$tokens" -ge 1000000 ] 2>/dev/null; then
    printf "%.1fM" "$(( tokens / 1000000 )).$(( tokens % 1000000 / 100000 ))"
  elif [ "$tokens" -ge 1000 ] 2>/dev/null; then
    printf "%.1fk" "$(( tokens / 1000 )).$(( tokens % 1000 / 100 ))"
  else
    echo "$tokens"
  fi
}

CTX_DISPLAY=$(format_tokens "$CTX_USED")

# --- Git info (the count only shows next to a branch name) ---
UNCOMMITTED_COUNT=0
GIT_BRANCH=$(git branch --show-current 2>/dev/null)
if [ -n "$GIT_BRANCH" ]; then
  UNCOMMITTED_COUNT=$(git status --porcelain 2>/dev/null | wc -l)
  UNCOMMITTED_COUNT=${UNCOMMITTED_COUNT//[[:space:]]/}
fi

# --- ANSI Colors ---
RESET="\033[0m"
GRAY="\033[38;5;245m"
WHITE="\033[38;5;255m"
GREEN="\033[38;5;114m"
YELLOW="\033[38;5;222m"
RED="\033[38;5;204m"
CYAN="\033[38;5;116m"

# --- Build status line ---
parts=()

# Model
parts+=("${WHITE}${MODEL}${RESET}")

# Context: tokens + percentage
parts+=("${CYAN}${CTX_DISPLAY}${GRAY} (${CTX_PCT}%)${RESET}")

# Current directory
if [ -n "$DIR_NAME" ]; then
  parts+=("${YELLOW}${DIR_NAME}${RESET}")
fi

# Git branch + uncommitted count
if [ -n "$GIT_BRANCH" ]; then
  git_part="${GREEN}${GIT_BRANCH}${RESET}"
  if [ "$UNCOMMITTED_COUNT" -gt 0 ] 2>/dev/null; then
    git_part="${git_part} ${RED}[${UNCOMMITTED_COUNT}]${RESET}"
  fi
  parts+=("$git_part")
fi

# Join with separator
SEP="${GRAY} | ${RESET}"
output=""
for i in "${!parts[@]}"; do
  if [ "$i" -gt 0 ]; then
    output="${output}${SEP}"
  fi
  output="${output}${parts[$i]}"
done

echo -e "$output"
