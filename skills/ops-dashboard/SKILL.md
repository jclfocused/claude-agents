---
name: ops-dashboard
description: Onboard a product onto its own ops dashboard — write manifest.yaml, run `obs validate/gen/install/push`, stand up obs-grafana@<slug> on its port, publish ops.<domain> behind Cloudflare Access, pair alerts to panels, and prove it. Also covers moving a product's dashboard to another server. Use when asked to "set up a dashboard", "onboard <product> to ops", "add a panel/alert", "regenerate the dashboard", "the board is stale/red/green-but-wrong", "add this timer to the board", "what is on ops.<domain>", or when scaffolding a new app that needs a manifest entry. Owns the manifest schema and the collector's rules. Not for app-side instrumentation (observability, observability-logs) or for investigating an alert (observability-triage).
---

# ops-dashboard

**One Grafana per product, on that product's own `ops.<domain>`, behind Cloudflare Access.**
Platform pieces are estate-wide and live in `~/ops/infra/observability/`; everything product-specific
lives in the product's own repo and moves with it.

```
PLATFORM  ~/ops/infra/observability/          APP  <repo>/api/deploy/observability/
  bin/obs                 the only entry point   manifest.yaml      the one file a human writes
  collector/collect.mjs   ONE collector, all     <app>-logs.alloy   relabel-only (observability-logs)
  gen/build.mjs + rows/   manifest -> tree       grafana/           GENERATED, committed
  projects.yaml           slug -> manifest ->      grafana.ini · provisioning/{datasources,
                          cadence -> PORT REGISTRY  dashboards,alerting}
  units/obs-collect@.*    units/obs-grafana@.*   grafana/push.sh    links the tree in + reloads
  units/obs-watchdog.*    install-alloy-app.sh   install.sh         enable unit + alloy + push
```

## The onboard

`obs` (`~/ops/infra/observability/bin/obs`) is the ONLY entry point. The shipped verbs:

```sh
cd ~/ops/infra/observability
node bin/obs list                    # the registry: slug, grafana port, cadence, phase, manifest path
node bin/obs validate <slug>         # refuses a manifest the board cannot honestly render
node bin/obs gen <slug> [--check]    # manifest -> <repo>/api/deploy/observability/grafana/ (pure, no network)
node bin/obs render-alerts <slug>    # the rule table: id, severity, phase, where, panel, for=, title
node bin/obs collect <slug>          # one oneshot collector tick, NDJSON on stdout
node bin/obs status <slug>           # /run/obs/<slug>/status.json — DIES "UNKNOWN" if older than ttl_s
node bin/obs install <slug>          # seeds ~/.config/observability/<slug>.env + the units
node bin/obs push <slug>             # shells the APP's own grafana/push.sh — no token, no dashboards API
```

Onboard order (do it by hand; **`obs scan` and `obs onboard` are NOT built yet** — deliberately, until
a second product needs them, so write the manifest from a box audit):

1. write `<repo>/api/deploy/observability/manifest.yaml`, claim a port, register the slug in
   `~/ops/infra/observability/projects.yaml`;
2. `obs validate <slug>` until clean;
3. `obs gen <slug>` and commit the generated tree;
4. `obs install <slug>`, then `systemctl --user enable --now obs-collect@<slug>.timer
   obs-grafana@<slug>.service`;
5. `obs push <slug>` — **the instance must exist before there is anything to provision into**;
6. the two Cloudflare-side steps below, which the box cannot do for you.

`obs gen --check` re-renders and diffs against the committed files and exits non-zero on drift — that
is the CI gate. `obs status` refusing a stale file is deliberate: an agent that reads a stale
`status.json` and reports green is worse than no dashboard.

## Write the manifest from a FILE audit, not a timer list

Diff `<repo>/*/deploy/*.timer` and `*.service` **FILES** against installed units
(`systemctl --user is-enabled <unit>`) and mark any file with no unit `installed: never`. An
inventory that starts from `systemctl list-timers` is structurally blind to that state — it is how a
reminders timer sat un-installed for months with nothing to notice. `installed` is **three states,
not two**: `enabled` (2) · `linked` (1) · `never`/not-found (0). `systemctl show` on a `not-found`
unit returns plausible-looking defaults, so checking existence is step zero, not step one.

## What `obs validate` refuses

- a service with neither `unit` nor `probe`;
- a job without `expected_every` or without `installed`;
- a missing `slo`, or an `slo` key with no panel consumer;
- a `mobile` block that is neither `none` nor two platforms;
- an `errors.projects` entry that does not exist in Sentry;
- an `ingress[]` row without a probe;
- a `dashboard.grafana.port` already claimed by another manifest in `projects.yaml`;
- **a `dashboard.host` that resolves publicly with `access: none`.**

## Manifest — the blocks and the rules

Reference: `api/deploy/observability/manifest.yaml` (Kommonz, every state verified on the box) and
`docs/OPS-DASHBOARD-PLAN.md` §3.2/§3.3.

`schema_version · project · title · repo_root · cadence_s · owners · links` then:

