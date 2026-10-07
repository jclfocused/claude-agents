#!/usr/bin/env bash
# SessionEnd: append one TSV line (date, session_id, cwd-basename, git branch,
# reserved) to ~/.claude/session-index/<cwd-basename>.tsv.
set -uo pipefail

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
# LFOS loop guard: a session spawned by the memory pipeline (distill.sh / the
# state.md updater export LFOS_MEM_RUNNER=1) must not trigger a state.md refresh.
[ "${LFOS_MEM_RUNNER:-}" = "1" ] || lfos_emit session-index "$input"
sid=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null) || sid=unknown
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || cwd=""
[ -z "$cwd" ] && cwd=$PWD
base=$(basename "$cwd")
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

dir="${CLAUDE_SESSION_INDEX_DIR:-$HOME/.claude/session-index}"
mkdir -p "$dir"
printf '%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$sid" "$base" "$branch" "" >> "$dir/$base.tsv"
exit 0
