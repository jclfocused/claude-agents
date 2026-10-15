---
name: deep-qa-pass
description: Run a deep, persona-driven QA pass on any app — define personas, distil the repo's own design/copy contract into a yardstick, fan out parallel real-browser lanes that judge behaviour AND content AND copy AND localization AND design, triage findings against the yardstick, fix in worktrees behind PRs, then codify every real defect as a Playwright regression test. Also covers API/service E2E and how to test endpoints whose responses come from an LLM. Triggers on "deep test the app", "thoroughly test", "QA pass", "test it like a real user", "find bugs in the app", "/deep-qa-pass", and any request to build E2E tests from exploratory findings. Scope: exploratory QA of a running app. For a pre-merge architecture/data/permissions/billing review of a branch, use `full-stack-e2e-review`.
---

## Required design dialogue

Before making or accepting any new branding, visual or UX/UI decision in this work, read and follow [design-dialogue](../design-dialogue/SKILL.md). Sol 6.1 (`gpt-6.1-sol`) and Opus 5.5 (`claude-opus-5-5`), both at least **xhigh**, must exchange proposals, respond to each other and agree on the same decision; Fable 5.1 (`claude-fable-5-1`, xhigh) then reviews and makes the final decision, and may call an audible (overrule, redirect or send back) whenever it judges fit. This includes building concept boards and later revisions, not just final review. It applies in Codex and Claude, including direct calls and delegated work. Research and faithful execution of a decided specification can proceed; unresolved design choices return to the pair. A participant already inside the dialogue responds through its coordinator and does not start another pair. Sol 6.1 and Opus are equal peers in the dialogue: neither leads or owes deference to the other. Either may reject the other’s proposal and criticize it bluntly with reasons; the coordinator only relays evidence and records outcomes. Do not manufacture agreement.

# Deep QA pass

A repeatable method for testing an app the way a demanding user would, then turning what you find
into regression tests. Proven on HyperGlot's web SPA, 2026-07-29/30 (found a ~12% auth-email failure
that had shipped to production and that no unit test could have caught).

**The core idea:** exploratory judgement finds defects that assertions cannot, because it can judge
*content correctness*, *copy quality* and *whether a screen serves a human*. Automated tests then
lock in what exploration found. Doing only the second half gives you a suite that passes while the
product is bad.

---

## Phase 0 · Ground yourself before touching anything

1. **Pick the target environment, deliberately.** A real dev/staging stack is best. If there isn't
   one, testing production is legitimate — but say so, get the user's agreement, and record the gap.
   Do not assume "the ports are listening" means "there is a usable stack": a stack needs seeded
   data, a frontend build pointed at it, and reachability from CI.
2. **Health-check every backing service first** and record the result. This is what lets you
   attribute a 5xx to a real app bug later instead of arguing about it.
3. **Provision test accounts per persona**, one per lane, so concurrent lanes cannot corrupt each
   other's state. Store the shared password in a `0600` file outside the repo (e.g.
   `~/.config/<app>/qa.env`), never in a commit, never in a workflow return value.
4. **Find out what blocks unattended signup.** Email verification enforcement, CAPTCHA, SMS, payment
   — each needs a route around it. If the user's mail is reachable (Gmail MCP), you can do full
   round-trip email flows; that is how you test verification and password reset for real.
5. **Check the observability you already have.** Sentry/Loki/PostHog will hand you real defects for
   free. Read them before guessing.

## Phase 1 · Build the yardstick (do NOT skip — this is what stops false positives)

Have one agent read the repo's design system, screen specs, copy/voice rules, brand docs, i18n
source, and any `PLACEHOLDERS.md`-style build checklist **in full**, and distil them into a single
brief that includes a clearly marked section listing:

- what is **already done** (so nobody re-reports a closed item), and
- what is **deliberately unfinished or by design** (so nobody reports it as a bug).

Every later lane reads this file before judging anything, and cites its sections in the `expected`
field of each finding.

> Why this matters: on the HyperGlot pass, the first "major finding" was that four of five locales
> only translated ~13 of ~492 strings. The contract said that exact fallback was **deliberate**.
> Without the yardstick, the headline finding would have been noise — and the credibility of the
> whole report would have gone with it.

