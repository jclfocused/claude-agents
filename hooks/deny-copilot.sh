#!/usr/bin/env bash
# PreToolUse(mcp__.*request_copilot_review): always deny.

# ---- LFOS emitter (fire-and-forget; must NEVER affect this hook) ----------
# Posts this hook's stdin JSON to the local LFOS collector (127.0.0.1:7311),
# adding lfos_event + source/kind (the collector's /event requires them) and
# raw (original payload). Fail-open: jq/curl missing or collector down is a
# silent no-op. Writes NOTHING to this hook's stdout/stderr and never changes
# its exit code or latency budget.
lfos_emit() {
  _lfos_payload=${2-}
  [ -n "$_lfos_payload" ] || return 0
  command -v curl >/dev/null 2>&1 || return 0
  if command -v jq >/dev/null 2>&1; then
    _lfos_decorated=$(printf '%s' "$_lfos_payload" | jq -c --arg e "$1" \
      '. + {lfos_event: $e, source: "claude-hook", kind: ("hook." + $e), raw: (. | tostring)}' 2>/dev/null) \
      && [ -n "$_lfos_decorated" ] && _lfos_payload=$_lfos_decorated
  fi
  ( { printf '%s' "$_lfos_payload" | curl -s -m 0.2 -X POST http://127.0.0.1:7311/event \
        -H 'content-type: application/json' --data-binary @- ; } </dev/null >/dev/null 2>&1 & )
  return 0
}

input=$(cat)
lfos_emit deny-copilot "$input"
echo "BLOCKED: Copilot reviews are forbidden (global CLAUDE.md: never call request_copilot_review or any GitHub Copilot review tool)." >&2
exit 2
