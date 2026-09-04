---
name: observability
description: The umbrella rule for logs, errors and product analytics on this box — three systems, one join key, and the definition of done that says a feature nobody can see running in prod is not finished. Use when adding a feature, integration, background job, timer, service or user-facing action to any app; when asked "is this observable", "add logging", "why can't we see what happened in prod", "wire up monitoring/telemetry/analytics"; when scaffolding a new app or backend; and as the pre-ship checklist on any lane that touched a boundary. Delegates mechanics — use observability-logs for pino/Loki/Alloy, observability-sentry for the error sink, observability-posthog for events/replay, observability-triage to investigate an alert, verify-observability to prove it, ops-dashboard for the Grafana instance and manifest.
---

# Observability — the umbrella

Three systems, three jobs, no overlap. Never make one do another's job.

| System | Answers | Store |
|---|---|---|
| **Logs** (pino → journald → Alloy → Loki) | "what happened, in order, with which ids" | self-hosted, loopback |
| **Errors** (Sentry SaaS, org `laserfocused`, EU `de.sentry.io`) | "something broke, here is the code state + stack" | SaaS |
| **Product analytics** (PostHog Cloud EU) | "did a human accomplish the thing" + session replay | SaaS |

The single design decision that makes agent triage work: **`request_id` and `posthog_session_id` are
both a Sentry tag AND a log field, and `sentry_event_id` is written into the error log line.** That
bidirectional join is load-bearing. Never break it to simplify something.

Reference (this workspace): `docs/OBSERVABILITY-PLAN.md` (rev 4, ratified 2026-09-04) and
`docs/OPS-DASHBOARD-PLAN.md` (rev 3). Read the SHIPPED CODE, not the plan prose, when they disagree.

## Definition of done — ANY feature, in any app

A feature with no way to tell whether it works in prod is not finished. For everything the lane touched:

1. **Boundary events.** Every new boundary emits its wide event (`observability-logs` §five shapes).
   No bare `console.*`. No `catch {}` with no log.
2. **Deliberate captures.** Every new integration or job has a capture at the DECISION POINT (not in
   the HTTP wrapper) with tags, a context and an **explicit fingerprint**. Every new timer has a
   monitor or a Loki staleness rule.
3. **One event per user action.** `object_action`, snake_case, past tense, with the `organization`
   group, plus a line in the repo's taxonomy doc. Names are IRREVERSIBLE — see `observability-posthog`.
4. **A panel and an alert per new job/timer.** In the app's own `deploy/observability/`, generated
   from `manifest.yaml` (`ops-dashboard`).
5. **A service gets `/health` + `/health/deep` and a `manifest.yaml` entry.** Shape in
   `docs/OPS-DASHBOARD-PLAN.md` §5.2; `api/src/health.ts` is the reference implementation.
6. **Portability holds** (below).
7. **Proof, pasted**: one real log line, one real Sentry event id, one real PostHog event id (or an
   explicit "gate shut, nothing sends" note). `verify-observability` produces these.

## Portability contract — never break it

The app owns everything named after the app; the platform owns everything named after the estate.

| Layer | Lives in | Owns |
|---|---|---|
| Platform | `~/ops/infra/observability/` → `/etc/alloy/observability.alloy`, k3s ns `observability` | the one shared `loki.write "observability"`, the Loki address, Grafana unit templates, the `obs` generator, the port registry |
| App | `<repo>/api/deploy/observability/` | `manifest.yaml`, `<app>-logs.alloy` (relabel-only), the generated `grafana/` tree, `push.sh`, `install.sh` |

Rules:
- An app's `.alloy` file forwards to `loki.write.observability.receiver` **by component name** — never
  a URL, never a port.
- App code reads `GRAFANA_URL` / `GRAFANA_SA_TOKEN` from env; it never hardcodes a host.
- **Grep the diff before shipping**: `3100`, `3300`, `loki`, `grafana` must not appear outside
  `deploy/observability/`'s env reads.
- Moving an app to another server = install the platform module there, re-run the app's `install.sh`.
  If that is not true, the contract is broken.

## The not-to-log list

