#!/usr/bin/env bash
# PreCompact: post the compaction event to the LFOS collector, which refreshes
# the project's state.md from it. Prints nothing: Claude Code ignores a top-level
# additionalContext on PreCompact and rejects hookSpecificOutput for it (debug
# log, 2.1.291, 2026-10-07), so the old memory reminder never reached the model.

# ---- LFOS emitter (fire-and-forget; must NEVER affect this hook) ----------
# Posts this hook's stdin JSON to the local LFOS collector (127.0.0.1:7311),
# adding lfos_event + source/kind (the collector's /event requires them) and
# raw (original payload). Fail-open: jq/curl missing or collector down is a
# silent no-op. Writes NOTHING to this hook's stdout/stderr (stdout purity is
# essential here — this hook returns JSON) and never changes its exit code or
# latency budget.
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
# LFOS loop guard (symmetric with session-index.sh): a memory-pipeline session
# (distill.sh exports LFOS_MEM_RUNNER=1) must not trigger a state.md refresh.
[ "${LFOS_MEM_RUNNER:-}" = "1" ] || lfos_emit precompact-reminder "$input"
exit 0