| Block | Rules |
|---|---|
| `dashboard` | `host: ops.<domain>` · `grafana.port` from the registry, loopback only · `access:` **never `none`** on a public host · `provisioning:` points at the app's own tree |
| `environments[]` | `is_production`, `third_party_mode` (**expected**; the probe reports the ACTUAL and the alert fires on the MISMATCH, never on the value), `database`, `expected_state: ephemeral` for a dev stack so "down" is never red |
| `ingress[]` | one row per public hostname, each with a probe and an `expect`. Tunnel fan-out lives in Cloudflare's dashboard-side config and is invisible on the box — **it lives in this list or nowhere.** A legacy prefix a shipped mobile build compiled in gets its own row with `critical: mobile` |
| `services[]` | `unit`, `port`, `bind`, `syslog_identifier`, `expected_state`, `probe`, `deep`, `version.source`, `depends_on` |
| `jobs[]` | every tracked `.timer` FILE, `expected_every` **mandatory**, `installed` three-state, and a `why` on anything not `enabled` |
| `db` | ONE psql round trip per tick through `SECURITY DEFINER` functions granted to `obs_ro` and nothing else. **Never a `BYPASSRLS` role.** |
| `queues[]`, `gates[]` | a queue whose drain is deliberately off is **rendered, never alerted** — otherwise it fires from the first tick forever |
| `partners[]`, `integrations[]` | `secret_ref` renders **presence, never a value** |
| `product`, `mobile`, `errors`, `slo`, `deploy` | `version_source` names the real source of truth (App Store Connect / a CI run), not the repo |
| `gaps[]` | every known untruth, written down. A board that hides its gaps is worse than no board |

## Collector rules — the ones that keep the board honest

- **Every gauge is a NUMBER** (`unwrap` needs numbers). Booleans are `0|1`. Enums are small integers
  with the mapping written in the panel. **No string is ever unwrapped.**
- **Per-source isolation**: a source the collector could not reach emits `null` **plus**
  `<source>_stale: 1`. A missing number must never render green.
- **`No value` → STALE**, always, in every panel's value mapping. Not optional.
- `status.json` staleness: `now - generated_at > ttl_s` ⇒ **UNKNOWN**.
- **Nothing in the event is PII** — counts only; no emails, org names, ids or raw paths. That is what
  makes the board safe to leave on an office screen. Secrets are never logged, never rendered, never
  written to `status.json`.
- **Two contracts, never mixed in one query**: `{job="obs"}` = the collector's `up`, `q_*`, `gate_*`,
  `job_*`, `host_*`, `stack_*`; `{job="<app>"}` = the app's own OTel-semconv lines, **dots flattened
  to underscores** by `| json`.
- **Tenancy**: `job`-label filtering is presentational, not a security boundary. Do not describe it
  as isolation.

## Panels and alerts

**One alert per RED, and not one more.** A panel that can be red without an alert is decoration; an
alert with no panel is a page with nowhere to look. Deliberate non-alerts get a `why` in the manifest
(a queue whose drain is gated off; a dev stack that is normally down; a demo environment on sandbox
keys). Never enable a gated timer to clear a colour on a dashboard — the outbound-send and
money-write gates outrank the board.

`obs push` **shells the app's own `grafana/push.sh`**, which links the provisioning tree into that
instance's `GF_PATHS_PROVISIONING` and reloads it. No token, no folder API, no
`POST /api/dashboards/db` — the instance reads the repo. One implementation, in the app repo, so a
moved app provisions itself with no ops checkout.

⚠️ **A folder created BY a service account is unreadable by that same service account** (Grafana 11.6
— the create returns 200, then every read 403s `folders:read`). Folders are created by an admin; the
SA only writes into them. This is one of the reasons provisioning beats the API here.

The generated tree is **read-only in the Grafana UI**. Edit `manifest.yaml` and re-run `obs gen`;
never edit a panel in the browser.

## Publishing `ops.<domain>`

Order, and do not skip step 3:

1. proxied DNS record for `ops.<domain>`;
2. an ingress row on the product's **existing** tunnel → `127.0.0.1:<grafana port>`;
3. a **Cloudflare Access application with an email allowlist** — never a public hostname without one;
4. only then uncomment the `ingress[]` row in the manifest and regenerate.

Adding the probe row before the host resolves gives you an alert that fires forever on day one — the
permanent false red this whole design refuses. If Access cannot be enabled on the account, the
instance stays **loopback-only** and the manifest records it in `gaps[]`. Recipe details:
`cloudflare-api`.

## Moving a product to another server

The delta is small because the split was designed for it:

1. install the platform module on the new box (`install-alloy-shared.sh`, Loki/Grafana in k3s ns
   `observability`, `install.sh`);
2. clone the app repo — it already carries `manifest.yaml`, `<app>-logs.alloy`, `grafana/`,
   `push.sh`, `install.sh`;
3. claim a port in that box's `projects.yaml`;
4. `./install-alloy-app.sh` then `obs install <slug>` then `obs push <slug>`;
5. move the DNS record + tunnel ingress row + Access application;
6. update `repo_root` and any host in the manifest, `obs gen`, commit.

Nothing in the app's tree names a Loki or Grafana host, so no file edited in steps 1–4. If you find
yourself editing one, the portability contract is broken — fix that, not the symptom.

## Prove it

```sh
systemctl --user status obs-grafana@<slug>.service obs-collect@<slug>.timer
curl -s http://127.0.0.1:<port>/api/health | jq                    # the instance
curl -sG http://127.0.0.1:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="obs", service="<slug>"}' | jq '.data.result | length'   # the collector
node bin/obs gen <slug> --check                                    # no drift
```
Plus a screenshot of the board above the fold, and one alert deliberately driven red and back.
