#!/usr/bin/env bash
# PostToolUse(Write|Edit) guard: memory files must stay lean.
# A bloated auto-recalled memory file both wastes context every session and can
# trip content classifiers. When a just-written memory file exceeds budget, emit
# a non-blocking nudge to compact it (keep a lean summary; move detail to a repo
# log / docs). Advisory only — never blocks the write.
set -euo pipefail

INPUT="$(cat)"
FP="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
[ -n "$FP" ] || exit 0

# Only guard auto-recalled memory markdown.
case "$FP" in
  */.claude/projects/*/memory/*.md) : ;;
  *) exit 0 ;;
esac
[ -f "$FP" ] || exit 0
# MEMORY.md is the index — held to a tighter line budget; others by size+lines.
BASE="$(basename "$FP")"
LINES="$(wc -l < "$FP" 2>/dev/null || echo 0)"
BYTES="$(wc -c < "$FP" 2>/dev/null || echo 0)"

MAX_LINES=200
MAX_BYTES=9000
[ "$BASE" = "MEMORY.md" ] && MAX_LINES=60 && MAX_BYTES=6000

if [ "$LINES" -gt "$MAX_LINES" ] || [ "$BYTES" -gt "$MAX_BYTES" ]; then
  MSG="Memory file $BASE is ${LINES} lines / ${BYTES} bytes (budget ${MAX_LINES} lines / ${MAX_BYTES} bytes). It is auto-recalled every session — compact it now: keep a lean current-state summary + [[links]], move detailed history to the project's repo (git log / docs/) which is NOT auto-recalled. Neutral factual phrasing only."
  jq -cn --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}' 2>/dev/null \
    || printf '%s\n' "$MSG" >&2
fi
exit 0
