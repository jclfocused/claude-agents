# Jev API contract, primitives, SDKs, commercial facts

Extracted 2026-09-20 from the research brief (`mem research search "jev typesafe"`), probe-verified against `jev-1.13.0`. Numbers are dated: re-verify limits/pricing before quoting them.

## 2. Programming model

### State

One state per request. `string | JSON object | array of text`. Text only — no images, audio or video. All questions in the request see the same state, and the state is ingested once and evaluated against every question **in parallel and in isolation**: one question's answer is never context for another. That property is the whole cost model (§5, fan-out) and it also means there is no context rot from adding questions.

English is the primary training language. CJK and others are accepted with explicitly lower accuracy. Accuracy also degrades as the state grows with content irrelevant to the decision — filter in code first, or use a cheap Noul as a relevance pre-filter.

Reference a nested state field from inside `instructions` with a **backticked dot-and-index path**: `` `support.tickets[0].message` ``. The docs state the backticks are load-bearing; a bare path may not bind.

### Questions

`questions` is a map of caller-chosen id → question object. **The id is never sent to the model** and plays no part in inference — all meaning must live in `instructions` and `criteria`. The id is only the key you read the answer back under. Namespacing ids (`field::metric`, `gate::key`) and filtering by prefix is the house pattern in the cookbooks.

| Type | Asks | `criteria` shape | Answer fields |
|---|---|---|---|
| `noul` | Is this statement true? | optional `{true?, false?}` | `noul` (0–1). **No `confidence`.** |
| `choice` | Which one of these options? | **object**: option key → description or `null` | `choice`, `probabilities` (map, sums to 1), `confidence` |
| `score` | Which level on this rubric? | **array**, index = level, ≥2 and ≤10 | `score` (float), `legend`, `probabilities` (level → p), `confidence` |

Types can be mixed freely in one request.

**Noul.** `noul` is P(true). Near 1 = strong yes, near 0 = strong no, ~0.5 = *uncertain*, never "medium level". For a spectrum use Score. Phrase so high = yes; a declarative statement ("the customer is requesting a refund") works as well as a question, and the docs suggest testing both. Optional `NoulCriteria(true=…, false=…)` clarifies what each side means.

**Choice.** Up to **255 options** — the API's hard cap ("A Choice question accepts up to 255 options", `/primitives/choice`). **Build against 240:** cookbooks run 182 and 218 comfortably and call ~240 the reliable ceiling; above that, narrow the field first (hierarchical / beam search, §5) rather than widening the option set. Option keys are the literal strings returned in `choice`. Descriptions may be `null` when the key speaks for itself — used when the option key is already present in the state (line ids, regex-found spans). Probabilities **always sum to 1**, so something always wins even when nothing fits: pair a ranking Choice with a separate existence Noul, or add an explicit `none` / `other` option.

**Score.** `criteria` is an ordered array; level number = array index from 0. `score` is the probability-weighted mean of the level numbers and lands **between** levels (1.035 on a 0/1/2 rubric). Compare with `>=`, never `==`. Normalize across scales of different lengths by dividing by `len(criteria) - 1`. Each level is judged independently — the model never sees a level's number or its neighbours, so comparative wording ("worse than the previous level") and numeric-only levels measurably degrade results (numbers-only: score 0.57 / confidence 0.35 vs 0.0 / 1.0 with descriptive levels on the same input). Rare extremes need their own level.

**Advanced entries.** `instructions`, each Choice option description, each Score level, and each side of `NoulCriteria` all accept `string | object | array | null` (the `EntryType`). Field names inside those objects (`question`, `focus`, `inspect`, `compare`, `what`, `not_for`, `examples`, `signals`) are **invented by you and are not reserved or validated** — the model sees key and value together. Nothing errors if you invent a key the model ignores, so bad structure fails silently as a quality regression. The documented convention is to use the *same* field names across all options of one Choice so the model can compare contrastively.

### Probability and confidence semantics

