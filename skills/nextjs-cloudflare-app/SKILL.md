---
name: nextjs-cloudflare-app
description: Scaffold and deploy Justin's canonical web app - Next.js 15 on Cloudflare Workers via @opennextjs/cloudflare, with @supabase/ssr auth, Tailwind v4 + shadcn, and the 2-file CI set. Use when the user says "scaffold a next app", "new web app", "next on cloudflare", "opennext", "deploy to workers", or starts a new laserfocused web product.
---

## DECISION GATE — read this FIRST (which deploy path?)

**Does this app have a server-side backend that touches LOCAL/SERVER data — a local Supabase, a DB, or a process on THIS box?**

- **YES → DO NOT USE THIS SKILL's Worker path.** Host the Next app **on the server**: `next start` on a port + a `systemd --user` unit + a cloudflared tunnel `app-<slug>.laserfocused.ee → localhost:<port>`, and reach Supabase directly at `127.0.0.1`. This is what ops / lift99 / hyperglot / mjcode already do. Jump to **[Server-host variant](#server-host-variant--localserver-data-apps)** below. The DB stays **loopback-only (127.0.0.1)** — never tunneled or publicly exposed.
- **NO — backend is FULLY EXTERNAL (paid cloud Supabase) or the app is static → use the Cloudflare-Workers / OpenNext path** documented in the rest of this file.

**Why a Worker can't front a local backend (o2o error 1003):** a Worker runs on Cloudflare's edge. If its server-side `fetch()` calls back to a tunnel on the *same* Cloudflare account (orange-to-orange), Cloudflare refuses the loop with **error 1003**. Worker↔VPC bindings only paper over the wrong architecture. The Worker-edge model works for myarchitectai / coworking **only because their Supabase is external paid cloud** — the edge never needs to reach back into this box. Lift that template WITHOUT that precondition and you get 1003. (Binding rule, Justin 2026-07-09.)

---

# Next.js on Cloudflare Workers (canonical app template)

