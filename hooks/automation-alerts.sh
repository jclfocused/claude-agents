#!/usr/bin/env bash
# SessionStart: surface automation alerts from the last 24h as context.
# Silent and fast (<100ms) when there is nothing to report.
# Alert log format, current: iso<TAB>message (all ~/.claude/automation/* writers).
# Legacy/other writers (some ~/ops/infra watchdogs) still emit epoch<TAB>iso<TAB>message,
# so the 24h filter below parses both shapes and prints iso<TAB>message either way.

# ---- LFOS emitter (fire-and-forget; must NEVER affect this hook) ----------
# Posts this hook's stdin JSON to the local LFOS collector (127.0.0.1:7311),
# adding lfos_event + source/kind (the collector's /event requires them) and
# raw (original payload). Fail-open: jq/curl missing or collector down is a
# silent no-op. Writes NOTHING to this hook's stdout/stderr (stdout becomes
# session context here) and never changes its exit code or latency budget.
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

# This hook never consumed stdin before LFOS; capture it (hooks always pipe
# JSON on stdin) solely for the emitter. `|| true` keeps any read hiccup from
# changing behavior.
input=$(cat 2>/dev/null || true)
lfos_emit automation-alerts "$input"

log="${ALERTS_LOG:-$HOME/.claude/automation/logs/alerts.log}"
[ -s "$log" ] || exit 0
cut=$(( $(date +%s) - 86400 ))
# Count + the 3 newest lines (about -1k tokens per session start); the log keeps the rest.
recent=$(awk -F'\t' -v cut="$cut" -v shown="${log/#$HOME/\~}" '
  function toepoch(s,   y,mo,d,h,mi,se,t,sign,oh,om) {
    if (s ~ /^[0-9]+$/) return s + 0                     # legacy epoch-first line
    if (s !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}T/) return -1   # not a timestamp: drop
    y=substr(s,1,4); mo=substr(s,6,2); d=substr(s,9,2)
    h=substr(s,12,2); mi=substr(s,15,2); se=substr(s,18,2)
    t = mktime(y" "mo" "d" "h" "mi" "se" 0", 1)          # gawk: parse as UTC
    if (match(s, /[+-][0-9][0-9]:[0-9][0-9]$/)) {        # then back out a stated offset
      sign = (substr(s, RSTART, 1) == "-") ? -1 : 1
      oh = substr(s, RSTART + 1, 2) + 0; om = substr(s, RSTART + 4, 2) + 0
      t -= sign * (oh * 3600 + om * 60)
    }
    return t
  }
  { if (toepoch($1) < cut) next
    n = ($1 ~ /^[0-9]+$/) ? 2 : 1                        # first field of iso<TAB>message
    out = $n; for (i = n + 1; i <= NF; i++) out = out "\t" $i
    last[++c % 3] = out }
  END { if (!c) exit
    printf "Automation alerts: %d in the last 24h; newest %d below. Full list: %s\n", c, (c < 3 ? c : 3), shown
    for (k = (c > 3 ? c - 2 : 1); k <= c; k++) print last[k % 3] }
' "$log" 2>/dev/null)
[ -z "$recent" ] && exit 0
printf '%s\n' "$recent"
exit 0
