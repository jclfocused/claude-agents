---
name: verify-observability
description: Prove the observability wiring actually works before claiming done — the replay-gate unit test, redaction/scrub assertions, a pino-stream check on dev (the dev stack never reaches Loki), a Sentry read-back after a deliberate capture, and the /health body shape. Use before committing or shipping any change that touched logging, error capture, analytics, a health endpoint, an Alloy file or a dashboard; when a lane must produce "proof" for the observability definition of done; when someone claims telemetry is wired without an event id; and as the observability arm of a pre-deploy or post-deploy verify. Pairs with deploy-verify / sandbox-verify — this one only covers observability.
---

# verify-observability

A gate that cannot fail is not a gate. Three arms; run 1 and 2 always, arm 3 only in prod-verify mode.

## Arm 1 — grep the diff for the anti-patterns

```sh
D=$(git diff --name-only origin/main...HEAD -- '*.ts' '*.tsx' '*.kt' '*.swift')
git diff origin/main...HEAD -- $D | grep -nE '^\+.*console\.(log|warn|error|info)'    # bare console
git diff origin/main...HEAD -- $D | grep -nE '^\+.*catch\s*\{\s*\}'                    # silent catch
git diff origin/main...HEAD -- $D | grep -nE '^\+.*(fetch|axios)\(' | grep -v withOutbound
git diff origin/main...HEAD | grep -nE '^\+.*(3100|3300|loki|grafana)'                 # portability
```

Findings that block:
- a bare `console.*` in `api/src` or `app/src` (scripts are exempt);
- a `catch {}` with no log and no comment;
- a partner call not wrapped in the outbound helper;
- a new timer with no `counts` in its `job finish`;
- a new user action with no taxonomy event;
- a Loki/Grafana host, port or datasource uid **outside** `deploy/observability/`'s env reads;
- any secret-shaped string inside a log call.

## Arm 2 — the unit assertions (against the pino stream, NOT Loki)

The dev stack runs as a plain foreground process, so its stdout never enters journald and never
reaches Loki. **In dev the pino stream is the whole log** — assert on it.

```sh
cd app && npm run test:unit -- observability     # replay gate, scrub, taxonomy
cd api && npm test -- observability health       # redaction, boundary shapes, health body
```

What must be asserted (`app/src/lib/observability.test.ts` and `api/test/observability.test.ts` are
the shipped references):

1. **The replay gate, both halves, driven directly** — export the gate function so the test calls it
   rather than asserting on a mock's side effects:
   - runtime host not prod + build-time site url prod (a local prod build / a branch through
     `deploy.sh`) ⇒ `init` called, **`startSessionRecording` NOT called**;
   - build-time site url not prod ⇒ **not called**;
   - both halves prod ⇒ called exactly once;
   - no key ⇒ `init` not called at all, every helper a safe no-op.
2. **Redaction** — a secret-shaped key loses its value; an email anywhere in the object (including
   inside free text) comes back as `sha256:…`; a raw credential-bearing path is never emitted.
3. **Boundary shapes** — capture the pino stream and assert the required fields are present:
   `http request` carries `http.route` (the PATTERN, not the path), `outcome`, `duration_ms`;
   `job finish` carries `counts`; an error line carries `sentry_event_id` and **no stack**.
4. **Request-id hygiene** — `resolveRequestId`/`safeId` discards anything outside
   `/^[\w.-]{1,64}$/` (newline injection, an unbounded value).
5. **The taxonomy list is in lockstep with the type** (`as const satisfies readonly
   AnalyticsEventName[]` does most of this at compile time; assert the array length too).

Capturing the stream in a test:

```ts
import { Writable } from 'node:stream'
const lines: any[] = []
const sink = new Writable({ write(c, _e, cb) { lines.push(JSON.parse(String(c))); cb() } })
// build the logger against `sink`, exercise the boundary, then assert on `lines`
```

## Arm 3 — prod-verify mode only

Run these against the live box, never against dev. Each produces a **pasteable artefact**.

```sh
# 3a. a real log line, end to end through Alloy into Loki
systemd-cat -t commons-api echo '{"level":"info","msg":"verify canary","service":"commons-api","request_id":"verify-'$(date +%s)'"}'
sleep 5
curl -sG http://127.0.0.1:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="kommonz",service="api"} |= "verify canary"' \
  | jq -r '.data.result[0].values[0][1]'

# 3b. a real Sentry event id, read back
set -a; . ~/.config/sentry.env; set +a
curl -s "https://de.sentry.io/api/0/projects/$SENTRY_ORG/kommonz-api/events/" \
  -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" | jq -r '.[0] | {eventID, title, "tags": (.tags|from_entries|{request_id, release})}'

# 3c. the health bodies (shape, not just 200)
curl -s http://127.0.0.1:54630/health      | jq '{ok, app, service, env, version, commit, built_at, uptime_s, third_party_mode}'
curl -s http://127.0.0.1:54630/health/deep | jq '{ok, checks: (.checks | map_values({ok, latency_ms}))}'
curl -s http://127.0.0.1:54640/api/health  | jq '{ok, service, commit}'
```

Assertions:
- 3a returns the canary line. Nothing back ⇒ the Alloy relabel matched nothing (check
  `__journal_syslog_identifier`, one underscore) or `alloy.service` is down.
- 3b returns an `eventID` whose tags carry `request_id` and the **same release string the logs use**.
- 3c: `/health` has no `checks` key; `/health/deep` `ok` is the AND of every check with
  `required !== false`, returns **503** when a required check fails and **200** when only an optional
  one does; `detail` is a human string, never a stack trace, credential or raw path;
  `version`/`commit`/`built_at` are build-time constants, not runtime reads.
- **PostHog**: with the key gate shut the correct proof is "no key ⇒ nothing sent", verified by arm 2.
  Once a key is live, capture one event and read it back with the personal API key. Do not send test
  events into the prod project to satisfy a checklist.

## Report

```
## Observability proof
- log line:      <the JSON line returned from Loki>
- sentry event:  <eventID> (release <sha>, tags request_id=<…>)
- posthog:       <event id>  |  gate shut — no key, arm 2 asserts nothing sends
- health:        /health 200 <commit>  ·  /health/deep 200, N checks, M optional
- diff grep:     clean (no console.*, no bare catch, no loki/grafana host outside deploy/observability/)
```

No artefact ⇒ the claim is **unverified**, and say so in those words.
