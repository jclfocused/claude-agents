#!/usr/bin/env bash
# PreToolUse guard (Grep tool): content output must be capped. Added 2026-09-11.
input=$(cat)
mode=$(printf '%s' "$input" | jq -r '.tool_input.output_mode // "files_with_matches"')
lim=$(printf '%s' "$input" | jq -r '.tool_input.head_limit // ""')
ctx=$(printf '%s' "$input" | jq -r '[.tool_input["-C"] // 0, .tool_input["-A"] // 0, .tool_input["-B"] // 0] | max')
deny() { jq -n --arg r "Grep blocked (context guard): $1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0; }
if [ "$mode" = "content" ]; then
  [ -z "$lim" ] && deny "content mode needs head_limit (≤ 120)."
  [ "$lim" -gt 120 ] 2>/dev/null && deny "head_limit=$lim is too big for content mode — use ≤ 120, or files_with_matches first."
  [ "${ctx:-0}" -gt 8 ] 2>/dev/null && deny "context lines (-A/-B/-C) > 8 — narrow the pattern instead."
else
  [ -n "$lim" ] && [ "$lim" -gt 400 ] 2>/dev/null && deny "head_limit=$lim — cap file lists at 400."
fi
exit 0
