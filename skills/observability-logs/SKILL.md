---
name: observability-logs
description: The structured-logging contract — pino wide events, the five boundary shapes, request-id propagation, redaction, the app-owned relabel-only Alloy file, and a LogQL cheat-sheet. Use when adding or changing logging in any service; when writing a route, an outbound partner call, an inbound webhook, a background job or a money/state transition; when a log line is missing in Loki; when wiring a new app or unit into the log pipeline; when asked about pino, Alloy, Loki, LogQL, journald, log labels, cardinality or redaction. Not for error capture (use observability-sentry) or product events (use observability-posthog).
---

# Logging contract

**One wide, structured JSON line per unit of work, on stdout.** `msg` is a FIXED string; every
variable is a field. Never `booking ${id} created`.

Reference implementations (read them, do not paraphrase):
`api/src/log.ts` · `api/src/observe.ts` · `app/src/lib/log.ts` · `app/src/lib/request-id.ts`.

## Labels vs fields — the rule that keeps Loki usable

Loki labels are a **four-way partition and nothing more**: `job`, `service`, `service_name`,
`environment`. `request_id`, `org_id`, `user_id`, `route`, `status`, `integration` are **JSON fields**
in the body, queried with `| json`. Promoting one to a label gives every distinct value its own stream
and shreds the index.

⚠️ **Loki's `| json` flattens dots to underscores.** Emit `http.response.status_code`; query
`http_response_status_code`.

Use OTel semconv names on the app side: `http.request.method`, `http.route`,
`http.response.status_code`, `server.address`, `duration_ms`. The four-band field is `outcome`
(`ok | client_error | server_error | skipped`) — `status_class` is emitted by nothing.

## The logger

```ts
export const log: Logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  base: { service: SERVICE, env: ENVIRONMENT, release: RELEASE },
  timestamp: pino.stdTimeFunctions.isoTime,
  formatters: {
    level: (label) => ({ level: label }),   // Loki's detected_level reads the WORD, not pino's number
    log: (obj) => redact(obj) as Record<string, unknown>,
  },
});
```

- ⚠️ **`ENVIRONMENT` is never `NODE_ENV`** — this box exports `development` globally, so a prod build
  would file every line as dev. Use `SENTRY_ENVIRONMENT ?? (NODE_ENV === 'production' ? … )`.
- `RELEASE` is the git sha **baked at build time** (`api/scripts/stamp-release.mjs` writes
  `dist/release.txt` + `dist/build.json`). Reading git at runtime reports the working tree, which can
  be ahead of the build.
- Web (`app/src/lib/log.ts`) is **server-only**: pino is Node-only and the Edge runtime has no
  `node:worker_threads`. Never import it from a Client Component or `middleware.ts`.

## Request-id propagation

Mint above every route, run the request inside `AsyncLocalStorage`, echo the header back:

```ts
const requestId = safeId(req.headers['x-request-id']) ?? randomUUID();
const sessionId = safeId(req.headers['x-posthog-session-id']);   // the replay join key
res.setHeader('x-request-id', requestId);
const child = log.child({ request_id: requestId, ...(sessionId ? { posthog_session_id: sessionId } : {}) });
requestContext.run({ requestId, sessionId, logger: child }, () => next());
```

Then `logger()` anywhere below — several awaits deep in a service — carries both ids with no threading.

- **`safeId` is mandatory**: an inbound id lands in a log body, so anything that is not
  `/^[\w.-]{1,64}$/` is DISCARDED. A newline forges a whole log line; an unbounded value is a
  cardinality hazard.
- Next side: `middleware.ts` mints it with `resolveRequestId()` and sets it on the **request** too
  (that is what makes it readable from `headers()` in a Server Component). Raw server-side fetches to
  the api use `correlationHeaders(await headers())`.
- The browser's PostHog session header does **not** reach the api on server-rendered paths — forward
  it explicitly or the replay join is missing on exactly those requests.

## The five boundary shapes

Use the helpers in `api/src/observe.ts`. Do not hand-roll these.

**A. HTTP request** — one line on `finish`, from `requestLogger()`:
`http.request.method`, `http.route` (**the PATTERN via `routeLabel(req)`**, never the raw path),
`http.response.status_code`, `duration_ms`, `outcome`, `user_id`, `actor`, `auth`. 5xx logs at
`error`, everything else at `info`. `/health`, `/v1/health`, `/ready`, `/.well-known/jwks.json` are
skipped — they would dominate the stream.

**B. Outbound partner call** — `withOutbound(integration, op, fn, meta)`, ONE line per attempt.
It only LOGS; it never captures. A 429 a retry handled is a `warn`, and only the caller knows it gave
up. Capturing inside the wrapper produces one issue per retry attempt and the channel gets muted.

**C. Inbound webhook** — three lines, deliberately:
`webhookReceived(integration, fields)` → `webhookSkipped(integration, reason, fields)` (`outcome:
'skipped'`) → `webhookHandled(integration, fields)`. A skip is a first-class outcome: "we received it
and chose not to act" must be distinguishable from "we never got it".

