---
name: observability-sentry
description: The error sink — Sentry SaaS org `laserfocused` (EU, de.sentry.io). Bootstrap a project + DSN + alert rules + cron monitor through the API, init per runtime (Express, Next, Edge, Cloudflare Worker, Cocoa, Android), capture rules and fingerprints, releases with source maps / dSYM / ProGuard in our own runners, and the cost-caps checklist. Use when adding error reporting to a new app or surface; when an integration, job or route needs a deliberate capture; when a Sentry issue fans out into hundreds of duplicates; when stack traces are unreadable or unminified; when setting up a cron monitor; when asked about DSNs, sampling, spike protection, PAYG budget or "why is Sentry expensive". Extends the sentry:* plugin skills — it does not restate them. Not for logs (observability-logs) or product events (observability-posthog).
---

# Sentry — the error sink

One SaaS org for the estate: **`laserfocused`**, org id `4511814930006016`, region **EU** —
every API call and every upload goes to `https://de.sentry.io`, not `sentry.io`. Data location is
fixed at org creation.

Credentials: `~/.config/sentry.env` — `SENTRY_ORG`, `SENTRY_AUTH_TOKEN` (`sntryu_…`). Take them by
name via `secrets-intake`; never print a value. Per-app DSNs live in `~/.config/<app>/*.env`.

The eight `sentry:*` plugin skills (`sentry-instrument`, `sentry-setup-releases`,
`sentry-fix-stack-traces`, `sentry-create-alert`, `sentry-debug-issue`, `sentry-snapshots-cocoa`, …)
all apply now that every surface is SaaS. **Use them for mechanics; this skill is the box-specific
policy layer on top.**

## The caps checklist — a hard gate, every time

Verify before and after any Sentry change. Getting this wrong is a bill, not a bug.

- [ ] PAYG / on-demand budget **$0** — exhausted budget ⇒ data is DROPPED, not billed.
- [ ] Spike protection **on, with notifications** (off by default; covers errors/spans/attachments —
      **not** replays, logs or metrics).
- [ ] `enableLogs: false` on every SDK. Defaults **true** on JS SDK ≥ 10.71.0 and bills per GB. Loki
      is our log store.
- [ ] `tracesSampleRate: 0.05`. **The span is the billing unit** and one Next request emits dozens —
      tracing, not errors, is what blows a quota.
- [ ] `profileSessionSampleRate: 0` — profiling has no included quota on any plan.
- [ ] `replaysSessionSampleRate: 0` / `replaysOnErrorSampleRate: 0` — only 50 Sentry replays are
      included and they are not covered by spike protection. **PostHog owns replay.**
- [ ] `sendDefaultPii: false` — the default sends identity, bodies and query params.
- [ ] Inbound filters on; `ignoreErrors` + `ignoreTransactions` set (health, JWKS, `NEXT_REDIRECT`,
      `ResizeObserver`, browser-extension `denyUrls`).
- [ ] No reserved volume purchased.
- [ ] Read it back: `GET /api/0/customers/laserfocused/` and assert `onDemandMaxSpend == 0`.

Plan today is **Developer**. Team upgrade, PAYG budget and spike protection are **UI-only, Justin's
action** — not doable with the API. Per-DSN rate limits and Delete & Discard are Business+.

## Bootstrap a project through the API

```sh
set -a; . ~/.config/sentry.env; set +a
API=https://de.sentry.io/api/0
AUTH="Authorization: Bearer $SENTRY_AUTH_TOKEN"

# 1. project (one per surface: <app>-api, <app>-web, <app>-landing, <app>-ios, <app>-android)
curl -sX POST "$API/teams/$SENTRY_ORG/<team>/projects/" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"name":"kommonz-api","slug":"kommonz-api","platform":"node-express"}'

# 2. DSN  (keys endpoint; store via secrets-intake, never echo)
curl -s "$API/projects/$SENTRY_ORG/kommonz-api/keys/" -H "$AUTH" | jq -r '.[0].dsn.public'

# 3. alert rule
curl -sX POST "$API/projects/$SENTRY_ORG/kommonz-api/rules/" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"name":"New issue","conditions":[{"id":"sentry.rules.conditions.first_seen_event.FirstSeenEventCondition"}],
       "actions":[{"id":"sentry.rules.actions.notify_event_service.NotifyEventServiceAction","service":"webhook"}],
       "frequency":30,"actionMatch":"all","environment":"production"}'

# 4. verify the caps
curl -s "$API/customers/$SENTRY_ORG/" -H "$AUTH" | jq '{plan:.planTier, onDemandMaxSpend}'
```

