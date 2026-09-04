---
name: observability-posthog
description: Product analytics — PostHog Cloud EU. Project bootstrap + billing limits + replay trigger groups through the API, the double-gated prod-only session replay init, masking, identify/group, the typed taxonomy file, the "an event name can never be renamed" rule and the ratification step it forces, and the mobile analytics-only gating. Use when adding a user-facing action that needs an event; when creating or naming an analytics event; when setting up PostHog on a new app or surface; when asked about session replay, masking, funnels, group analytics, distinct ids, autocapture, or "are we tracking this"; and before flipping any POSTHOG key on. Not for error reporting (observability-sentry) or server logs (observability-logs).
---

# PostHog — product analytics

**Cloud EU** (`https://eu.posthog.com`, ingest `https://eu.i.posthog.com`). Org **LaserFocused OÜ**.
Two projects per product: `<app>` (prod) and `<app>-dev`. Kommonz = `265773` / `265774`.

Credentials: `~/.config/posthog.env` — `POSTHOG_API_HOST`, `POSTHOG_PERSONAL_API_KEY` (`phx_…`).
Per-app project tokens (`phc_…`) live in `~/.config/<app>/web.env`. Never print a value.

## ⛔ The standing gate

**The prod key is held as `POSTHOG_KEY_PENDING` until Justin ratifies the taxonomy doc**
(`docs/POSTHOG-TAXONOMY.md`, 27 events). Every helper — web client, web server, iOS, Android, landing
— is a no-op without a key, deliberately. Do not rename that variable, do not paste a key into a
`.env`, do not "just test it in prod" on your own initiative.

Why the gate exists: **PostHog cannot rename an event.** Their own docs say it "requires updating
every existing event in the database"; the workaround is grouping the old and new names with an
Action, forever. It is the only irreversible decision in the whole observability plan. Treat a new
event name like a migration you can never roll back.

## Bootstrap through the API

```sh
set -a; . ~/.config/posthog.env; set +a
API=https://eu.posthog.com/api
AUTH="Authorization: Bearer $POSTHOG_PERSONAL_API_KEY"

# 1. project, in the right ORG (the key's @current org is not necessarily the one you want)
curl -s "$API/organizations/" -H "$AUTH" | jq '.results[] | {id, name}'
curl -sX POST "$API/organizations/<org-id>/projects/" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"name":"kommonz"}'                       # repeat for kommonz-dev

# 2. project token (this is NEXT_PUBLIC_POSTHOG_KEY / PUBLIC_POSTHOG_KEY)
curl -s "$API/projects/<id>/" -H "$AUTH" | jq -r '.api_token'

# 3. BILLING LIMITS at the free-tier boundary — /api/billing/ is PER ORG, set the org context
curl -sX PATCH "https://billing.posthog.com/api/billing/" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"custom_limits_usd":{"product_analytics":0,"session_replay":0}}'

# 4. replay trigger groups + the `organization` group type: project settings, below
```

A managed reverse proxy (`e.<domain>`) is **not available on this org** — `/api/projects/<id>/
proxy_records/` 404s. Use a same-origin rewrite instead (`/ingest` → `eu.i.posthog.com` in
`next.config.ts`), or direct EU ingest on a static site.

## The prod-only replay gate — four enforcements, none a toggle

A dashboard toggle is invisible to the repo and cannot satisfy the requirement.

```ts
export const PROD_HOST = 'app.kommonz.com'
export function isProdSurface(host?: string, siteUrl?: string): boolean {
  return siteUrl === `https://${PROD_HOST}` && host === PROD_HOST
}