**D. Background job** — `jobRun(job, runId, fn)` wraps the work and emits `job start` /
`job finish {counts}`. **`counts` is MANDATORY.** A job that finishes `ok` having processed 0 rows for
three days is the failure nobody notices; the per-timer staleness alert and the "job did nothing"
alert both read `counts`.

**E. Money / state transition** — `stateTransition({ entity, entity_id, from, to, reason, org_id,
actor_user_id, amount_cents, currency })`, one `state transition` line. Every invoice/payment/
subscription/membership/order status change goes through it.

**The floor**: an error handler at the bottom of the tree (`jsonErrors` in `api/src/app.ts`) captures
with `fingerprint: [route, err.name]` and logs `sentry_event_id` — the stack lives in the error sink,
never in the log body.

## Redaction

```ts
const SECRETISH = /authorization|cookie|secret|token|password|api[-_]?key|apikey|card|cvc|iban|signature|bearer/i;
export const hashEmail = (e) => `sha256:${sha256(`${SALT}:${e.trim().toLowerCase()}`).slice(0,16)}`;
export const scrubText = (s) => s.replace(EMAIL, hashEmail);   // partner error bodies, operator prose
```

`redact()` is recursive, depth-capped at 5, array-capped at 50, and runs as a pino `log` formatter so
it cannot be forgotten at a call site. A secret-shaped KEY loses its value; every string is
email-scrubbed. **This is a backstop.** The defence is not putting the thing in the object.

Web-side uses pino's `redact.paths` (`'*.token'`, `'*.iban'`, `'headers.cookie'`, …) plus
`lib/sentry-scrub.ts` for events.

## The Alloy file — relabel-only, app-owned

`api/deploy/observability/commons-logs.alloy` is the template. It declares **no Loki address**:

```hcl
loki.source.journal "kommonz" {
  forward_to    = [loki.write.observability.receiver]   // BY COMPONENT NAME. Never a URL.
  relabel_rules = loki.relabel.kommonz.rules
  labels        = { job = "kommonz", environment = "production" }
  max_age       = "12h"
}
loki.relabel "kommonz" {
  forward_to = []                                        // rules-only
  rule { source_labels = ["__journal_syslog_identifier"]  // ONE underscore before `journal`
         regex = "commons-(.+)" target_label = "service" replacement = "$1" }
  rule { action = "keep" source_labels = ["service"] regex = ".+" }   // drop other tenants' units
}
```

⚠️ Gotchas that silently ship nothing:
- `__journal_syslog_identifier` has **one** underscore after `__journal` (the journal field
  `SYSLOG_IDENTIFIER` has no leading `_`); contrast `__journal__systemd_user_unit`. Two underscores
  matches nothing and the `keep` rule then drops every line.
- Match on `syslog_identifier`, not `systemd_user_unit`, so `systemd-cat -t <ident>` (the smoke test)
  lands on the same stream as the unit.
- The `keep` rule is mandatory: the journal carries every other tenant's units.

Install (validates the whole `/etc/alloy` dir BEFORE restarting — `alloy.service` is shared box-wide,
a malformed file takes down every tenant's pipeline):

```sh
cd <repo>/api/deploy/observability && ./install-alloy-app.sh          # this app's file
~/ops/infra/observability/install-alloy-shared.sh                     # platform, once per box
```

## Three silent-failure gotchas

1. **journald rate limiting** drops lines and only says so in a `"Suppressed … messages"` line. Alert
   on that string; raise `RateLimitBurst=`/`RateLimitIntervalSec=` in the unit if a job is chatty.
2. **Next.js's own `logging` config is development-only.** Every production web log line is yours to
   write.
3. **The dev stack never reaches journald.** `api/scripts/dev-stack.sh` runs commons-api as a plain
   foreground process, so nothing in dev enters Loki. In dev the **pino stream is the whole log** —
   which is why `verify-observability` asserts against the stream, not Loki.

## LogQL cheat-sheet

```logql
{job="kommonz", service="api"}                                   # everything from one service
{job="kommonz"} | json | request_id="8f3c…"                      # THE triage query
{job="kommonz"} | json | org_id="…" | __error__=""               # widen to the org, drop parse errors
{job="kommonz"} | json | msg="http request" | http_response_status_code>=500
sum by (http_route) (count_over_time({job="kommonz"} | json | outcome="server_error" [15m]))
quantile_over_time(0.95, {job="kommonz"} | json | msg="http request" | unwrap duration_ms [15m]) by (http_route)
absent_over_time({job="kommonz",service="api"}[15m])             # service silence — beats a health probe
{job="kommonz"} | json | msg="job finish" | job="accounting-drain"    # per-timer staleness
{job="kommonz"} | json | msg="outbound call" | integration="merit" | outcome!="ok"
{job="kommonz"} |= "Suppressed"                                  # journald dropped lines
```

Two `job` labels, never mixed in one query: `{job="obs"}` is the collector's gauges (`ops-dashboard`);
`{job="<app>"}` is the app's own OTel-shaped lines.

## Prove the wiring

```sh
systemd-cat -t commons-api echo '{"level":"info","msg":"alloy wiring test","service":"commons-api"}'
curl -sG http://127.0.0.1:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="kommonz",service="api"}' | jq '.data.result[0].values[0]'
```