> **external-backend-only.** Everything below the gate is the Worker/OpenNext path for apps whose backend is fully external (paid cloud Supabase) or static. If your app touches local/server data, STOP and use the [Server-host variant](#server-host-variant--localserver-data-apps).

Copy, don't invent. Golden repos on disk:
- `/home/justin/code/worktrees/coworking-app/cfsetup` — bare scaffold snapshot (+ `DEPLOY.md`, the full runbook)
- `/home/justin/code/coworking-mng-not-shit/app` — the same template grown into a real app (most recent conventions win)

This is the CURRENT stack (2026-06). Do NOT average in hyperglot's Vite+zustand SPA (previous generation) or myarchitectai (inherited: pnpm/prettier/Vercel — none of that is his pattern).

## The stack (pinned, with the why)

| Piece | Choice | Why / evidence |
|---|---|---|
| Framework | **Next `^15.5` — PINNED `<16`** | Next 16 renames middleware→proxy and forces Node runtime; `@opennextjs/cloudflare` can't bundle Node middleware → undeployable. Documented in `app/src/middleware.ts` + cloudflare/workers-sdk#13755. Re-check before unpinning. |
| Runtime | React 19, TS `strict: true`, `src/` + `@/*` alias | create-next-app defaults, tsconfig excludes `supabase/functions` (Deno) |
| Styling | Tailwind **v4** via `@tailwindcss/postcss` — CSS vars in `globals.css`, **no tailwind.config** | |
| Components | shadcn, `components.json` style **`base-nova`** (+ `@base-ui/react`), lucide, cva/clsx/tailwind-merge, `tw-animate-css` | Verify `npx shadcn init` still emits base-nova — recent combo, only in the two coworking repos |
| Theme/toast | `next-themes` + `sonner` | next-themes is why `keep_names: false` (below) |
| Auth | `@supabase/ssr` triple `src/lib/supabase/{client,server,proxy}.ts` + **Edge `src/middleware.ts`** calling `updateSession` | Copy all 4 files from coworking-mng-not-shit/app. Matcher excludes static assets AND `.well-known` (App/Universal Links must not 3xx) |
| Structure | Route groups `(auth)/(app)/(manage)/(public)`; server actions as colocated `actions.ts` per route group; `error.tsx` + `not-found.tsx` | No client fetch libs (no react-query) in greenfield |
| Tests | vitest for pure logic colocated `src/lib/*.test.ts`; Playwright e2e in `e2e/` | |
| Deploy | `@opennextjs/cloudflare` → Cloudflare Workers | `open-next.config.ts` = `defineCloudflareConfig({})` — add R2 cache only when ISR is needed |

## Repo shape

```
<slug>/            # product workspace repo, GitHub org LaserFocused-ee
  app/             # Next app (everything above)
  landing/         # separate Astro 6 + Tailwind 4 static site (own worker.js — different template)
  docs/  brand/    # as needed
  CLAUDE.md
```

npm + package-lock (never pnpm/yarn), `.nvmrc` = `22`, flat `eslint.config.mjs` bridging `next/core-web-vitals` + `next/typescript` via FlatCompat with ignores for `.next/.open-next/.wrangler/.backups/out/build/supabase/functions` (copy from coworking-mng-not-shit/app). **NO prettier, NO husky.** Commented `.env.example` with explicit "server-only, NEVER exposed" split (copy `app/.env.example`).

## wrangler.jsonc (verbatim template — every comment is load-bearing)

```jsonc
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "<slug>-app",
  // Pin the laserfocused account so deploys are non-interactive (the API token can see two accounts).
  "account_id": "e9adf716c7d13735e158a045298fe26f",
  "main": ".open-next/worker.js",
  // esbuild's keep_names (default true) injects a `__name` helper that leaks into stringified
  // inline scripts (e.g. next-themes' pre-hydration theme script) → "__name is not defined" in the
  // browser console on every page. https://opennext.js.org/cloudflare/howtos/keep_names
  "keep_names": false,
  "compatibility_date": "2026-06-02",
  "compatibility_flags": ["nodejs_compat", "global_fetch_strictly_public"],
  "assets": { "directory": ".open-next/assets", "binding": "ASSETS" },
  "observability": { "enabled": true },
  // Runtime env for the Worker. The Edge middleware creates a Supabase client at REQUEST time,
  // and OpenNext does NOT build-inline NEXT_PUBLIC_* into the middleware chunk — without these
  // as runtime vars the middleware throws "URL and Key are required" and EVERY route 500s.
  // All three are public (anon key ships to browsers; RLS guards data).
  "vars": {
    "NEXT_PUBLIC_SUPABASE_URL": "<https://xxx.supabase.co>",
    "NEXT_PUBLIC_SUPABASE_ANON_KEY": "<anon key>",
    "NEXT_PUBLIC_SITE_URL": "https://<slug>.laserfocused.ee"
  },
  // laserfocused.ee zone is in this account → custom_domain auto-creates the proxied DNS
  // record on deploy. No DNS API call needed. (Zone id e62515b34e1fa778bc574d10abd178ec.)
  "routes": [{ "pattern": "<slug>.laserfocused.ee", "custom_domain": true }]
}
```

Sources: keep_names + vars comments from `coworking-mng-not-shit/app/wrangler.jsonc`; account_id + routes from `coworking-mng-not-shit/landing/wrangler.jsonc`; auto-DNS claim from `worktrees/coworking-app/cfsetup/DEPLOY.md`.

## Deploy

```json
"cf-build": "opennextjs-cloudflare build",
"preview":  "opennextjs-cloudflare build && opennextjs-cloudflare preview",
"deploy":   "opennextjs-cloudflare build && opennextjs-cloudflare deploy"
```

- Needs `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` — both already exported under those exact names in `~/.zshrc` (~line 506), so wrangler picks them up with no mapping. Non-interactive shells that skip .zshrc won't have them. `account_id` is also pinned in wrangler.jsonc.
- **On this server: `env -u NODE_ENV npm run deploy`** — NODE_ENV=development in ~/.zshrc breaks `next build`.
- workers.dev subdomain is `justin-e9a`; with Supabase auth, add `https://<worker>.justin-e9a.workers.dev/**` and `https://*-<worker>.justin-e9a.workers.dev/**` to the Supabase redirect allow-list (per DEPLOY.md).
- Push-to-main deploys use Cloudflare Workers Builds git integration — a one-time dashboard OAuth connect (human step, can't be done via API). For prototypes skip it and `npm run deploy` directly.
- Verify with the deploy-verify skill; **Cloudflare replaces 5xx response bodies** — return API errors as 4xx (lift99 lesson).

## Supabase

Local-first with per-project custom ports — follow the **supabase-local** skill (unique `546XX` block, `npx supabase` always). npm scripts: `db:start/db:stop/db:status/db:reset` + `"db:types": "supabase gen types typescript --local > src/lib/supabase/database.types.ts"`. Prod = Supabase cloud; migrations applied by the Supabase GitHub integration on merge to main (no migration GHA).

## CI — exactly 2 workflows

`ci.yml` (lint + tsc + vitest + build; NEXT_PUBLIC_* as repo **Variables** not Secrets) and `e2e.yml` (Playwright vs an **ephemeral local Supabase** spun up in the runner — never prod; the `supabase status -o env` quote-stripping eval is load-bearing). Both green on the first PR with zero secrets configured. Verbatim templates: [references/ci-workflows.md](references/ci-workflows.md). No deploy GHA — deploys ride Cloudflare's Git integration. If one is ever wanted, gate every step on the token secret existing (`::warning`-skip until it does); there is no template for it in this skill (references/ci-workflows.md carries `ci.yml` + `e2e.yml` only).

## Gotcha checklist (all have bitten)

- Next pinned `<16` (OpenNext Node-middleware gap) — see middleware.ts comment before touching.
- `keep_names: false` or next-themes breaks every page with `__name is not defined`.
- NEXT_PUBLIC_* must be in wrangler `vars` (runtime) or every route 500s.
- `env -u NODE_ENV` for any `next build` on this box.
- Middleware matcher must exclude `.well-known` (app-link files reject 3xx).
- Playwright against pages with persistent SSE: `waitUntil: 'load'`, never networkidle.
- 5xx bodies are swallowed by Cloudflare — surface errors as 4xx.
- Dev port: pick a unique `-p 30XX` (coworking uses 3007) — many dev servers coexist on this box.

---

## Server-host variant — local/server-data apps

Use this when the [gate](#decision-gate--read-this-first-which-deploy-path) said YES. Same Next app; **skip `@opennextjs/cloudflare`, wrangler.jsonc, and the Worker `vars`/routes entirely.** The app runs as a long-lived `next start` process on this box; a cloudflared tunnel puts it on `app-<slug>.laserfocused.ee`. Supabase is reached at `127.0.0.1:<api-port>` — no anon-key-in-wrangler dance, RLS + loopback are the boundary.

**DB stays loopback-only.** The local Supabase binds `127.0.0.1` and is NEVER tunneled or exposed. Only the Next app's HTTP port goes through the tunnel. (This is why the JWT-rotation / demo-key-probe layer in the supabase-local skill is NOT needed for the normal case.)

### 1. Build + run

```jsonc
// package.json — no cf-build/preview/deploy scripts here
"build": "next build",
"start": "next start --hostname 127.0.0.1 --port <port>"
```

`NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:<api-port>` (and the local anon key) live in the app's gitignored `.env` / the systemd unit's `Environment=`, not in any wrangler config. Build on this box with `env -u NODE_ENV npm run build` (NODE_ENV=development in ~/.zshrc breaks `next build`).

### 2. systemd --user unit

Model: `/home/justin/ops/infra/ops-web.service` (verbatim pattern below). `systemctl --user enable --now`, `loginctl enable-linger justin` so it survives logout.

```ini
# ~/.config/systemd/user/<slug>-app.service   (symlink from the repo's infra/ like ops does)
[Unit]
Description=<slug> app (Next.js, 127.0.0.1:<port>)
After=default.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
WorkingDirectory=/home/justin/code/<slug>/app
Environment="PATH=/home/justin/.nvm/versions/node/v22.22.2/bin:/usr/local/bin:/usr/bin:/bin"
Environment=NODE_ENV=production
# .env holds NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:<api-port> + local anon key
EnvironmentFile=/home/justin/code/<slug>/app/.env
ExecStart=/home/justin/.nvm/versions/node/v22.22.2/bin/node /home/justin/code/<slug>/app/node_modules/next/dist/bin/next start --hostname 127.0.0.1 --port <port>
Restart=always
RestartSec=2
RestartSteps=6
RestartMaxDelaySec=120

[Install]
WantedBy=default.target
```

### 3. Tunnel ingress → the port

Point `app-<slug>.laserfocused.ee` at `http://localhost:<port>`. Copy `/home/justin/code/mjcode/scripts/setup-cloudflare.sh` (creates/reuses the tunnel, PUTs the ingress, points proxied DNS at `<tunnel-id>.cfargotunnel.com`, prints the run token) — change `HOSTNAME`, `TUNNEL_NAME`, and set `SERVICE="http://localhost:<port>"` (mjcode is k3s so it uses an in-cluster service URL; for a systemd app use `http://localhost:<port>`). Or drive the same three API calls via the **cloudflare-api** skill. Run the cloudflared connector for the tunnel token (a `cloudflared` systemd --user unit or the token fed to your run script).

Verify with the **deploy-verify** skill: the live `app-<slug>.laserfocused.ee` must return the new artifact, and confirm the DB port is NOT reachable off-box.

## Observability (required)

Read `observability`; `observability-sentry` for the init details, `observability-posthog` for events.

- **`instrumentation.ts`** (server + edge `register()`), **`instrumentation-client.ts`** (browser),
  and **`onRequestError`** exported from `instrumentation.ts` — without the last one, a React Server
  Component throw is never reported. Add `app/global-error.tsx` too.
- **The DSN is baked at build time** (`NEXT_PUBLIC_SENTRY_DSN`), so the build must source the same env
  file the runtime uses. Same trap as `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`: a build with a different
  env than the unit produces a silently un-instrumented deploy.
- **Session replay is prod-only behind a DOUBLE gate** — a build-time check (`NODE_ENV`/an explicit
  release flag) AND a runtime check on the host. Ship a unit test that asserts
  `startSessionRecording` is NOT called when either gate is false; the dev-recording leak is the
  expensive mistake here.
- **A typed `analytics.ts`** — the event union IS the taxonomy, so a typo is a type error. PostHog
  **cannot rename an event**; names are irreversible, so the list gets reviewed before the first
  send. Client events are INTENT, server events are TRUTH (`invoice_paid` comes from the webhook,
  never from a browser).
- **`no-console: 'error'`** in the ESLint config, with the logger module as the only exception. On
  the Edge runtime pino does not load — middleware writes one `JSON.stringify` line through that
  same module, not a bare `console.log`.
- **`/api/health`** returning `{ ok, release }`, plus a `manifest.yaml` entry for the unit.