The four alert rules we run: **new issue** · **regression** · **error-rate spike** (spike protection)
· **cron monitor missed**. All route to the i2a webhook, deduped on `fingerprint` — see
`observability-triage`.

**Cron monitors: exactly ONE is included on any plan.** It goes to the money job
(`accounting-drain`). Every other timer is watched by a Loki staleness rule instead. ⚠️ A Sentry
monitor is **created by its first check-in** — a timer held inactive by a gate has no monitor, so
Sentry cannot alert on a miss it has never seen. Run
`node api/scripts/check-cron-monitors.mjs` before arming any money timer; it proves which of the two
routes actually exists.

## Init per runtime

**Express 5 (Node)** — `api/src/instrument.ts`, loaded by the unit as
`node --import ./dist/instrument.js dist/index.js`. It MUST evaluate before express/pg are imported;
ESM auto-instrumentation needs the loader hook and a plain top-level import cannot patch a module
already in the graph.

```ts
export const sentryEnabled = !!process.env.SENTRY_DSN && process.env.NODE_ENV === 'production';
if (sentryEnabled) Sentry.init({
  dsn: process.env.SENTRY_DSN, environment: ENVIRONMENT, release: `kommonz-api@${RELEASE}`,
  sampleRate: 1.0, tracesSampleRate: 0.05, profileSessionSampleRate: 0,
  enableLogs: false, sendDefaultPii: false,
  integrations: [Sentry.expressIntegration(), Sentry.postgresIntegration()],
  ignoreErrors: ['AbortError', /^Non-Error promise rejection captured/],
  ignoreTransactions: ['GET /health', 'GET /v1/health', 'GET /.well-known/jwks.json'],
  beforeSend,   // below
});
```

**Next 15** — `app/src/instrumentation.ts` (`register()` branched on `NEXT_RUNTIME`, plus
`export const onRequestError = Sentry.captureRequestError` — the ONLY hook that sees a throw inside a
Server Component, Route Handler or Server Action) and `app/src/instrumentation-client.ts`
(`export const onRouterTransitionStart = Sentry.captureRouterTransitionStart`). Shared options live in
`app/src/lib/sentry-options.ts`. Edge gets `tracesSampleRate: 0` — a span per middleware-matched
request is the cheapest way to spend the whole quota. Browser events ride `tunnelRoute` (`/monitoring`
on our own host) so an ad-blocker cannot eat the stream.

**Cloudflare Worker** — `@sentry/cloudflare`, `Sentry.withSentry(env => ({...}), handler)` in
`landing/worker.js`. DSN is a Worker **secret** (`wrangler secret put SENTRY_DSN`); `nodejs_compat`
must be in `compatibility_flags`; release comes from the `SENTRY_RELEASE` var the deploy script sets.

**Cocoa / Android** — `ios/Sources/Telemetry.swift`, `android/.../Telemetry.kt`. Keep the two in
lockstep. **The build is the gate, never a literal**: the DSN rides a build setting into the generated
Info.plist / `BuildConfig` exactly the way `API_BASE_URL` does, and the SDK starts only when it is
non-empty — so a developer's simulator build sends nothing. Environment is derived
(`DEBUG` → `development`; release → `testflight` when the receipt is `sandboxReceipt`, else
`production`). A hardcoded `"production"` files every simulator and TestFlight crash as prod.
`attachScreenshot`/`attachViewHierarchy` stay **off** — a screenshot of a member portal is member data.

## Capture rules