- `noul`, `choice.probabilities`, `score.probabilities` are calibrated probabilities. Contract: over a **population** of predictions, outcomes given p=0.2 occur ~20% of the time, 0.8 ~80%. This is never a guarantee about a single answer. Do not tell a user "the model is 84% sure about this case".
- `confidence` (Choice and Score only) is a 0–1 statistic derived from how **peaked** the distribution is. TypeSafe deliberately does not publish the formula and says you may compute your own from the raw probabilities. In v1 it is a new computation — preview's value was `1 − normalized Shannon entropy` and is still reproducible client-side if you want a stable definition.
- **`confidence` ≠ the winner's probability.** Sample: `billing` at p=0.84 with Choice confidence 0.596. Threshold on the field you actually mean. Cookbooks split on this: one abstains on `max(probabilities) < 0.60`, another gates on `confidence >= 0.9`.
- `confidence` is not accuracy. 1.0 only means all mass is on one outcome. The docs warn twice that a rubric edit raising confidence is not evidence it improved.
- Same `score` can come from very different distributions (1.0 = all on level 1, or half on 0 and half on 2). Read `probabilities` alongside `score`.

### Documented pitfalls

- **No structural invariants.** The same question as a Noul returned 0.22 while as a yes/no Choice returned `no` 0.99 / confidence 0.97. `refund` 0.72 and `not_refund` 0.47 sum to 1.19. Never carry a Noul threshold to a Choice, and never compute `P(x) = 1 − P(¬x)`. Choice is *relative* (which option wins); Noul is *absolute* (all can be low).
- **Cannot count**, and error grows with the size of the thing counted. Count by fanning out one Noul per item and summing in code.
- **Dates are read as text, not ordered quantities.** Extract date parts as Choices over closed sets (with an explicit "not stated" option) and do ordering/duration arithmetic in code.
- **Numeric representations are weak** — English colour names beat hex/RGB, high-level languages beat assembly. Prefer semantic representations.
- **Literal reading.** Write the exact condition and its boundary cases into `criteria`; split an ambiguous judgment into two literal questions.
- **Indirection and double negatives cost accuracy.** Name the relevant state fields explicitly.
- **State is not treated as hostile.** Injected instructions, misleading framing, or self-classifying text in the state can move the answer. Any injection-detection Noul you write is a signal, not a security boundary — the cookbook says so outright.
- **Contradictory instructions vs criteria** (a Noul whose `true` side describes "no") silently degrade.
- **Aliases move.** Every example pins `jev-latest`, which is a floating alias. Log the response's `model` field and pin `jev-1.13.0` if you tuned thresholds.

---

## 3. API contract

**Base URL** `https://api.typesafe.ai` (SDK default; overridable with `TYPESAFE_BASE_URL`).
**Auth** `Authorization: Bearer <API_KEY>` + `Content-Type: application/json`. Keys at `https://console.typesafe.ai/keys`.

**Endpoints — there are two.**
- `POST /v1/systemone` — the only inference endpoint.
- `GET /v1/models` — `{"models":[{name, description, release_date}, …]}`.

### Request (probe-verified)

```json
{
  "state": {"text": "The meeting is on Friday"},
  "model": "jev-latest",
  "questions": {
    "mentions_day": {"type": "noul", "instructions": "Does the text mention a day of the week?"},
    "topic": {"type": "choice", "instructions": "What is this text about?",
              "criteria": {"scheduling": "Times, dates, meetings", "billing": "Money, invoices", "other": null}},
    "specificity": {"type": "score", "instructions": "How specific is this statement?",
                    "criteria": ["Vague", "Somewhat specific", "Fully specific"]}
  }
}
```

All three top-level fields are required over raw HTTP. `model` is optional in the SDKs (the client default fills it); a raw curl without it returns 422.

### Response (probe-verified, 2026-09-20)

```json
{
  "model": "jev-1.13.0",
  "answers": {
    "mentions_day": {"type": "noul", "noul": 0.99},
    "topic": {"type": "choice", "choice": "scheduling", "confidence": 1.0,
              "probabilities": {"scheduling": 1.0, "billing": 0.0, "other": 0.0}},
    "specificity": {"type": "score", "score": 1.02, "confidence": 0.87,
                    "legend": {"0": "Vague", "1": "Somewhat specific", "2": "Fully specific"},
                    "probabilities": {"0": 0.03, "1": 0.92, "2": 0.05}}
  },
  "usage": {"input_tokens": 389, "output_tokens": 73}
}
```

