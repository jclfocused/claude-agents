---
name: field-encryption
description: House pattern for per-person (per-subject) envelope encryption of personal-data fields and backups with crypto-erasure, run through the shared lfos-erasure broker and OpenBao in backup-service. Use when deciding whether an app should adopt field-level encryption, when adopting it, or when writing any feature, query, migration, list endpoint or API request in an app that already has it (Kommonz is the reference). Triggers - "field encryption", "encrypted mode", "per-person keys", "crypto-erasure", "envelope encryption", "erasure broker", "lfos-erasure", "live decrypt", "decryptMany", "protected embed", "declared wire", "wire shape", "lookup token", "blind index", "backup data policy", "OpenBao", "restore drill", "switch-on", "cutover rehearsal", "LF-DATA-026", "LF-DATA-027", or a slow list endpoint in an encrypted app.
---

# Field-level encryption with crypto-erasure

Each person (a **subject scope**) gets their own data key. Protected fields are stored as
authenticated envelopes in live rows and in backups. The subject keys are wrapped by one OpenBao
transit key. Erasing a subject destroys that subject's key, so every copy of their data becomes
unreadable, including old backups. The app never holds the wrapping key. It calls the
**lfos-erasure broker** (`/opt/lfos-erasure/current`, source in `/home/justin/code/backup-service`)
to encrypt, decrypt, erase and mint lookup tokens.

Standards: `LF-DATA-026` (erasure policy; crypto optional, off by default) and `LF-DATA-027`
(coding rules for encrypted units) in `/home/justin/code/lf-standards/docs/standards/05-data-layer.md`.
Personal-data inventory work (what counts, where it flows) is the `personal-data-protection` skill;
this skill covers the encryption pattern itself.

## 1. Should this app adopt it?

The default is **no**. Every app declares an erasure policy under LF-DATA-026, but crypto-erasure
is an explicit opt-in (`crypto_erasure: true` in `erasure-policy.json`).

Adopt when all of these hold:
- the app stores personal data about individuals (members, customers, contacts) who can ask to be erased;
- backups are kept long enough that "delete the row" does not remove the person from them in reasonable time;
- the app runs on this box's stack (a Postgres + API unit that can reach the broker socket).

Do not adopt for: apps with no personal data, apps whose data is only organization/company records,
throwaway or demo apps, static landings, or apps where ordinary deletion and short backup retention
already meet the obligation. Document stores are a separate opt-in from database fields.

The costs to weigh: a broker dependency on every protected read (the broker must be up), a gateway
that only serves declared read shapes, backup policy upkeep on every migration, a rehearsed
switch-on, and key-store recovery duties.

## 2. How to adopt it

Follow the integration guide, then use Kommonz as the worked example.

- **Integration guide:** `/home/justin/code/backup-service/docs/INTEGRATING-AN-APP.md`. If your
  checkout does not have it yet, use these docs from the same folder:
  `live-data-key-service.md` (live encrypt/decrypt, batch route, caller contract),
  `identity-lookup.md` (lookup tokens), `postgres-erasure-backups.md` (backup export/restore with
  erasure), `erasure-service.md` (broker, registry, caches, erasure timing),
  `openbao-operations.md` (snapshots, unseal-share escrow, isolated restore),
  `kommonz-r2-enrollment.md` (enrolling a project).
- **Reference implementation (Kommonz API, `/home/justin/code/coworking-mng-not-shit/api`):**
  - `src/personal-data/rest-gateway.ts`: the data API gateway in front of PostgREST.
  - `src/personal-data/profile-embed-contracts.ts`, `wire-hydration.ts`: declared protected embeds and wires.
  - `src/personal-data/private-payloads.ts` (`hydratePrivateFields`), `decrypt-cache.ts`
    (`limitedReaders`, `cachedDecrypts`, `countDecrypts`), `runtime.ts`: batched, cached decrypt.
  - `src/personal-data/member-budget.ts`: per-operation allowance.
  - `config/backup-data-policy.json`, `config/backup-data-policy.encrypted.json`, `config/staged/*.backup-policy.json`,
    `scripts/check-backup-data-policy.mjs`, `.github/workflows/backup-policy.yml`: backup policy and its CI check.
  - `scripts/cutover/*`, `scripts/rehearse-cutover.mjs`, `docs/PERSONAL-DATA-CUTOVER-RUNBOOK.md`: rehearsal and switch-on.
  - Workspace doc `docs/PERSONAL-DATA-MIGRATION.md`: the inventory and migration status.