Judgement rule: when the contract prescribes something specific and the live app differs, that is a
finding. When the contract is silent, judge against what a paying user would expect, and say which
of the two you are doing.

## Phase 2 · Personas, before any testing

Personas drive everything downstream. Each must be **useful for testing**, not marketing fluff:

- identity, and the real motivation that brings them to the app
- their language(s), device, and context of use (phone on a commute vs laptop at a desk)
- friction tolerance — what makes them quit
- **the journey**: the exact ordered sequence of screens and actions, with the expectation at each
  step, from first landing through their success moment and into repeat use
- **what would be broken for them specifically** — failures invisible to other personas
- success criteria

Cover at minimum: a first-time visitor who has never signed up; the least-capable legitimate user
(absolute beginner / low literacy / assistive tech); a returning power user; a user in a non-default
locale; every distinct role (admin, teacher, member); and a user hitting a paywall or quota.

Add a **cross-cutting checks** section that applies on every screen regardless of persona:
i18n completeness, empty/loading/error states, keyboard and screen-reader access, mobile widths,
copy tone, and locale-correct numbers/dates/currency.

## Phase 3 · Fan out exploratory lanes in a workflow

One workflow agent per lane. **Each lane MUST pass its own browser `session` name** — that is what makes
the sweep parallel at all. Chunk concurrency (2–3 at a time) because each lane holds a real browser.

**But named sessions are NOT full isolation, and this bit a real run.** Concurrent lanes were observed
sharing `localStorage`, so one lane's signed-in account surfaced inside another lane's browser and
produced a false finding ("visiting /today silently completes onboarding") which only died because that
lane re-tested it against a clean control account. Defend against it explicitly in every lane brief:

- **The fix that actually works: shadow the app's storage keys per tab.** A lane that hit this solved it
  by using `page.addInitScript` to redirect the app's auth/session `localStorage` keys into
  `sessionStorage`, which is per-tab and therefore genuinely isolated. Do this in the lane's setup rather
  than fighting the symptom — otherwise another lane's sign-in silently overwrites the refresh token
  mid-flow and the page renders someone else's account.
- Make each observation **atomic** — sign in and assert inside a single browser call, rather than
  trusting a session to persist across calls.
- **Verify identity server-side** before believing any authed observation: call the "who am I" endpoint
  and confirm the account is the one this lane owns.
- Give each lane its **own account**, never a shared one, so contamination is detectable rather than
  merely plausible.
- Require lanes to **discard, and say they discarded**, anything they cannot tie to a verified account,
  and to refute a suspicious finding with a clean control before reporting it.

A lane that reports contamination honestly is doing its job. A lane that silently reports the artefact
poisons the whole triage, because a cross-session artefact looks exactly like a real bug.

Split lanes by surface and persona, e.g.: signup funnel · sign-in and recovery · routing and guards ·
localization · responsive and accessibility · commercial/paywall surface · the core product loop ·
each distinct role · the deepest interactive component · theme and visual conformance.

Give every lane a **structured findings schema** so results merge: title, severity
(blocker/major/minor/polish), category (bug/copy/i18n/design/ux/a11y/perf/security/content), route,
detail, repro steps, expected (citing the contract), actual, evidence, suggested fix, likely files.
Also require a `coverage` field stating what they actually exercised and what they could not reach —
without it you cannot tell thorough from lucky.

Every lane also runs a **UX/UI review** of the screens it touched, at 1440 and 390, against the
[UX/UI rubric](../sandbox-verify/references/ux-ui-review.md) (Justin, 2026-10-15: browser checks
always judge how it looks, not only whether it works). Findings use its BLOCKING/NON-BLOCKING split
(category `design`/`ux`/`a11y`); a pass report carries the `## UX/UI review` section and a
`UI VERDICT: APPROVE|CHANGES` line, and the overall `VERDICT: APPROVE` needs both. The orchestrator
Reads the screenshots itself before reporting a UI change done.