export function initPostHog(key?: string, host?: string, siteUrl?: string): boolean {
  if (!key || isE2E) return false                 // gate 4: no key in dev + off under Playwright
  posthog.init(key, {
    api_host: '/ingest', ui_host: 'https://eu.posthog.com',
    defaults: '2026-05-30',                        // pin SDK behaviour
    capture_pageview: false,                       // the router hook owns pageviews
    respect_dnt: true,
    person_profiles: 'identified_only',            // anonymous traffic stays cheap and less personal
    autocapture: false,                            // ON for the landing only
    disable_session_recording: true,               // ALWAYS true at init …
    tracing_headers: [PROD_HOST, 'api.kommonz.com'],
    session_recording: { maskAllInputs: true, maskTextSelector: '*' },
    capture_performance: { network_timing: false },
    loaded: (ph) => ph.register({ release: RELEASE, surface: 'web', env: 'production' }),
  })
  if (isProdSurface(host, siteUrl)) posthog.startSessionRecording()   // … started only in prod
  return true
}
```

1. `disable_session_recording: true` at init + an explicit gated `startSessionRecording()`.
2. **Build-time** gate on `NEXT_PUBLIC_SITE_URL` — **never `NODE_ENV`**, this box exports
   `development` globally.
3. **Runtime** gate on `window.location.host` — any build that sources `~/.config/<app>/web.env`
   (a local prod build, a branch through `deploy.sh`) inlines the prod constant and would otherwise
   start recording from a laptop.
4. No key in the dev env at all, plus a separate non-prod project.

**Export the gate function so a unit test can drive it directly** rather than asserting on a mock's
side effects. The test is not optional — without it the requirement is a comment. See
`app/src/lib/observability.test.ts` and `verify-observability`.

PostHog must be **off under Playwright** (`NEXT_PUBLIC_E2E === '1'`) or every run pollutes prod
analytics and adds network flake to a suite capped at `workers: 3`.

## Sampling = trigger groups, not client config

In project settings (`posthog-js` ≥ 1.369.0): a **20% baseline** group with a 2s minimum duration,
plus **100%** groups on the `$exception` event trigger and on URL regexes for the money and conversion
paths (`/manage/finance`, `/billing`, `/checkout`, `/join`, the public directory). Sampling is a
deterministic hash of the session id — you choose how many, never which. Low baseline + 100% where it
matters is what makes replay a support tool rather than a bill.

## Masking — the defaults are NOT safe

`maskAllInputs` defaults to true but **page text is UNMASKED by default**. That records member
rosters, invoice amounts and door credentials.

- Ship `maskTextSelector: '*'` (PostHog's own max-privacy preset).
- Add `ph-no-capture` to the members roster, finance rows, door-credential UI, the newsletter composer.
- Masking **cascades to children**, so `:not()` selectors do not work — un-mask via `maskTextFn`
  checking a data attribute.
- Keep OFF: network header/body capture, console capture, canvas recording.

## identify + group

- `posthog.identify(authUserId, { role })` — **the id, never an email, as the distinct id.**
- One group type: **`organization`**, key = org uuid. Properties: `name`, `plan`, `kind`,
  `member_count`, `is_listed`, `stripe_charges_enabled`, `city`.
- Call `group()` from wherever the app **already resolves the active org** — the org is not in the JWT
  (see the `org-scope-resolution` memory); do not add a second source of truth.
- ⚠️ **A backend event must pass `$groups` on EVERY capture** — the JS SDK's sticky `group()` does not
  reach the server — and it must be identified to associate with the group at all.
- Billing note: group analytics and identified events are **separately metered add-ons** (1M free
  each). Enabling groups is right; it is a meter, not a free flag.

## The taxonomy file

ONE typed file per repo so a typo is a type error (`app/src/lib/analytics.ts` is the reference).

```ts
export type AnalyticsEvent =
  | { name: 'booking_created'; props: { resource_type: string; duration_min: number; price: number; is_free: boolean } }
  | { name: 'invoice_payment_recorded'; props: { method: string; chained_to_books: boolean } }
  // …
export const ANALYTICS_EVENTS = [ … ] as const satisfies readonly AnalyticsEventName[]
```

Rules the types enforce:
- **`object_action`, snake_case, past tense.** Never `click_button`, never an interpolated name.
- **Properties are SCALARS ONLY and never PII**: no email, name, phone, address, door credential, or
  member-authored free text (a booking title is free text — send the duration, not the title).
- **Client events are INTENT; server events are TRUTH.** `invoice_paid` is fired by the Stripe
  webhook, never by a browser. Where both exist, use different names or the funnel double-counts.
- **Three clients, ONE taxonomy.** Web, iOS and Android must emit identical names or every funnel
  triple-counts — the same lockstep rule that governs `booking-grid.ts`.

Adding an event = add the union member + the `ANALYTICS_EVENTS` entry + a line in
`docs/POSTHOG-TAXONOMY.md`, then get it ratified before the first send (the D3-style step).

Server-side capture is one `fetch` to `${host}/i/v0/e/`, not `posthog-node` — a Server Action has
neither a long life nor a shutdown hook, so batching and flush-on-exit buy nothing. It carries
`$groups`, `surface`, `env`, `release`, and **swallows its own errors**: analytics never breaks a user
action.

## Mobile — analytics only

```kotlin
PostHogAndroid.setup(app, PostHogAndroidConfig(apiKey = BuildConfig.POSTHOG_KEY, host = BuildConfig.POSTHOG_HOST).apply {
  sessionReplay = false          // 2x the price, wireframe fidelity, half the free allowance
  captureScreenViews = false     // autocapture would invent names outside the ratified taxonomy
  captureDeepLinks = false
})
```

Same on iOS (`PostHogConfig`, `sessionReplay = false`, `captureScreenViews = false`). **The key ships
only in release/production builds** — TestFlight and TestApp.io builds get no key, so a tester cannot
write into the prod project. Each SDK starts only when its build-config value is non-empty.

## Landing — the one place autocapture is ON

Cookieless: `persistence: 'memory'` (no cookie, no localStorage) + `autocapture: true` +
`capture_pageview: true` + `disable_session_recording: true`, loaded via a **dynamic import** so
`posthog-js` is not even fetched without a key. That is what lets the privacy page say we set no
analytics cookies and lets the site ship with no consent banner.

⚠️ **Touching analytics on a public site means re-reading its privacy page.** Adding a processor
without editing the copy ships a false statement — PostHog Cloud EU and Sentry SaaS EU are new
processors of member-derived data.

## Funnels worth building

org activation (`org_created → member_invited → membership_activated → invoice_paid`) · demo → paid ·
booking (member vs guest) · event RSVP/ticketing · directory claim · invoice collection with
time-to-pay. Retention is measured on weekly active **orgs** (group retention), not users.