1. **Capture at the DECISION POINT, not in the wrapper.** `withOutbound` logs; only the caller knows
   it gave up. Capturing inside the HTTP wrapper = one issue per retry attempt = a muted channel.
2. **Always fingerprint.** Without one, the first partner outage is 500 issues.
3. **Never put an id in a fingerprint** — no org, invoice, request or user id. That is the Loki label
   mistake, mirrored.

```ts
capture(err, {
  tags: { route, 'http.request.method': req.method, org_id },   // ids are TAGS
  fingerprint: [route, err?.name ?? 'Error'],                   // never an id
  userId,                                                        // id only, never an email
});
fail('job finish', err, { tags: { job }, fingerprint: ['job', job, err.name], fields: {…} });
```

`capture()` returns the event id; write it into the log line as `sentry_event_id`. It already tags
`surface`, `request_id` and `posthog_session_id` from the AsyncLocalStorage context — that is the
triage join key, do not remove it.

Fingerprint recipes: outbound failure → `[integration, op, err.name]`; job failure →
`['job', job, err.name]`; unhandled route throw → `[route, err.name]`; webhook signature failure →
`['webhook', integration, 'signature']`.

Scope: use `Sentry.getIsolationScope()` for per-request tags — the http integration forks one per
request, so a tag set there cannot leak onto a concurrent request. `Sentry.withScope()` for a
one-off capture.

## `beforeSend` — the scrubber

```ts
const SECRET_PATH = /\/(pms\/webhook|join|auth\/confirm|invite)\/[^/?#]+/g;   // live credentials in a URL
beforeSend(event) {
  if (event.request) { delete event.request.data; delete event.request.cookies;
    delete event.request.headers; delete event.request.query_string;
    if (event.request.url) event.request.url = scrub(event.request.url); }
  if (event.user) event.user = { id: event.user.id };            // id only, never email
  if (event.message) event.message = scrub(event.message);
  for (const v of event.exception?.values ?? []) if (v.value) v.value = scrub(v.value);
  // contexts (except `trace`) through redact(); breadcrumb messages through scrub()
  return event;
}
```

Drop bodies/headers/cookies **wholesale** first, then scrub what is left. None of it debugs anything
the ids don't, and all of it is GDPR surface.

## Releases and symbols

`<project>@<sha>` everywhere, and it must be the **same string** the logs and PostHog use. Bake it at
build time (`api/scripts/stamp-release.mjs`; `NEXT_PUBLIC_RELEASE` for web;
`kommonz-ios@<short>+<build>` / `kommonz-android@<version>+<code>` on mobile).

**Upload symbols inside the build that produced the artefact** — never as a later step:
- **Next**: `@sentry/nextjs` source maps, `withSentryConfig` with `hideSourceMaps`.
- **iOS**: dSYM upload as a step in `.github/workflows/release-ios.yml` (our own `cowork-mac` runner).
- **Android**: the Sentry Gradle plugin's only job is uploading the R8 mapping. Release is minified,
  so **no mapping = no readable stack**. Needs `SENTRY_AUTH_TOKEN` in the env; without it the build
  still succeeds and silently skips the upload. ⚠️ **`url` must be `https://de.sentry.io`** or the
  upload 404s.
- CI needs its **own** copy of the auth token as a repo secret.

Owned by `mobile-cicd-pipeline` for the mobile half.

## Prove the wiring

```sh
# api — a deliberate throw, then read the event back
curl -s http://127.0.0.1:54630/health           # confirm the service is up first
# ios (debug build only)
xcodebuild … SENTRY_DSN=<dsn> SENTRY_ENVIRONMENT=verify
xcrun simctl launch <udid> ee.laserfocused.cowork -sentryPing
# android (debug build only)
./gradlew :app:assembleDebug -PSENTRY_DSN=<dsn> -PSENTRY_ENV=verify
adb shell am start -n ee.laserfocused.cowork/.MainActivity --ez sentryPing true
# read back
curl -s "https://de.sentry.io/api/0/projects/laserfocused/<project>/events/" -H "$AUTH" | jq '.[0].eventID'
```

A claim of "Sentry is wired" without an event id read back is unverified.