Never in a log body, a Sentry event, a PostHog property, a dashboard panel or `status.json`:
email addresses (hash them), names, phone, address, reg codes, card data, IBANs, bearer/session
tokens, `stripe-signature`, door credentials (`door_credentials.number` — never, in any form),
member-authored free text (a booking title is free text: log the duration), raw request bodies,
raw URLs on credential-bearing routes (`/join/:code`, `/auth/confirm`, `/pms/webhook/:token`,
`/invite/:code` — log the ROUTE PATTERN via `routeLabel()`, never the path).

Structural first, denylist second: the denylist in `api/src/log.ts` (`SECRETISH`) is a backstop, not
the defence. The defence is not putting it in the object.

## Values the setup skills collect

Take these by NAME through `secrets-intake`; never echo a value; presence-check and probe read-only.
`docs/OBSERVABILITY-PLAN.md` §9b is the full table.

| Pillar | Values | Where |
|---|---|---|
| Sentry | `SENTRY_ORG`, `SENTRY_AUTH_TOKEN` | `~/.config/sentry.env` |
| Sentry per app/env | `SENTRY_DSN`, `SENTRY_PROJECT`, `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE` | `~/.config/<app>/*.env`; `NEXT_PUBLIC_SENTRY_DSN` baked at build; Info.plist / BuildConfig on mobile |
| PostHog | `POSTHOG_API_HOST`, `POSTHOG_PERSONAL_API_KEY` | `~/.config/posthog.env` |
| PostHog per app/env | `NEXT_PUBLIC_POSTHOG_KEY` / `PUBLIC_POSTHOG_KEY`, `POSTHOG_PROJECT_ID`, `POSTHOG_HOST` | `~/.config/<app>/web.env`, `api.env` |
| Grafana | `GRAFANA_URL`, `GRAFANA_SA_TOKEN` | `~/.config/observability/grafana.env` (+ `grafana-<slug>.env` for the admin password) |
| Loki | push URL | the platform `observability.alloy` — **never the app** |
| Alerts | i2a webhook URL, Telegram bot token + chat id | `~/ops` env |

Plus, at scaffold time: app slug · surfaces · environments + hostnames · systemd unit prefix +
`SyslogIdentifier` · timers · integrations · mobile bundle ids. That is the `manifest.yaml` input set.

## Standing gates

- **The PostHog prod key is held as `POSTHOG_KEY_PENDING`** until Justin ratifies the taxonomy doc
  (`docs/POSTHOG-TAXONOMY.md`, 27 events). Every capture helper no-ops without a key. Do not rename
  that variable on your own initiative.
- **Sentry stays SaaS Developer** until Justin upgrades. PAYG budget $0. `enableLogs: false`
  everywhere (Loki is the log store). Replay is PostHog's, not Sentry's.
- **Alerts route through i2a, deduped on `fingerprint`**; `obs-watchdog` goes direct to Telegram
  because it is the dead-man switch for the stack that carries the other alerts.
- **Prod-only session replay** is enforced by a build-time gate + a runtime gate + no dev key + a
  unit test. Never by a dashboard toggle.

## Run the verify

```sh
# repo-local, from the app repo
cd app && npm run test:unit -- observability     # replay gate + scrub + taxonomy
cd api && npm test -- observability              # redaction, boundary shapes, health
```
Full arms, including the prod canary through Loki and a real Sentry read-back: `verify-observability`.

## Where to go next

| Job | Skill |
|---|---|
| pino contract, boundary shapes, Alloy file, LogQL | `observability-logs` |
| Sentry project bootstrap, init per runtime, fingerprints, releases/symbols, caps | `observability-sentry` |
| PostHog project bootstrap, taxonomy, replay gate, masking, identify/group | `observability-posthog` |
| An alert fired / something is broken in prod | `observability-triage` |
| Prove it, before claiming done | `verify-observability` |
| Manifest, `obs gen`, per-product Grafana, moving a product | `ops-dashboard` |
| The health endpoint body | `docs/OPS-DASHBOARD-PLAN.md` §5 + `api/src/health.ts` |
