#!/usr/bin/env bash
# SessionStart + UserPromptSubmit: when the balancer has raised fleet-wide
# usage conservation (flag file written by the ops collector), tell the session
# to work in credit-saver mode. File check only — fast, no network, fail-open.
set -uo pipefail

FLAG="$HOME/.claude/automation/state/conserve-mode.json"
[ -f "$FLAG" ] || exit 0
# Per-session override (Justin, 2026-09-30): a file named after the session id in conserve-override/ silences this
# session only. Same directory the no-anthropic-api.sh Fable gate reads.
input=$(cat 2>/dev/null || true)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] && [ -f "$HOME/.claude/automation/state/conserve-override/$sid" ] && exit 0
# Headless seats launched by an overridden session's work carry the override in their environment.
[ "${LFOS_CONSERVE_OVERRIDE:-}" = 1 ] && exit 0

pct=""
if command -v jq >/dev/null 2>&1; then
  pct=$(jq -r '.minWeeklyPct // empty' "$FLAG" 2>/dev/null)
fi

echo "CONSERVATION MODE ACTIVE — fleet-wide weekly usage is near its cap${pct:+ (best remaining account at ${pct}% weekly)}. Load ~/.claude/skills/credit-saver/SKILL.md and follow it for this session: ship the essential work with minimum viable verification, no exploratory fan-outs or wide agent fleets, prefer cheap targeted checks, and write down anything skipped for a later verification pass. Moving slower is the intended trade — the alternative is a hard usage block."
exit 0