Tell lanes to judge **content correctness**, not just mechanics. On a language-learning app a
linguistically wrong exercise matters more than a spacing nit. This generalises: wrong data beats
wrong pixels, always.

## Phase 4 · Triage against the yardstick

Merge and deduplicate, then split genuine defects from by-design behaviour, rank by real user impact,
and pull every **security** finding out separately and prominently (open redirect, session surviving
sign-out, cross-account data, account enumeration). For each defect name the likely files and the
shape of the fix, and state the assertion a regression test should make.

## Phase 5 · Fix in worktrees, behind PRs, on a ledger

- One agent per fix, each in **its own git worktree branched off `origin/main`**, so concurrent fixes
  and any still-running sweeps never collide. Worktrees ALWAYS live under the canonical root —
  `${WORKTREE_ROOT:-/home/justin/worktrees}/<repo>/<branch-slug>` (slug = branch with `/`→`-`).
  `~/code` holds main clones only; never create a worktree there or beside one.
- In a containment-workspace layout (a root repo whose sub-directories are independent repos), the
  Agent tool's `isolation: "worktree"` forks the **workspace** repo, which does not contain the
  sub-repos. Create the worktree inside the target sub-repo instead, at the nested canonical path:
  `git -C <workspace>/<subrepo> worktree add -b <branch> "${WORKTREE_ROOT:-/home/justin/worktrees}"/<workspace>/<subrepo>/<branch-slug> origin/main`.
- Every fix carries a regression test that **genuinely fails without the fix** — verify by reverting
  the fix and watching it fail. Require the agent to prove this, or you get test theatre.
- Run the repo's own gate (lint, test, build) and **verify the output yourself**. A skipped suite is
  not a green suite.
- Keep a **ledger** file: finding, severity, repo, branch, PR, status. Record the deploy trigger for
  each repo so you know whether merging ships anything.
- Hold merges until the pass completes, unless told otherwise.

## Phase 6 · Codify the findings as regression tests

Write the browser suite from what exploration found — each real defect becomes one assertion. Two
tiers, because they answer different questions:

- **Fast, deterministic, every PR:** the built frontend with the network stubbed. Catches routing,
  guards, copy, i18n, empty/error states, accessibility. Runs in minutes on a clean runner.
- **Full-stack, nightly or on a self-hosted runner:** real services, seeded data. Catches integration
  and contract drift.

Auth in specs: provision users via the API at setup and reuse a stored session, rather than driving
the login form in every spec.

**Give parallel spec-writing lanes separate worktrees, or exclusive file ownership.** Fix agents each get
their own worktree (same canonical root as Phase 5: `${WORKTREE_ROOT:-/home/justin/worktrees}/<repo>/<branch-slug>`); it is tempting to let several spec lanes share one because they are "only adding
files". That was a mistake in a real run: five lanes wrote `e2e/` concurrently, and the consequence was
not merge conflicts but something worse — **no lane could verify a green gate**, because the failure set
churned under them (two reds in one spec, ten minutes later two different reds elsewhere). One lane also
force-ran a copy of another's file mid-run. If lanes must share a tree, assign each an exclusive file and
finish with a **single consolidation pass** that waits for quiescence (poll `git status` and mtimes until
nothing changes for several minutes) and then owns lint, the full suite in the CI container, and any
visual-baseline re-blessing.

**Re-blessing a visual baseline is a decision, not maintenance.** A baseline goes stale for two reasons —
an intended change, or drift. Regenerate inside the CI container so the bytes match what CI compares, and
state in the commit which of the two it was and that the diff was reviewed. A blanket re-bless is how
visual testing stops meaning anything.

**Shrink the unverifiable set before you allowlist it.** When a mechanical check cannot decide N cases, the
lazy move is to allowlist all N. Read them first: on a real run, 90 "undecodable" pronunciation hints turned
out to be **65 instances of one convention** plus a second small pattern — teaching the checker both took the
undecodable count from 71 to 7 **with zero new disagreements**, which is the evidence the added rules are
*correct* rather than merely quieter. An allowlist hides; understanding removes. Whatever genuinely remains
should be an **exact-set assertion with a per-entry reason**, so a new unverifiable case fails the suite and
names itself instead of drifting up silently.

