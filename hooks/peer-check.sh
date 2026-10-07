#!/usr/bin/env bash
# SessionStart: warn if another live Claude Code session shares this repo.
# Silent when the session is alone. Fail-open and fast (<~300ms); stdout becomes
# session context. Detection logic lives in the LFOS repo (peer-check.mjs) —
# pure git + /proc, no collector/DB dependency.
NODE=/home/justin/.nvm/versions/node/v22.22.2/bin/node
PEER=/home/justin/ops/infra/peers/peer-check.mjs
input=$(cat 2>/dev/null || true)
[ -x "$NODE" ] && [ -f "$PEER" ] || exit 0
printf '%s' "$input" | timeout 3s "$NODE" "$PEER" --hook 2>/dev/null || true
exit 0
