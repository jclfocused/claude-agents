---
name: setup-backend
description: Kickoff/decision guide for standing up a backend on THIS server (Justin's box). Use when the user says "setup backend", "new backend on the server", "self-host this app", "host it on the box", "move off supabase", "de-supabase", or a new app needs server-side data. Routes to the shape choice (single-app rkfitness vs hyperglot microservice) and the ordered domain skills; does not itself teach the details.
---

# setup-backend — kickoff for a backend on this box

This skill ROUTES. It picks the shape, walks the ordered checklist, and names the
domain skill for each step. The domain skills teach; read only the ones the step needs.

## Step 0 — the first question

**Does the app touch local/server data (DB on this box, local Supabase, files on disk, a server process)?**
- **Yes** → it runs ON THIS SERVER: loopback service + systemd --user unit + cloudflared tunnel (`<host>.laserfocused.ee → localhost:<port>`). NEVER a Cloudflare Worker (same-account Worker fetch() back to a tunnel loops, error 1003).
- **No** (static site, or backend fully external) → Cloudflare Pages/Workers is fine; this skill doesn't apply. See `astro-landing` / `nextjs-cloudflare-app`.

## Step 1 — pick the shape

**Default = rkfitness single-app shape.** One repo, one DB, auth inline, SPA + API on one origin. Escalate to hyperglot only when the criteria below say so.

| | **rkfitness shape** (single app) | **hyperglot shape** (microservices) |
|---|---|---|
| Repos/services | 1 repo, 1 process | many services, template unit `<name>@.service` |
| DB | 1 role+db on shared native PG16 `127.0.0.1:5641` | db-per-service on the same cluster, `create-service-db.sh` |
| Auth | inline: bcryptjs + jose HS256 + rotating refresh | own auth service, ES256 JWT + JWKS, local verify per service |
| Origin | Express serves `/v1/*` API + built SPA, zero CORS | api-gateway + host cloudflared with committed ingress |
| Deploy | in-repo `deploy.sh`: git pull → build → migrate → restart → /health poll | GHA reusable workflow → self-hosted runner → atomic release flip + auto-rollback |
| Model files | `~/.config/systemd/user/rkfitness-api.service` + `rkfitness-tunnel.service`; `~/prod/rkfitness/rkfitness-api/deploy/deploy.sh` | `~/.config/systemd/user/hyperglot@.service`; `/home/justin/code/hyperglot-workspace/hyperglot-infra/` (`DEPLOY.md`, `scripts/`, `backup/`) |

Choose **hyperglot shape** only if ≥2 of: multiple teams/deploy cadences, ≥3 genuinely independent services, a public metered API needing a gateway lane, release-flip + auto-rollback is a hard requirement. Otherwise rkfitness. You can graduate later; you can't un-complicate.

## Step 2 — ordered checklist (each step names its skill)

1. **Port** — `ss -ltn` first; pick a free high loopback port. Supabase stacks take a 546XX 10-port block per `supabase-local`. Record it in the workspace CLAUDE.md / port registry.
2. **DB** → `backend-postgres-box`. Role+db on the native PG16 cluster `127.0.0.1:5641` (model: `/home/justin/code/hyperglot-workspace/hyperglot-infra/scripts/create-service-db.sh`). Loopback-only, forever.
3. **Service + unit + tunnel** → `backend-box-deploy`. `~/prod/<slug>` layout, systemd --user unit pair, token tunnel (`TUNNEL_TOKEN` in `~/.config/<slug>/tunnel.env`), DNS via `cloudflare-api` (canonical script: `/home/justin/code/mjcode/scripts/setup-cloudflare.sh`).
4. **Observability** → `observability` (**before the first feature, not after**). See the section below — `log.ts` + `instrument.ts` + `/health` + `deploy/observability/`. Retrofitting costs a week and never fully lands.
5. **Auth** → `backend-auth-service`. rkfitness inline pattern by default; hyperglot auth service only in the microservice shape.
6. **Storage** → `backend-file-storage`. Disk under `~/prod/<slug>/storage`, busboy multipart, HMAC-signed relative URL paths.
7. **Realtime** → `backend-realtime-sse`. SSE (pg LISTEN/NOTIFY or trigger tables); WS only when truly needed.
8. **Email** → `backend-email`. Resend, graceful no-op when the key is unset.
9. **Backups + watchdog + registry** — nightly restic→R2 timer + restore-check (model: `/home/justin/code/hyperglot-workspace/hyperglot-infra/backup/hg-backup.sh` + the `hyperglot-backup.timer`/`hyperglot-backup-check.timer` symlinks in `~/.config/systemd/user/`); optional 60s watchdog that starts only `inactive` units (`/home/justin/ops/infra/ops-web-watchdog.service`); register in `~/ops/packages/shared/workspaces.json` (kind `systemd`, units, healthUrl).
10. **Verify** → `deploy-verify`. Curl the live https URL for the new artifact AND prove the DB port is unreachable off-box. Flow-level checks → `sandbox-verify` (or the repo-local verify skill).

Skip a step that doesn't apply (no files → no storage step) — but never skip 1–4, 9, 10.

## Observability (required)

Step 4 above, in full. Read `observability` for the contract and the definition of done;
`observability-logs` / `observability-sentry` for the mechanics. Scaffold in this order, on day 1:

1. **`src/log.ts`** — pino, `base: { service, env, release }`, ISO time, `formatters.level` returning
   the word, a recursive `redact()` and an email hasher, an `AsyncLocalStorage` request context, and a
   `requestLogger()` middleware that writes ONE wide `http request` line per request. Reference
   implementation to copy: `~/code/coworking-mng-not-shit/api/src/log.ts`.
2. **`src/instrument.ts`** — Sentry init behind `!!SENTRY_DSN && NODE_ENV === 'production'`, with
   `tracesSampleRate 0.05`, `enableLogs: false`, `profileSessionSampleRate 0`, `sendDefaultPii: false`
   and a `beforeSend` that drops request body/cookies/headers. It must load **before** express/pg:
   the unit runs `node --import ./dist/instrument.js dist/index.js`. Reference:
   `~/code/coworking-mng-not-shit/api/src/instrument.ts`.
3. **`/health` and `/health/deep`** — unauthenticated at BOTH `/health` and `/v1/health`,
   `{ ok, service, release, ... }`. The deep report is not a public document; gate it.
   Reference: `api/src/health.ts` in the same repo.
4. **`deploy/observability/`** — `<app>-logs.alloy` (relabel-only, forwarding to
   `loki.write.observability.receiver` **by component name**), `manifest.yaml`, generated `grafana/`,
   `push.sh` (reads `GRAFANA_URL` + `GRAFANA_SA_TOKEN`) and `install.sh` calling the platform's
   `~/ops/infra/observability/install-alloy-app.sh`. `ops-dashboard` generates the tree from the
   manifest. This directory is what makes "move this app to its own server" a seven-step procedure.
5. **`no-console` lint** — the logger module is the only place `console.*` is allowed.

Values to collect at scaffold time (by NAME, through `secrets-intake`, never echoed):
`SENTRY_DSN` · `SENTRY_ENVIRONMENT` · `POSTHOG_*` · `GRAFANA_URL` + `GRAFANA_SA_TOKEN`, plus the
manifest inputs — app slug, surfaces, environments + hostnames, unit prefix + `SyslogIdentifier`,
timers, integrations. Full table: `observability` → "Values the setup skills collect".

## Skill index

Being stood up alongside this one (the domain teachers): `backend-postgres-box`, `backend-box-deploy`, `backend-auth-service`, `backend-file-storage`, `backend-realtime-sse`, `backend-email`.

Existing: `cloudflare-api` (DNS/tunnel API recipes) · `secrets-intake` (credential handling — everything lands in `~/.config/<slug>/*.env`, mode 0600, never in CI or the repo) · `deploy-verify` · `sandbox-verify` · `supabase-local` (legacy local Supabase stacks + port-block table) · `k3s-deploy` (ONLY when k8s is justified — the hyperglot fleet deliberately left k3s) · `mobile-cicd-pipeline` (if the backend serves native apps).

## Supabase-exit quick map

One line each; full playbook in the domain skills. **Lift path (smallest diff): keep Postgres RLS and run standalone PostgREST against the box cluster — supabase-js clients keep working with a swapped URL** — then peel pieces off at leisure.

| Supabase piece | Replacement on the box |
|---|---|
| GoTrue (auth) | inline jose/bcrypt auth (`backend-auth-service`); Google = verify id-tokens against the 3 client IDs |
| PostgREST (`.from()`) | standalone PostgREST (keep-RLS lift), or rewrite onto SQL/ORM with per-request `set_config('request.jwt.claims', …)` |
| RPCs (`.rpc()`) | keep as Postgres functions behind PostgREST, or port to `/v1/*` routes |
| Storage buckets | disk + signed URL paths (`backend-file-storage`) |
| Realtime | one SSE endpoint (`backend-realtime-sse`) |
| Edge functions (Deno) | Node routes in the app — plain TS, swap `Deno.env.get` → `process.env` |
| pg_cron + Vault + pg_net | systemd --user timers curling the endpoint with a server-side bearer — the Vault dance existed only because Supabase cron can't hold secrets |

## Worked example (new app "acme")

```sh
ss -ltn | grep 54390 || true                    # 1. port free?
# 2. DB (backend-postgres-box): role acme + db acme on 127.0.0.1:5641 → ~/.config/acme/api.env
# 3. service (backend-box-deploy): ~/prod/acme checkout, acme-api.service + acme-tunnel.service,
#    setup-cloudflare.sh HOSTNAME=app-acme.laserfocused.ee SERVICE=http://localhost:54390
systemctl --user enable --now acme-api acme-tunnel && loginctl enable-linger justin
curl -fsS https://app-acme.laserfocused.ee/health   # 9. deploy-verify
```

## Box invariants (never violate)

- **DB is loopback-only** — `127.0.0.1:5641` (native PG) and every Supabase db port. The tunnel carries ONLY the app's HTTP port; never tunnel or expose a DB.
- **Server-data apps never go on Cloudflare Workers** (error-1003 loop). Workers/Pages = static or fully-external-backend only.
- **Absolute node path in every unit**: `/home/justin/.nvm/versions/node/v22.22.2/bin/node` (or the `~/prod/.node` symlink) — `/usr/bin/node` is v18 and nvm is a shell function systemd never sees.
- **`loginctl enable-linger justin`** or user units die on logout.
- **NODE_ENV trap**: `~/.zshrc` exports `NODE_ENV=development` — build with `env -u NODE_ENV` (Next) and `npm ci --include=dev` (devDeps get dropped under NODE_ENV=production).
- Secrets: `~/.config/<slug>/*.env` (0600) via `secrets-intake` — never in the unit file, the repo, or GitHub Actions.
- Tunnels are remotely-managed (`config_src=cloudflare`): no `~/.cloudflared`, no local config.yml; `TUNNEL_TOKEN` in an EnvironmentFile, never a CLI arg.
- `~/code` = dev tree, `~/prod` = production — nothing hand-copied between them.

## Gotchas

- Watchdog timers must start only `inactive` units, never `failed` ones — hammering a failed unit defeats start-limit self-heal.
- `/health` must answer unauthenticated at BOTH `/health` and `/v1/health`, or probes 401 and you hunt a phantom credential bug.
- Native PG port is **5641**, not 5432 — deliberately non-standard; `pg_lsclusters` confirms.
- The Supabase 5461X block is shared by two cowork checkouts — only one stack runs at a time.
- Backups are the step everyone skips: rkfitness still owes its nightly timer. Install it at setup, not "later".
