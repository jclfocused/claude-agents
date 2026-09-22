#!/usr/bin/env bash
# Read-only probe: is the Jev key on this box valid, and does one Noul answer?
# Never prints the key. Usage: jev-probe.sh [state-text]
set -euo pipefail
set -a; . "${JEV_ENV_FILE:-$HOME/.config/jev/jev.env}"; set +a
: "${JEV_API_KEY:?JEV_API_KEY not set — see secrets-intake skill}"
API=${TYPESAFE_BASE_URL:-https://api.typesafe.ai}
TEXT=${1:-"The meeting is on Friday"}

echo "key: set (len ${#JEV_API_KEY})"
curl -sS -o /tmp/jev-models.$$ -w 'GET /v1/models -> %{http_code} in %{time_total}s\n' \
  -H "Authorization: Bearer $JEV_API_KEY" "$API/v1/models"
jq -c '[.models[].name]' /tmp/jev-models.$$; rm -f /tmp/jev-models.$$

BODY=$(jq -cn --arg t "$TEXT" '{state:{text:$t},model:"jev-latest",questions:{mentions_day:{type:"noul",instructions:"Does the text mention a day of the week?"}}}')
curl -sS -o /tmp/jev-one.$$ -w 'POST /v1/systemone -> %{http_code} in %{time_total}s\n' \
  -H "Authorization: Bearer $JEV_API_KEY" -H 'Content-Type: application/json' \
  -d "$BODY" "$API/v1/systemone"
jq -c '{model, noul:.answers.mentions_day.noul, usage}' /tmp/jev-one.$$; rm -f /tmp/jev-one.$$
