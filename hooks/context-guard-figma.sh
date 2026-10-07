#!/usr/bin/env bash
# PreToolUse guard: large Figma reads (get_metadata / get_design_context) stay out of the
# orchestrator's context. Allowed inside subagents/workflow lanes (their transcript lives
# under .../subagents/); denied in the main session with a pointer to delegate.
# Added 2026-09-03 after a Figma read overloaded a Fable session (Justin: fill the gap).
input=$(cat)
tp=$(printf '%s' "$input" | jq -r '.transcript_path // ""')
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')
case "$tp" in
  */subagents/*) exit 0 ;;
esac
reason="$tool is blocked in the main session: its output is large and lands in the orchestrator context. Delegate this read to a subagent (Opus lane) that writes a compact summary to a file, or use get_screenshot (URL only) / a use_figma script that returns under 2 KB."
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
