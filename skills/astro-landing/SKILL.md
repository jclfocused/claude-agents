---
name: astro-landing
description: Justin's landing-page template - Astro 6 + Tailwind v4 static site deployed as a Cloudflare Worker with a tiny hand-written worker.js. Use when building a landing page, marketing site scaffold, or "astro landing", or when adding a form endpoint / custom domain / video to one of the existing stamps (laserfocused, cowork, yommayo, ulrika, hyperglot-reader).
---

# Astro Landing (Cloudflare Worker + static assets)

The template stamped 5x: `laserfocused/landing`, `coworking-mng-not-shit/landing`, `johanna-landing`, `ulrika/landing`, `hyperglot-workspace/landing-reader`. Copy from a real stamp, don't reinvent — `/home/justin/code/laserfocused/landing` is canonical (apex domain + form + pagefind), `johanna-landing` is the cleanest minimal stamp.

Content/design is NOT this skill's job — the **taste-skill** applies to what the page says and looks like. This skill is the scaffold + deploy mechanics.

## Stack (exact)

- **Astro 6** (`astro ^6.3+`), static output (default), `site:` set in `astro.config.mjs`, `integrations: [sitemap()]` always.
- **Tailwind v4 via PostCSS**, NOT `@tailwindcss/vite` — the Vite plugin is incompatible with Astro 6's rolldown-vite bundler (withastro/astro#16542, documented in `laserfocused/landing/astro.config.mjs`). `postcss.config.mjs` = `@tailwindcss/postcss` plugin only. No `tailwind.config` — v4 CSS-vars style.
- **Self-hosted fonts** via `@fontsource-variable/*` (per-brand pairs; laserfocused = Inter/Space Grotesk/JetBrains Mono). Never Google Fonts CDN — the CSP is `'self'`-locked.
- **`@astrojs/sitemap` + `sharp`** as deps; `@astrojs/check` + `typescript` + `wrangler` as devDeps.
- **tsconfig**: `extends: "astro/tsconfigs/strict"` + `strictNullChecks: true` + `@/*` → `src/*` alias.
- `.nvmrc` = `22`, npm + package-lock (never pnpm/yarn in greenfield). Optional: `pagefind` for search (laserfocused, ulrika) — then `"build": "astro build && pagefind --site dist"`.

## worker.js (~100 lines, hand-written, no framework)

`main: worker.js` runs first (`run_worker_first: true`), everything not handled falls through to `env.ASSETS.fetch(request)`. The three jobs it exists for:

1. **Security headers** on responses — full CSP locked to `'self'` (`'unsafe-inline'` for Astro's inlined scripts, `'wasm-unsafe-eval'` + `worker-src blob:` only if pagefind), HSTS, nosniff, X-Frame-Options, Referrer-Policy. See `laserfocused/landing/worker.js:39-61`.
2. **www→apex 301** (and a `/sitemap.xml → /sitemap-index.xml` 301 alias — Astro's sitemap integration emits `sitemap-index.xml`, tools look for `sitemap.xml`).
3. **Optional one form-POST endpoint** (`/api/contact`, `/api/subscribe`, `/api/demo`) → Resend email to the owner. Pattern: honeypot field (`company_website`) silently accepted; email regex validation; `!env.RESEND_API_KEY` → 503 with a graceful message; Resend failure → 502. Secret set via `wrangler secret put RESEND_API_KEY`.

Full annotated template + Resend handler: [references/worker-template.md](references/worker-template.md).

**Video gotcha (Range/206)**: Workers static assets NEVER return 206, and Safari refuses to play video from servers that ignore Range requests. If the page has `<video>`, the worker must slice the asset and answer Range requests itself for `/media/*` — working implementation in `hyperglot-workspace/landing-reader/worker.js` (suffix ranges, 416 handling). Copy it verbatim.

## wrangler.jsonc conventions

```jsonc
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "<slug>-landing",
  // Pin the laserfocused account so deploys are non-interactive (the API token can see two accounts).
  "account_id": "e9adf716c7d13735e158a045298fe26f",
  "main": "worker.js",
  "compatibility_date": "<scaffold date>",
  "assets": {
    "binding": "ASSETS",
    "directory": "./dist",
    "run_worker_first": true,
    "not_found_handling": "404-page"
  },
  "observability": { "enabled": true }
  // No custom-domain routes yet — <apex> still serves the old site. The Worker
  // serves on *.workers.dev until Justin decides to cut the domain over. When ready:
  //   "routes": [
  //     { "pattern": "<apex>", "custom_domain": true },
  //     { "pattern": "www.<apex>", "custom_domain": true }
  //   ]
}
```

- **Domain-undecided convention**: the `routes` block lives COMMENTED OUT in the file with the cutover steps, until the domain decision is made (see `johanna-landing/wrangler.jsonc`). Until then the site serves on `<name>.justin-e9a.workers.dev` (+ a preview URL per deploy).
- **`custom_domain: true` auto-creates the proxied DNS record on deploy** when the zone is in this account (laserfocused.ee zone works this way — `cowork.laserfocused.ee` precedent for subdomains). No DNS API calls needed.
- **Failure mode**: if the token lacks zone-level Workers Routes permission on the target zone (happened with hyperglot.io), declaring the route fails the deploy — attach the domain once via the Workers Domains API instead and leave routes out (documented in `hyperglot-workspace/landing-reader/wrangler.jsonc`).

## Deploy

```bash
npm run deploy        # = "npm run build && wrangler deploy" (build = astro build [+ pagefind])
```

- `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` are exported in `~/.zshrc` (~line 503) — non-interactive shells that skip .zshrc won't have them, and Node lives at `/home/justin/.nvm/versions/node/v22.22.2/bin`.
- No GHA, no dashboard, no Pages — Cloudflare Pages is the LEGACY pattern; Workers + static assets is current.
- After deploy: verify per the **deploy-verify** skill (fetch the live URL, confirm the change is served). worker.js changes need a deploy to test — locally (`astro preview`/tailscale) the worker doesn't run and forms degrade gracefully.

## Repo shape

Usually `landing/` inside the product workspace repo (`laserfocused/landing`, `ulrika/landing`, `coworking-mng-not-shit/landing`) — standalone repo only when the landing IS the product (`johanna-landing`). Gitignore `dist/`, `.astro/`, `.wrangler/`, `node_modules/`.

## Observability (required)

Read `observability`; a landing page's share is two lines of init and one honest privacy page.

- **Errors** — `@sentry/cloudflare` in `worker.js` via `Sentry.withSentry(env => ({ dsn: env.SENTRY_DSN, ... }))`.
  DSN is a Worker secret (`wrangler secret put SENTRY_DSN`), never in `wrangler.jsonc`.
  Same caps as everywhere: `tracesSampleRate` low, `enableLogs: false`, `sendDefaultPii: false`.
- **Analytics** — PostHog **cookieless** (`persistence: 'memory'`, `person_profiles: 'identified_only'`),
  loaded only when `PUBLIC_POSTHOG_KEY` is set, and **never on a page the privacy policy says is
  untracked**. If you add analytics, edit `privacy.astro` in the same commit — a marketing site that
  promises "no analytics" and then loads a tracker is the one observability bug that is also a legal
  one. Cookieless + an honest privacy page beats a cookie banner at this data level.
- **Worker observability** stays enabled in `wrangler.jsonc` (`"observability": { "enabled": true }`) —
  it is free and it is the only log the Worker has.
- The landing is a **surface in the product's `manifest.yaml`** (`kind: cf-worker`, its routes, a
  probe on `https://<domain>/`), not a thing with its own dashboard.