**Distil a big dataset into a small committed fixture.** A gate that needs a 1.4 GB download, or python, or a
dataset path, is a gate that only runs on the machine that built it. Keep the heavyweight extractor as a
refresh script and commit the small derived artefact (5 KB in that case) so the check runs anywhere with no
setup — then the gate belongs to the repo, not to its author.

**In a shared worktree, `git add <path>` — never `git add -A`.** A broad add sweeps other lanes' in-flight
files into your commit. It happened twice in one run; the second time it silently attributed a whole
verification harness to an unrelated commit message.

**Force-run every `test.fixme` periodically.** A fixme that has quietly started passing is worse than a
missing test: it advertises a defect that no longer exists, so the next person either deletes real
coverage or chases a ghost. Rewrite `test.fixme(` → `test(` in a throwaway copy and run it. Every fixme
should fail; any that passes is either a fixed defect (delete the fixme) or an assertion too weak to fail
(fix the assertion). A real run caught a stale fixme this way within minutes of the fix merging.

## Phase 7 · API and service E2E

Per service, drive black-box request/response coverage from the service's own spec (OpenAPI/zod), not
from a hand-written list — that is how you get *every* route rather than the ones someone remembered.
Assert status, body shape, authorization boundaries, and error shapes; include the failure paths.

## Testing endpoints whose responses come from an LLM

Non-determinism does not prevent reliable tests; it changes what you assert. Tier by cost:

1. **Invariants (per PR, free, deterministic).** Assertions true of ANY valid generation: schema
   conformance, length bounds, required fields present, no leaked prompt/system text, answer-key
   distribution fairness, n-gram overlap between answer and source (catches verbatim lifting),
   locale/typography lint, and domain-specific checks (e.g. a morphology/speller pass for language
   content).
2. **Record/replay cassettes (per PR).** Record real provider responses once, replay them for
   determinism. Assert the *parsing and handling* logic, which is where most bugs actually live.
   Cassettes rot — re-record on a schedule and diff.
3. **Failure paths (per PR, cheap, usually untested and usually broken).** Provider timeout, refusal,
   malformed JSON, truncation mid-object, rate limit, empty response. Force each with a stub.
4. **Judge model (nightly, not per PR).** A strong model grading output quality. Too slow, costly and
   variable to gate a PR; excellent as a trend signal.
5. **Offline eval bench (on demand).** A fixed dataset with scores you track across prompt changes.

Structured output/schema forcing buys shape, never correctness — a schema-valid answer can still be
wrong. Temperature 0 buys much less determinism than people expect from hosted models; do not build
a suite that depends on byte-identical output.

If the codebase already has a content quality gate in production, mirror it: the gate defines what is
already guaranteed, so tests should prove what the gate does **not** cover.

## Hard-won gotchas

- **Retry every agent lane on API 529/Overloaded** with escalating backoff. A bare fan-out loses every
  lane to one overload burst. Wrap `agent()` and retry until it lands.
- **`page.on(...)` does not exist** in the betterwright runtime. Capture console errors with
  `page.addInitScript` installing an `error`/`unhandledrejection` hook onto `window`, then read it via
  `page.evaluate`.
- **Lazy-loaded routes keep the previous DOM mounted** for seconds after a client-side navigation, and
  `waitUntil: 'networkidle'` does not cover it. Always wait for the expected new content explicitly,
  and treat unconfirmed navigation as unverified — otherwise you will "test" the previous page.
- **Read the email, don't assume it.** Transactional mail is a real surface with real bugs. The
  HyperGlot pass found a MIME/quoted-printable mangling that killed ~12% of verification links —
  visible only by reading a delivered message and comparing the link against the same token printed
  elsewhere in the same mail.
- **Prove a diagnosis with a probe** before fixing a layer. One deliberate send with crafted payloads
  identified the exact trigger (multipart, not text-only) in two minutes and stopped a fix in the
  wrong place.
- Never report a documented placeholder as a new bug; never let a lane skip reading the yardstick.
