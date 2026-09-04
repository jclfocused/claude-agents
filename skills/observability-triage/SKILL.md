---
name: observability-triage
description: First-line support — take an alert or a prod symptom from intake to a hypothesis and a fix PR, joining Sentry issue → request id → Loki logs → PostHog session/replay. Use when an alert fires (i2a item, Telegram, Sentry email, Grafana contact point); when the user says "something is broken in prod", "why did X fail", "investigate this error/issue", "users are reporting", "check the logs", "is the site down", "what happened to this booking/invoice"; when running the daily sweep; and whenever a Sentry issue URL or a request id is handed to you. Owns the autonomy boundaries for prod investigation. Not for adding instrumentation (observability / observability-logs) or for building dashboards (ops-dashboard).
---

# Triage runbook

## 0. Context rule, before anything else

**Every MCP query runs in a subagent lane and returns a COMPACT BRIEF.** Never read a full issue
list, an event payload or a log dump into the orchestrator's context — that has killed a session
twice. The Grafana MCP guardrail flags below exist for exactly this.

## The runbook

```
0. INTAKE     alert webhook -> i2a tracker item (+ Telegram). Carries: source, issue url,
              fingerprint, org_id, first_seen, count, release.
1. CLASSIFY   new / regression / spike? which release introduced it (compare `release` to the
              last deployed sha)?
2. SCOPE      one org or many? one route or many?
              ONE org + ONE integration  => partner/config problem, not our bug.
              MANY orgs + ONE route      => our bug.
3. CORRELATE  pull `request_id` from the Sentry tag ->
                {job="<app>"} | json | request_id="..."
              then widen:
                {job="<app>"} | json | org_id="..." | __error__=""
4. REPRODUCE  pull `posthog_session_id` from the same tag -> the replay (PROD ONLY; there is no
              replay in dev, by design).
5. HYPOTHESIS one line: the file, the function, and the evidence from EACH of the three systems.
6. ACT        within the autonomy limits below.
7. CLOSE      comment on the issue with the finding + PR link; resolve-in-next-release.
```

Steps 3–4 only work because `request_id` and `posthog_session_id` are both a Sentry **tag** and a Loki
**field**, and `sentry_event_id` is written into the error log line. If a join fails, suspect a missing
header forward before suspecting the data: the browser's PostHog session header does not reach the api
on server-rendered paths unless the app forwards it.

## Queries you will actually type

```logql
{job="kommonz"} | json | request_id="8f3c…"                                 # step 3
{job="kommonz"} | json | org_id="…" | __error__=""                          # widen
{job="kommonz"} | json | msg="http request" | http_response_status_code>=500
{job="kommonz"} | json | msg="outbound call" | integration="merit" | outcome!="ok"
{job="kommonz"} | json | msg="job finish" | job="accounting-drain"
{job="kommonz"} | json | msg="state transition" | entity="invoice" | entity_id="…"
absent_over_time({job="kommonz",service="api"}[15m])
{job="kommonz"} |= "Suppressed"                                             # journald dropped lines
```