Adoption order: declare the policy → enroll the project with the broker → classify every table
and column in both backup policies → move protected fields behind the gateway with declared read
shapes → enroll existing rows → rehearse on a restored copy at the shipping commit → switch on under
a deploy freeze → walk the app → set up escrow and the monthly restore drill.

## 3. Coding rules for an app that has it

These are LF-DATA-027. Each one closes a failure we have already had.

**Read shapes are declared, and tests build the exact request.**
- A protected field is readable only through a declared contract: select list, embeds, filters,
  `order`, `limit`, `offset`. The gateway rejects anything else with `400`/`501`. That is correct
  behaviour, not a bug to route around.
- When you add or change a page's query, update its declared wire in the same change.
- The wire-shape test builds the request **exactly as the call site does**: same column order, same
  order/limit/offset params. A test that builds a tidier version of the request proves nothing.
  (A page added an ordering parameter its wire did not declare, and Finance failed on every load.)

**Decrypt once per response, in a batch, only what you show.**
- Collect every envelope the response needs, then make one batch call through
  `LiveDataClient.decryptMany` / `hydratePrivateFields` / `pooled()`. The client chunks at the broker
  cap: 256 items, 256 KiB of plaintext, 512 KiB body per request.
- Never call `decrypt()` inside a per-row loop, a per-row authorization check or a per-row query.
  (The payers list made about 1,840 single decrypts and took 8–17 s. Batched, 1,057 values take
  about 85 ms.)
- Decrypt only the fields the response returns. Do not decrypt source payloads "in case".
- Read lists in sets: one query per table, caller authority checked once per request.
- Cache decrypted values keyed by scope + coordinates + stored envelope, with a lifetime of 60 s or
  less (the broker's out-of-process erasure bound). Do not build a longer-lived plaintext cache.
- Check the `http request` log line: `decrypt_calls`, `decrypt_items`, `decrypt_cache_hits`. For a
  list, add a test that broker calls stay constant as rows grow.

**No protected values through the raw data API, logs or analytics.**
- Protected columns are not granted to the PostgREST roles. Clients go through the gateway, which
  authorizes first and decrypts second.
- Exact-match lookup across the whole app (login by email, uniqueness, invite matching) uses lookup
  tokens (`createLookupClient`, see `identity-lookup.md`).
- Substring search and sorting on a protected field run server-side over the caller's
  authorized, tenant-bounded set after one batch decrypt (Kommonz `profiles.ts` `read`). Never add a
  plaintext shadow column, and never send a decrypted list to the client to filter.
- Decrypted values never go into logs, Sentry events or PostHog properties.

**Every migration updates both backup policies, and child rows share the parent's scope.**
- A migration that adds a table or column classifies it in `backup-data-policy.json` **and**
  `backup-data-policy.encrypted.json` (plus any staged overlay) in the same PR. CI
  (`check-backup-data-policy.mjs`) fails otherwise.
- A child row of a subject-scoped or omitted parent carries the parent's subject scope, so erasure,
  export and restore treat them together. (Invitation child rows with a different scope forced a
  switch-on rollback.)

**Test with production-shaped data, then use the app.**
- Fixtures use production-shaped counts and relationships: hundreds of members per org, and rows
  that point at existing confirmed logins.
- After switching a surface on, walk its pages in the running app. API probes alone missed
  page-level failures.

**Rehearse at the shipping commit and freeze deploys.**
- Rehearse the switch-on or cutover on a restored copy at the exact commit that ships.
- Freeze deploys of affected units from rehearsal to switch-on.
- Pin "today" in date-dependent assertions, or make sure the rehearsal does not cross UTC midnight.
- A broker release that changes the client needs a `commons-api` (or consuming API) restart.

**Key-store recovery is escrowed and drilled.**
- Keep the OpenBao unseal material in at least two independent places (today: 1Password, the Mac
  and the server). Keep it separate from erasable subject keys, which are never escrowed.
- Run a monthly isolated restore drill: restore a snapshot on an isolated host, decrypt a synthetic
  subject, confirm an erased subject stays unreadable. Alert when the drill is overdue.

## 4. Before you open the PR in an encrypted app

- [ ] New or changed query → declared wire updated, wire-shape test builds the exact request.
- [ ] No `decrypt()` in a loop; list endpoint makes a constant number of broker calls.
- [ ] Only displayed fields decrypted; no new plaintext cache over 60 s.
- [ ] Migration → both backup policies (and staged overlays) updated; CI check green.
- [ ] Child rows share the parent's subject scope.
- [ ] No decrypted value in logs, errors or analytics.
- [ ] Fixtures are production-shaped; the page was used in the running app.
