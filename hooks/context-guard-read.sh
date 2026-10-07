#!/usr/bin/env bash
# PreToolUse guard: Read of a large text file without offset/limit is denied everywhere
# (main session and subagents). 40 KB whole-file reads and >250-line slices are denied (tightened 2026-09-11 after a context blow-up).
# Images and PDFs are exempt (the tool renders them). Added 2026-09-03.
input=$(cat)
fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
lim=$(printf '%s' "$input" | jq -r '.tool_input.limit // ""')
[ -z "$fp" ] && exit 0
if [ -n "$lim" ]; then [ "$lim" -le 250 ] 2>/dev/null && exit 0; jq -n --arg r "Read blocked: limit=$lim lines. Cap a Read at 250 lines; take several slices or grep for the part you need." '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0; fi
[ -f "$fp" ] || exit 0
case "${fp,,}" in *.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf|*.ipynb) exit 0 ;; esac
sz=$(stat -c %s "$fp" 2>/dev/null || echo 0)
max=${CLAUDE_READ_MAX_BYTES:-40000}
[ "$sz" -le "$max" ] && exit 0
kb=$((sz/1024))
reason="Read blocked: $fp is ${kb} KB. Reading it whole would overload the context. Pass offset/limit for a slice, grep/sed the part you need, or delegate to a subagent that returns a summary."
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