The probe settles a docs contradiction: a Score answer **does** carry `probabilities` alongside `legend` and `confidence` (the quickstart's abbreviated sample omitted it), and a Noul answer carries
**only** `type` and `noul` — no confidence. `model` reports the versioned id that actually answered.

**Usage.** Only `usage.input_tokens` / `usage.output_tokens`. No cost, credit, quota or rate-limit fields; no billing headers observed. Python types both as `int | None`; JS types both as required `number` — null-check on the Python side. Request id is the `x-typesafe-request-id` header.

**Errors.** `401` missing/invalid key · `403` permission denied · `404` · `422` validation (body names the offending field) · `429` rate limit · `5xx` · `529 Overloaded` (non-standard — a hand-rolled retry list built on 503 will miss it).

**Retry policy.** Retry 429 and 529 with exponential backoff; both SDKs do so by default on `{408, 429, 500–599}` with `max_retries=2`, initial 500 ms, max 5 s, jitter 0.25, honouring `Retry-After` (JS caps a server-supplied delay at 60 s). JS `timeout` is 10 s **per attempt with no total budget** — worst case ≈ timeout × (retries+1) + backoff. Python has a real total budget: `RetryPolicy.timeout = 30.0` s per call, separate from `DEFAULT_TIMEOUT = 10.0` s per HTTP operation.

**Limits (docs; not observable from a response).**

| | |
|---|---|
| Context | 64k tokens per request **total** (state + all questions); **and** 32k for state + the single longest question |
| Questions/request | No documented cap — bounded only by the shared token budget (~32k ≈ 150k chars of English). **Build against ~80:** highest observed in docs is 78; 54 in one call is routine. Beyond that, measure before shipping |
| Choice options | 255 hard cap; **build against 240** |
| Score levels | 2 min, 10 max (11 returns a server error) |
| Rate limits | 250,000 tokens/sec **and** 1,200 requests/min — either trips 429; **scope undocumented** (see note) |
| Input | Text only |

- **Rate limits — the numbers are published, the unit of accounting is not.** `250,000 tokens per second / 1,200 requests per minute` is quoted verbatim from the Jev 1.13 model card (`/models`). **Nothing in the public docs says whether the bucket is per API key, per account, per organization or per model.** Verified 2026-09-20 against the models page, the API reference and the Python retry docs: the API reference says only "You have exceeded **your** rate limit" for `429` — second person, no scope noun. `llms.txt` indexes no pricing, plans, limits, keys or console page that could resolve it; key management lives behind the login at `console.typesafe.ai/keys`, which we cannot read unauthenticated.
- **No rate-limit headers are documented** — no `x-ratelimit-*` family on any doc page. The only documented feedback is `Retry-After` / `retry-after-ms`, which the SDKs honour "when the response carries one", i.e. not guaranteed present; `TypeSafeRateLimitError` surfaces exactly one field, `retry_after_ms`. Scope cannot be inferred from response metadata either — an observed 429 tells you a bucket was hit, not which bucket.
- Docs explicitly warn the limits "are adjusting dynamically… as upcoming large GPU deals land and we let in more users" and can change without notice; "Higher limits are available on custom and enterprise plans. Contact sales@typesafe.ai." Treat both the values and the scope as provisional.
- Cookbook practice caps client fan-out at 4–12 threads ("eight is already enough to hit a rate limit on a shared key") — there is no batch endpoint.

**Models and versions.** Live probe returned exactly two entries for this account: `jev-latest` ("The latest iteration of TypeSafe's System One Model: Jev", released 2026-09-10T18:38Z) and `jev-preview` ("A preview version of `jev-latest`: should be better in most ways", 2026-09-10T18:39Z). Both currently resolve to `jev-1.13.0`, which is the id echoed in every response. **Versioned ids are accepted by the `model` field even though `/v1/models` lists only aliases** — docs first ("Versioned IDs such as `jev-1.13.0` are accepted by the `model` field whether or not they appear in the list", `/models`), then confirmed by a separate probe call the same day: `"model": "jev-1.13.0"` → HTTP 200, body `{"model":"jev-1.13.0","answers":{"is_urgent":{"type":"noul","noul":0.95}},"usage":…}`. The four probe calls behind the request/response samples above sent `jev-latest` or no model at all. No fine-tuning, no LoRA, same weights for every account; domain fit comes from state + instructions/criteria + decomposition. A dedicated jaggedness page documents jev-1.13's nine failure modes (§2).

**Migration to v1** (from the preview `/preview/evaluation`): endpoint → `/v1/systemone`; `prompts` array → `questions` map; **`document` → `state`** (a request sending `document` now fails validation); per-type `options`/`levels` → unified `criteria`; `responses` array → `answers` map; `probability`→`noul`, `chosen`→`choice`, `expectation`→`score`; choice `probabilities` array → map; score `probabilities` is new; `usage.billing_units` → `input_tokens`/`output_tokens`; score levels may no longer be skipped; **confidence is a new computation — re-tune every threshold**. The old Python package `typesafe-client` (all 0.1.x/1.0.x) is dead — `evaluate()` became `system_one()`. Note the migration page itself (`/migrating-to-v1.md`) is live (200) but **absent from `llms.txt`** — an index-driven re-crawl will not find it, so fetch the path directly.

---

## 4. SDKs

Two official SDKs; no Go, Rust, Java, Ruby or .NET.

| | JS/TS | Python |
|---|---|---|
| Package | `@typesafe-ai/sdk` (also on JSR) | `typesafe-sdk` |
| Version verified today | **0.6.0** (installed clean, 1 package, 0 vulns) | **0.7.0** (2026-09-18) |
| Runtime | Node ≥ 20, ESM + CJS + `.d.ts` | Python ≥ 3.10 |
| Deps | **zero runtime deps** | httpx2, pydantic, pydantic-core, tenacity, typing-extensions |
| Install | `npm install @typesafe-ai/sdk` | `pip install typesafe-sdk` |

Do not install `typesafe-ai`: on npm that name is unpublished (404); on PyPI it is a redirect shim that just depends on `typesafe-sdk`. A third package, `system-one-adapter`, is a drop-in `TypeSafeClient` replacement backed by OpenAI/Anthropic, for A/B-ing Jev against an LLM.

**Version baseline for everything in §4.** JS `@typesafe-ai/sdk` **0.6.0** (2026-09-15) and Python `typesafe_sdk` **0.7.0** (2026-09-18) are the newest releases of each. Both took a breaking change at 0.6.0 (`Score.criteria` dict → ordered sequence); Python additionally swapped msgspec → pydantic at 0.7.0. **Nothing below is valid for ≤0.5.7.**

**Env vars** (both SDKs, precedence explicit option > env > default): `TYPESAFE_API_KEY` (required), `TYPESAFE_BASE_URL` (`https://api.typesafe.ai`), `TYPESAFE_DEFAULT_MODEL` (`jev-latest`), `TYPESAFE_LOG_LEVEL`. **On this box the key lives in `~/.config/jev/jev.env` as `JEV_API_KEY`** — a bare `new TypeSafeClient()` will throw here; pass the key explicitly or export `TYPESAFE_API_KEY`.

**Client construction.**
- JS: `new TypeSafeClient(config?)` — `apiKey`, `baseURL`, `defaultModel`, `timeout` (10000 ms, per-attempt), `retry`, `defaultHeaders`, `logger`, `logLevel`, `fetch`, `dangerouslyAllowBrowser` (default false — leave it false; it ships the key to every page visitor). Throws on missing key or unsupported runtime. Method `systemOne({state, questions, model?}, options?) → APIPromise<…>`, plus `models.list()`. `APIPromise` adds `asResponse()`, `withResponse()` (`{data, response, requestId}`) and `map()`.
- Python: `TypeSafeClient` / `AsyncTypeSafeClient`, kwargs-only (`api_key, model, retry, timeout, headers, transport, http_client, base_url`), usable as a (async) context manager. Method `system_one(state, questions, *, model=None, retry=None, timeout=None, extra_headers=None, extra_body=None, response_model=None)`. Responses are frozen pydantic models (`extra="ignore", strict=True`) exposing `answers`, `model`, `usage`, cached `nouls`/`choices`/ `scores`, `request_id` and `raw_http_response`.

**The three helper functions** build question objects so you never hand-write the `type` discriminator:
- JS: `choice(instructions, criteria)`, `noul(instructions? = null, criteria?)`, `score(instructions, criteria)`.
- Python: the classes `Choice(instructions=, criteria=)`, `Noul(instructions=, criteria=NoulCriteria(true=, false=))`, `Score(instructions=, criteria=[…])`. Raw dicts (`{"type": "noul", …}`) are also accepted and may be mixed with objects.

**Minimal working example** (probe-verified, JS, key by env-var name only):

```js
import { TypeSafeClient, noul } from "@typesafe-ai/sdk";

const client = new TypeSafeClient({ apiKey: process.env.JEV_API_KEY }); // else reads TYPESAFE_API_KEY
const res = await client.systemOne({
  state: { text: "The meeting is on Friday" },
  questions: { mentions_day: noul("Does the text mention a day of the week?") },
});
console.log(res.answers.mentions_day.noul); // 0.99
```

Answer types are inferred per question id, so `res.answers.mentions_day.noul` type-checks with no cast. Measured: 680 ms wall, byte-identical envelope to raw HTTP.

**Cross-SDK traps.** JS result has only `answers`/`model`/`usage`; Python adds `nouls`/`choices`/ `scores`/`request_id`/`raw_http_response`. Retry units differ — JS milliseconds, Python seconds (copying numbers across is a 1000× error). JS enforces ≥2 score levels; Python's client-side floor is 1, so a one-level list passes the client and is rejected by the server (detail below). Python `extra_body` shallow-merges **after** state/model/questions, so a colliding key overrides them. JS forwards any stray extra property on the request object, including `null`s. Unknown answer kinds are dropped by the Python SDK with a log warning — read `raw_http_response` if a new primitive lands before an SDK release. Both SDKs redact credential headers at `debug` log level but **not request/response bodies** — `TYPESAFE_LOG_LEVEL=debug` writes your state (customer PII) to logs, and in Python that var is applied once at import.

**Breaking changes so far.** v0.6.0 (both SDKs, 2026-09-15): `Score.criteria` became an ordered sequence instead of an int-keyed dict — any sample using `criteria={0: …, 1: …}` is stale. Python v0.7.0 (2026-09-18): serialization moved msgspec → pydantic; `system_one` gained `response_model`.

### Version-pinned behaviour (JS @0.6.0 / Python @0.7.0)

**Timeouts — the "no total budget" trap is JS-only.**
- JS `TypeSafeClientConfig.timeout`: "Timeout per attempt in milliseconds, without a total retry budget. Default: 10000." JS `RetryPolicy` has **no `timeout` field at all** — its full property set is `apiConnectionError` (true), `apiTimeoutError` (true), `backoffInitialMs` (500), `backoffJitter` (0.25), `backoffMaxMs` (5000), `httpStatuses` (408, 429, 500–599), `maxRetries` (2), `maxRetryAfterMs` (60000), `respectRetryAfter` (true).
- Python has both: `DEFAULT_TIMEOUT = 10.0` ("Default timeout in seconds for each HTTP operation") **and** `RetryPolicy(timeout: float | None = 30.0)` — "Total retry budget in seconds per SDK call, including the initial attempt and delays; `None` disables the limit. Stops before a retry whose delay would reach or exceed the budget, re-raising the last error." Python `RetryPolicy` also gained "handle invalid values in `RetryPolicy`" at 0.6.0, so its validation differs below that version.

**Score levels — three floors, one per layer.** The HTTP API (unversioned) requires "an ordered array of level descriptions. **You must include at least two levels.**" JS rejects fewer than two client-side (source-verified; not in the JS API reference). Python raises `TypeSafeError` only when "questions are empty **or a score question's criteria list is empty**", and the `Score` pydantic schema declares `criteria` with **no `minItems`** — so the Python floor is 1, not "anything non-empty passes end to end": the server rejects the one-level list.

**`extra_body` (Python) is docs-confirmed, not source-only:** "Additional top-level request-body fields, shallow-merged over the body **after `state`, `model`, and `questions` are set**. Merging is last-write-wins: a key that collides with `state`, `model`, or `questions` overrides it, and object values are replaced rather than deep-merged."

**Unknown answer kinds dropped with a warning is source-observed and undocumented** — neither the Python responses reference nor the HTTP API reference mentions it, so it carries no compatibility promise. It is also the most version-fragile claim in §4: Python 0.7.0 replaced msgspec with pydantic (the exact deserialisation layer that decides the fate of an unrecognised answer type) and added `response_model`, which routes decoding through caller-owned types. Re-verify on any Python minor bump; do not carry the claim back to 0.6.x Python.

### Error handling — exception classes

**The class names differ between SDKs: Python prefixes every class with `TypeSafe`, JS does not.** One catch block per SDK, not one shared name list.

| HTTP | JavaScript (`@typesafe-ai/sdk`) | Python (`typesafe_sdk`) |
|---|---|---|
| 400 | `BadRequestError` | `TypeSafeBadRequestError` |
| 401 | `AuthenticationError` | `TypeSafeAuthenticationError` |
| 403 | `PermissionDeniedError` | `TypeSafePermissionDeniedError` |
| 404 | `NotFoundError` | `TypeSafeNotFoundError` |
| 422 | `UnprocessableEntityError` | `TypeSafeUnprocessableEntityError` |
| 429 | `RateLimitError` | `TypeSafeRateLimitError` |
| 5xx (incl. 529) | `InternalServerError` | `TypeSafeInternalServerError` |
| any HTTP error (base) | `APIError` | `TypeSafeAPIError` |
| no response (DNS/TLS/closed) | `APIConnectionError` | `TypeSafeAPIConnectionError` |
| timeout | `APITimeoutError` | `TypeSafeAPITimeoutError` |
| base of everything | `TypeSafeError` | `TypeSafeError` |

Neither SDK has a 529-specific class — 529 arrives as the 5xx class. `TypeSafeError` is the only name spelled the same on both sides.

**Asymmetric — no counterpart on the other side:**
- `TypeSafeAPIResponseValidationError` (Python only) — a *successful* HTTP response whose body was missing or structurally invalid. Carries `field_path`, a dotted path such as `answers.tone.confidence`; `args` is `(status, body, headers, field_path, endpoint)`.
- `APIUserAbortError` (JS only) — the caller cancelled via an `AbortSignal`; extends `TypeSafeError`, **not** `APIError`, so an `instanceof APIError` catch misses it.

**Catch the base, branch on status.** `TypeSafeAPIError` / `APIError` expose `status` (int), the body, the headers and the request id from `x-typesafe-request-id` (`request_id` in Python, `requestId` in JS — snake vs camel here too). Python additionally exposes `endpoint` (method + URL, credentials/query/fragment stripped); JS has no `endpoint`.

```python
except typesafe_sdk.TypeSafeAPIError as e:
    if e.status == 429: ...        # e.request_id, e.body, e.headers, e.endpoint
```
```ts
catch (e) { if (e instanceof APIError && e.status === 429) { /* e.requestId */ } }
```

**Retry/timeout fields differ in name and in unit.** 429: Python `retry_after_ms` (ms, `None` if unavailable) / JS `retryAfterMs` (`number | undefined`). Timeout: Python `TypeSafeAPITimeoutError.timeout` is the *configured* setting, **in seconds** or an `httpx2.Timeout` object; JS `APITimeoutError.timeoutMs` is a `number` in **milliseconds**. Different name, different unit, different type.

**Inheritance (same shape in both):** HTTP classes extend `APIError`/`TypeSafeAPIError` → `TypeSafeError`; the timeout class extends the connection class → `TypeSafeError`. Python's connection classes also inherit the builtins (`ConnectionError`, and `TimeoutError` for the timeout class), so a bare `except ConnectionError` catches TypeSafe connection failures in Python; JS has no such overlap.

### Async and high-volume (Python)

**Async fan-out.** The docs ship no concurrency example; the pieces are documented, the pattern is not. One client, reused, bounded by a semaphore:

```python
import asyncio
from typesafe_sdk import AsyncTypeSafeClient, Noul

async def main(texts: list[str]) -> list:
    sem = asyncio.Semaphore(8)                       # bound, not len(texts)
    async with AsyncTypeSafeClient(timeout=120.0) as client:   # one client = one pool
        async def one(t: str):
            async with sem:
                return await client.system_one(t, {"billing": Noul(instructions="About billing?")})
        return await asyncio.gather(*(one(t) for t in texts))

asyncio.run(main(texts))
```

- The client owns its HTTP layer: a supplied `transport` or `http_client` (`httpx2.AsyncClient`) is "closed when this SDK client closes", so construct once and reuse — per-call construction throws away the connection pool. Outside a context manager, `await client.aclose()`.
- Per-call `retry=RetryPolicy(...)`, `timeout=`, `extra_headers=`, `extra_body=` are arguments of `system_one` itself, so one shared client can carry different retry budgets per task; `RetryPolicy(max_retries=0)` disables retries.

**Is the sync client threadsafe?** The docs never say so in words, but every first-party cookbook shares one module-level `TypeSafeClient` across a `ThreadPoolExecutor` — `skill_suggestion` builds the client at import and calls it from `WORKERS = 8` ("small pool: enough to keep a live run to minutes, gentle on rate limits") over "up to 488 × 2 TypeSafe requests"; the consistency cookbooks use 16, rerank 12, RAG 4. So the 4–16 range is a rate-limit/politeness choice, not a client limit, and sharing one client across threads is the documented-by-example practice. Underlying transport is `httpx2.Client`.

**What `response_model=` changes.** It swaps the return type, not the request. Two overloads: omitted → `SystemOneResponse`; given `type[ResponseT]` → `ResponseT`, typed at the call site with no cast.
- Subclass `SystemOneResponse` and declare one annotated field per question name → typed attribute access alongside everything the base class gives: `result.billing.noul`, with `result.billing == result.nouls["billing"]`, plus `request_id`, `raw_http_response`, `model`, `usage`, `answers`, `nouls`/`choices`/`scores`.
- A plain pydantic `BaseModel` (no inheritance) also works, but answers arrive nested under `answers` (`result.answers.billing.noul`) and you get only the fields you declared — no `request_id`, `raw_http_response` or `usage`.

**High-volume gotcha.** At `TYPESAFE_LOG_LEVEL=debug` the SDK logs request *and response bodies*, explicitly **not** redacted (only secret headers are) — fine for 10 calls, a data-leak and an I/O tax at 10,000.

Sources for this subsection: `/sdk/python/api/exceptions` · `/sdk/python/api/clients/sync` · `/sdk/python/api/clients/async` · `/sdk/python/api/constants` · `/sdk/python/api/retries` · `/sdk/python/api/types/questions` · `/sdk/python/api/types/responses` · `/sdk/python/usage` · `/sdk/javascript/api/classes/{APIError,RateLimitError,APITimeoutError,APIConnectionError,APIUserAbortError,TypeSafeError}` · `/sdk/javascript/api/interfaces/{TypeSafeClientConfig,RetryPolicy}` · both changelogs · JS class list from `llms.txt` (14 classes; no `OverloadedError`, no `APIResponseValidationError`).

---


## 6. Commercial and operational

**Pricing.** `$42` per billion input tokens = **`$0.042` per Mtok, input only; output tokens free**. That figure appears only on `docs.typesafe.ai/models`; `typesafe.ai/pricing` 404s. Cookbooks still carry the older jev-1.12 constant `(0.042, 0.00)` labelled "historical". Billing is prepaid TypeSafe-managed Credits consumed per Input (MCA §8.2); purchased Credits **expire at the earlier of end-of-Term or 12 months**, non-refundable, non-transferable. The free tier is "Promotional Credits… at its sole discretion" with no published allowance. Fees USD, net-30.

Measured on the probe: a 5-word state cost 287 input tokens — there is a **~280-token fixed overhead** per request, which is exactly why fan-out beats per-question calls (3 questions = 389 tokens vs ~861 sent separately). Four probe calls totalled 676 input + 94 output tokens, under $0.0001.

**Limits.** 250k tok/s, 1,200 req/min, explicitly volatile; 64k/32k context; 255 choices; 10 score levels. Higher limits via sales@typesafe.ai.

**Size concurrency empirically, not from the published numbers.** The headline limits have **no documented scope** (§3), so you cannot compute a safe thread count: if the bucket is per-key, eight parallel workers on one shared key can collide; if it is per-account or per-org, adding keys buys you nothing. The one thing the docs do guarantee is the failure mode — over either limit you get `429 Too Many Requests`, and the official SDKs retry with backoff by default (Python `RetryPolicy(max_retries=2, timeout=30.0, http_statuses={408, 429, 500–599})`, honouring `Retry-After`/`retry-after-ms` when present). Practical recipe: keep SDK retries on, ramp concurrency until 429s appear, back off one step, and re-measure after any limit change — TypeSafe reserves the right to move them without notice. To pin the scope or raise the ceiling, ask sales@typesafe.ai; it is not answerable from the docs.

**Retry vs billing — no idempotency, no dedupe statement (NOT FOUND).** Checked `/api`, `/sdk/python/api/retries`, the JS `RetryPolicy` and `RequestOptions` interfaces, and the full `llms.txt` index: **zero occurrences of "idempoten", "dedup", "duplicate", "billed" or "charge" anywhere**, and `docs.typesafe.ai/pricing` returns 404.

- The only documented request headers are `Authorization` and `Content-Type`. **No idempotency-key header, and no request-id header is documented on either side** (the response one, `x-typesafe-request-id`, is observed rather than documented).
- The documented error table is exactly `401`, `422`, `429`, `529`. There is **no `402`/quota-exhausted status**, so there is no documented signal for "you ran out of prepaid Credits".
- The response always carries `usage.input_tokens` / `usage.output_tokens` and **no field marking a response as replayed, cached or deduplicated** — a retried call is indistinguishable from a first call.
- The docs connect retries to cost exactly nowhere: "When you receive a `429 Too Many Requests` or `529 Overloaded` response, retry the request with exponential backoff… Our client SDKs handle this automatically."
- Both SDKs default to `max_retries = 2` (**up to 3 attempts per call**) over `{408, 429, 500–599}`, **plus** `apiConnectionError = true` — JS says this includes "interrupted response bodies" — and `apiTimeoutError = true`. A response the server fully computed (and presumably billed) but failed to deliver is re-sent as a fresh request.
- **Consequence (our inference, not a vendor statement):** worst-case billed volume is **attempts, not calls — up to 3× the intended token spend** in a degraded-upstream window, and connection/timeout retries can bill for work already completed server-side. Nothing in the docs promises otherwise and there is no documented mechanism to make a retry safe: JS `RequestOptions.headers` lets you *send* an idempotency header, but no server-side handling of one is documented, so it would be decorative.
- **Open question for the vendor:** is a retried request deduplicated or billed again, and does any idempotency key exist? Until answered, size a prepaid budget at `max_retries + 1` × nominal, or set `max_retries = 0` and retry at the application layer where the cost decision is explicit.

**Data policy.** No training on Input, stated in both the privacy policy and the model docs; Input is not disclosed to third parties other than service providers. **No retention window is published anywhere** — both the privacy policy and DPA Schedule I §8 say only "as long as reasonably necessary". **Zero data retention is enterprise-only**, by request to privacy@typesafe.ai. MCA §4.3 carves out Telemetry — logs, hashes, summary statistics, classifications, "learnings" — which TypeSafe may process "without restriction, including to improve Services or TypeSafe's other products". Output is assigned to the customer (§4.2); on termination TypeSafe is under no obligation to retain Customer Data and may delete it, with no refund, and the DPA has no deletion-on-termination clause. All hosting is **United States**; all six subprocessors (AWS, Modal, Nebius, CoreWeave, Slack, Google Workspace) are US; no region selection or EU residency option exists, so EU/UK transfers rely on the SCCs (Module 2 + 3) and UK IDTA B1.0 in the DPA. Lead supervisory authority Ireland; 15-day subprocessor objection; audit once per 12 months. SOC 2 Type II – 2026 is listed on the Vanta trust centre behind "Request access"; no ISO 27001, HIPAA, PCI or FedRAMP.

**Legal.** Terms of Use 2026-09-14 (website only, $100 cap, arbitration) · Master Customer Agreement 2026-08-27 (the API contract; Delaware law; liability cap = greater of 12 months' fees or **$50**) · DPA 2026-04-24 · Privacy Policy 2025-11-19 (stale relative to the rest). **MCA §2.3 prohibits publishing benchmarks or performance information about the Services**, and bars distillation or training a competing model — relevant before posting any comparison publicly.

**Status.** `status.typesafe.ai` — api 99.854%, console 99.985% over a ~90-day window, with 24 downtime events totalling 196 minutes, worst 59 minutes. The API briefly stopped serving at launch from demand.

**Support.** support@ / sales@ / privacy@ / hello@. MCA §3 promises "commercially reasonable efforts… in accordance with its standard support policies" — that policy is not published. No tiers, no response targets, no community channel.

**NOT FOUND.** No idempotency key, no dedupe/replay statement, no documented quota-exhausted status, no documented rate-limit scope or `x-ratelimit-*` headers (all above). No SLA, no uptime commitment, no service credits. No latency SLO or percentiles (only the marketing "70–500 ms"). No model deprecation or sunset policy — the closest is MCA §2.5's unquantified "commercially reasonable efforts to provide advance notice". No pricing page, no published free-tier amount, no data-residency control, no explicit retention period, no deletion-on-termination clause, no self-hosting/VPC/BYOC option, no published support policy, no enterprise page (`typesafe.ai/enterprise` 404s), no Bedrock/Azure/Vertex availability, no peer-reviewed paper on RLCD or the architecture, no weights, no public leaderboard submission, no customer names or revenue.

---

