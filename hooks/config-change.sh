#!/usr/bin/env bash
# PostToolUse (Edit|Write): audit-trail for Claude Code control-surface edits.
# If the written path is a config that changes agent behavior — global
# ~/.claude/settings.json / settings.local.json, any project .claude/settings*.json,
# any .mcp.json, or anything under ~/.claude/hooks/ — emit a `config_change`
# event to the LFOS collector (127.0.0.1:7311).
#
# Same contract as every LFOS emitter: fire-and-forget (curl -m 0.2,
# backgrounded, fds detached), fail-open when jq/curl are missing or the
# collector is down, writes NOTHING to stdout/stderr, always exits 0 — this
# hook must never block or alter the Edit/Write it observes.
#
# Deliberately EXCLUDED from the event: tool_input.content / new_string
# (an .mcp.json can carry tokens; file bodies must not land in the ledger).
set -uo pipefail

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || fp=""
[ -n "$fp" ] || exit 0

case "$fp" in
  "$HOME/.claude/settings.json") kind_hint="global-settings" ;;
  "$HOME/.claude/settings.local.json") kind_hint="global-settings" ;;
  "$HOME/.claude/hooks/"*) kind_hint="hook-script" ;;
  */.claude/settings.json|*/.claude/settings.local.json) kind_hint="project-settings" ;;
  */.mcp.json|.mcp.json) kind_hint="mcp-config" ;;
  *) exit 0 ;;
esac

payload=$(printf '%s' "$input" | jq -c --arg fp "$fp" --arg hint "$kind_hint" '{
  source: "claude-hook",
  kind: "config_change",
  severity: "warn",
  session_id: (.session_id // null),
  title: ("config change: " + $fp + " via " + (.tool_name // "unknown")),
  body: ("surface: " + $hint + "  cwd: " + (.cwd // "?")),
  raw: ({session_id: .session_id, cwd: .cwd, tool_name: .tool_name, file_path: $fp, surface: $hint} | tostring)
}' 2>/dev/null) || exit 0
[ -n "$payload" ] || exit 0

( { printf '%s' "$payload" | curl -s -m 0.2 -X POST http://127.0.0.1:7311/event \
      -H 'content-type: application/json' --data-binary @- ; } </dev/null >/dev/null 2>&1 & )
exit 0