⚠️ `| json` flattens dots to underscores: `http_response_status_code`, never
`http.response.status_code`. And never mix `{job="obs"}` (collector gauges) with `{job="<app>"}`
(the app's own lines) in one query — two contracts.

## MCP servers

⚠️ **Tool names below are the official servers' documented names; VERIFY against the live tool list
before relying on an exact string.** Configure per `mcp-project-config`.

| Server | Endpoint / command | Config |
|---|---|---|
| **Sentry** (official, hosted) | `https://mcp.sentry.dev/mcp` | OAuth. Pin the org (`laserfocused`) and, where a lane needs one, the project. Issues, events, releases, Seer root-cause. Read-mostly; issue resolution is inside the boundary, deploys are not. |
| **PostHog** | `https://mcp.posthog.com/mcp?mode=cli` | **`cli` mode** — one `exec` tool, context-cheap. Read-only session restriction, tool filtering, pinned to one org/project. |
| **Grafana** | `uvx mcp-grafana`, `GRAFANA_URL=http://127.0.0.1:3301` | `--disable-write --enabled-tools loki,dashboard,alerting,datasources --max-loki-log-limit 50 --loki-guardrail-mode enforce`. Read-only service account scoped to the Loki datasource. |

Without an MCP, everything is reachable with `curl` — the Loki HTTP API on `127.0.0.1:3100`, the
Sentry API on `https://de.sentry.io/api/0/` with `~/.config/sentry.env`, PostHog on
`https://eu.posthog.com/api` with `~/.config/posthog.env`.

## Alert routing

`Sentry alert / Grafana contact point / obs-watchdog → webhook → a dumb normaliser → i2a tracker item
(+ Telegram)`. The handler verifies the signature, normalises to
`{source, severity, title, url, fingerprint, org_id, release, count, first_seen}` and **dedupes on
`fingerprint`**. One inbox, one dedupe key — otherwise an outage produces a hundred Telegram messages,
Justin mutes the channel, and that is the real failure mode.

`obs-watchdog` goes **direct to Telegram**, deliberately: it is the dead-man switch for the stack that
carries every other alert. Precedent for the sink: `api/deploy/alert.sh` (rate-limited, 6h per-message
cooldown keyed on the message hash).

## Proactive checks

| Check | Where | Fires when |
|---|---|---|
| Service silence | Loki | `absent_over_time({job="<app>",service="api"}[15m])` — beats a health probe: catches a wedged process AND a unit that never came back after a deploy |
| Error rate | Loki | `outcome="server_error"` / total > 1% over 15m per service |
| Timer staleness | Loki | no `job finish` for a `job` in N × its interval — **per timer**, because only one Sentry cron monitor is included |
| Job did nothing | Loki | `job finish` with `counts.scanned == 0` for N consecutive runs |
| Webhook failure ratio | Loki | non-ok > 5% over 1h per `integration` |
| Partner degradation | Loki | p95 `outbound call` duration or error rate per `integration` |
| journald drops | Loki | any line matching `"Suppressed"` — the rate limiter fails silently otherwise |
| p95 latency | Loki | p95 `duration_ms` per `http.route` above threshold for 15m |
| Money invariants | `commons-invariants.timer`, hourly, read-only SQL | invoices `paid` with no payment row · payments with no invoice · Merit-settled vs local sum mismatch. The only check that catches a books gap the logs cannot |
| **The stack itself** | `obs-watchdog.timer`, 5-minutely, Telegram direct | `alloy.service` not active · Loki `/ready` not ok · Grafana `/api/health` not ok · Loki PVC >70% · no app stream in Loki for 15m. **If Loki dies every Loki-based row above goes silently green** — this is what makes the rest trustworthy |

**Daily sweep** (`obs-sweep`, 09:00): one lane reads new/regressed issues since yesterday plus the
anomaly queries, and files **one** i2a item with a ranked list — or nothing if clean. Alerts fire on
thresholds; the sweep notices the drift nobody set a threshold for. Read-only MCPs, compact brief, no
autonomous fixes.

## Autonomy boundaries

**Autonomous** — investigate; query all three systems; read code; write the triage note; open a PR
with a fix + test on a branch; add a dashboard panel or a *non-paging* alert; mark an issue
resolved-in-next-release; add a fingerprint rule to stop fan-out.

**Ask first** — anything that deploys to prod; anything that **writes prod data** (standing rule);
silencing an alert; changing sampling or retention (cost + evidence loss); money paths, auth/RLS/
tenancy, door access (dual review); anything outbound to an external recipient; rotating a credential.

**Never** — deleting logs, replays or issues; turning off the error sink or a drain; editing a
fingerprint to hide a recurring error instead of fixing it; raising a threshold to make an alert stop.

And the standing rule that outranks all of it: **a red check is yours to fix.** "Pre-existing" and
"flaky" are not triage outcomes.

## Output shape

Report in the `reply-format` template. The finding is one line, then the evidence, then the action:

```
Status: red — <one line: what is broken, for whom, since when>

What happened
- Sentry <issue-url> · fingerprint <…> · release <sha> · first_seen <ts> · <n> events, <m> orgs
- Loki: <the query> → <the one line that proves it>
- PostHog: session <id> → <what the human actually did>  (or: no replay, non-prod / no key)
- Hypothesis: <file>:<fn> — <mechanism>

## Needs you
- <only what Justin must do>
```
