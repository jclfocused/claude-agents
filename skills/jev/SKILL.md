---
name: jev
description: House rules for integrating TypeSafe AI's Jev (System One model — typed Choice/Noul/Score judgments with calibrated probabilities, no text generation) into our apps and automation. Use when a feature or lane needs a classify / route / rank / verify / select-from-candidates decision over natural language, when an existing LLM prompt-and-parse step only returns a label or a yes/no, when a regex or keyword heuristic misfires on free text, when the user says "jev", "typesafe", "system one", "typed judgment", or asks where Jev could apply. Wraps the vendor plugin skill `typesafe:typesafe-ai` (load it too — it carries the live-docs routine) with this box's key location, verified contract, SDK versions, hard boundaries, observability and testing rules. Do not use for anything that must produce prose, code, a summary or a plan — that is a generative model (claude-api skill); do not use for embeddings (gemini-embedding-001).
---

# Jev on this box

Jev = a very cheap, fast, schema-guaranteed `if`. State in (text/JSON), typed answers + probabilities out. Code owns the workflow; Jev supplies one snap judgment per question. It is not more accurate than a frontier judge (~90% agreement with LLM judges; loses the vendor's own accuracy column) — it wins on cost (`$0.042`/Mtok input, output free) and latency (0.1–0.7 s), so it belongs where a decision is made often, cheaply, and with a threshold.

**Read first:** `references/contract.md` (primitives, request/response, limits, SDKs, errors, pricing, data policy) · `references/patterns.md` (cookbook decompositions + 25-entry use-pattern catalogue) · vendor skill `typesafe:typesafe-ai` for the live-docs routine (`https://docs.typesafe.ai/llms.txt`, append `.md` to any page). Full research brief: `mem research search "jev typesafe"`. Where it applies in our products/process: `~/ops/docs/products/jev-applicability-2026-09.md`.

## Credentials and versions (house facts)

- Key: `$JEV_API_KEY` in `~/.config/jev/jev.env` (mode 600). Load per command: `set -a; . ~/.config/jev/jev.env; set +a`. Never print it. Runtime units get it via `EnvironmentFile=%h/.config/jev/jev.env` (or the app's own `~/.config/<app>/*.env` copy, recorded in that app's Credentials entry).
- The SDKs read `TYPESAFE_API_KEY`, not `JEV_API_KEY` — pass `apiKey` explicitly through the app's config module (the one place that touches env), never a bare `new TypeSafeClient()`.
- Probe: `~/.claude/skills/jev/scripts/jev-probe.sh` — read-only, prints models + one Noul + usage.
- SDKs verified 2026-09-20: JS `@typesafe-ai/sdk@0.6.0` (zero deps, Node ≥ 20) · Python `typesafe-sdk@0.7.0` (≥ 3.10). **Not** `typesafe-ai` (unpublished / redirect shim). Pre-1.0: pin exact versions; 0.6.0 already broke `Score.criteria` (now an ordered array).
- Model: send `jev-latest` only in exploration. Production pins the versioned id echoed in `response.model` (today `jev-1.13.0`) — thresholds drift silently when the alias moves.
- Endpoint: `POST https://api.typesafe.ai/v1/systemone`, `GET /v1/models`. Server-side only; `dangerouslyAllowBrowser` stays false.

## Hard boundaries (do not cross)

1. **Never a money, auth, permission or tenancy gate.** Jev may rank, pre-sort, suggest or escalate; the accept/deny of a payment match, a role grant, a refund, a prod promotion stays in code + human. Same list as the correctness-critical review rule.
2. **Never generation.** No prose, no rewriting, no chained Choices to build a string. Keep the LLM for those; put Jev in front of it (route/gate) or behind it (verify fields).
3. **State is untrusted input at our boundary** — Jev treats it as data, not hostile. An injection-detection Noul is a signal, not a control. Size, sanitize and scope state in code.
4. **Data policy is US-only, no retention window, no ZDR outside enterprise.** Do not send raw customer PII when a redacted or field-level state answers the question; `TYPESAFE_LOG_LEVEL=debug` logs full state — never in prod.
5. **MCA §2.3 forbids publishing benchmarks** of the service — internal evals stay internal.

## Design the call (the vendor's rules, house-ordered)

- Code first: rules, arithmetic, dates, counts, regex-visible evidence never go to the model. Jev **cannot count** (one Noul per item, sum in code) and reads **dates as text** (parts as Choices, arithmetic in code).
- One request, many questions: questions over one state run in parallel and isolated; ~280-token fixed overhead per request makes fan-out 10× cheaper than per-question calls. Ask speculatively, discard in code. A second request only when the first answer is needed to build the next state.
- Pick the primitive by meaning: **Noul** = absolute P(yes), no confidence field, ~0.5 = uncertain not medium; **Choice** = relative, always sums to 1 → add `none`/`other` or pair with an existence Noul; **Score** = ordered levels (2–10), compare `>=` never `==`, descriptive levels not numbers, read `probabilities` next to `score`.
- Atomic questions, literal wording, name the state field with a backticked path (`` `ticket.messages[0].text` ``). Question ids are not sent to the model. Consistent invented field names across an option set. Add one example that resembles real input.
- `confidence` ≠ winner probability ≠ accuracy. Threshold on the field you mean; give low confidence a **named destination** (review queue, parent category, human) — never a silent default. Aggregate red flags with `max`, not mean.
- Every question and threshold lives in **one constants file** per integration (e.g. `src/jev/questions.ts`) — that file is what review reads; a threshold change is a one-line diff and stored raw probabilities re-route with no API cost.

## Integration shape (TS backend on the box)

```ts
// src/jev/client.ts — the only importer of the SDK
import { TypeSafeClient } from "@typesafe-ai/sdk";
import { config } from "../config";           // the app's single env reader
export const jev = new TypeSafeClient({ apiKey: config.jevApiKey, defaultModel: "jev-1.13.0", timeout: 3000 });

// src/jev/questions.ts — every question + threshold, reviewed as policy
export const TICKET = {
  urgent: noul("The customer describes an outage or lost money happening now."),
  topic: choice("Which team owns this?", { billing: "invoices, payments, refunds", access: "login, permissions", other: null }),
};
export const T = { urgentAuto: 0.85, topicMin: 0.6 };

// call site: one request, answers consumed in code, decision logged
const { data, requestId } = await jev.systemOne({ state: { ticket }, questions: TICKET }).withResponse();
log.info({ jev: { model: data.model, requestId, answers: data.answers, usage: data.usage, thresholds: T } }, "ticket.triage");
```

Python pipelines: `typesafe-sdk`, `TypeSafeClient(api_key=...)`, `system_one(state, questions)`; `Score(criteria=[...])` list form; retry units are seconds (JS = ms).

## Observability (definition of done, per the observability skill)

- Boundary log line per call: `model`, `x-typesafe-request-id`, the full `answers` map, `usage`, the threshold constants applied, and the decision taken. This is what makes a model bump reproducible.
- Error capture with fingerprint `jev.<integration>` on 401/403/422/429/529 and on timeouts; retries: SDK default handles 408/429/5xx incl. the non-standard **529**, JS `timeout` is per attempt (no total budget) — set it low.
- A dashboard panel per integration: calls, p50/p95 latency, share of answers landing in the abstain band. Alert when the abstain share doubles or the model id changes.

## Testing — derive thresholds, never guess them

1. Build a labelled sample from today's mechanism (the LLM output, the heuristic's hits/misses, the human queue) — 50–200 rows.
2. Run one fan-out request per row, store raw answers.
3. Sweep thresholds in code; plot confidence vs accuracy; choose per-branch thresholds sized to the blast radius (read-only action at the floor, irreversible action ≥ 0.85 + confirm band).
4. Repeatability harness: N=10 repeats with a nonce; any question that wobbles across a threshold gets a wider abstain band or a sharper criterion.
5. Compare against today's mechanism on the same rows before switching; keep the comparison in the repo (`docs/jev-<integration>.md`) with the pinned model id.
6. A unit test asserts the constants file's invariants (every Choice has a no-match option or a paired Noul; every threshold has a named destination) — the rule breaks the build, not a comment.

## FAIL / PASS

FAIL: `noul("Is this ticket urgent and about billing?")` → two judgments in one number; `probability > 0.5` acts; `jev-latest` in prod; threshold in the call site.
PASS: `urgent` Noul + `topic` Choice (with `other: null`) in one request; `urgent >= 0.85` auto-escalates, `0.35–0.85` lands in the review queue, `< 0.35` normal; `defaultModel: "jev-1.13.0"`; both numbers in `questions.ts` with a one-line justification each.

## Cost envelope (measured 2026-09-20)

3 questions over a one-sentence state = 389 input / 73 output tokens ≈ $0.000016. 1,200 req/min and 250k tok/s per key, volatile; cap client concurrency at ≤ 8 on the shared key.

## Dev-process check (live 2026-09-22)

`~/.claude/hooks/jev-review.sh` (PreToolUse, both harnesses) reviews staged diffs + the message on `git commit`, and durable-prose `Write`/`Edit` (memory, research, docs/{backlog,design,products}, SKILL.md, AGENTS.md, CLAUDE.md).
A `memory/*.md` write also answers to the memory-write rules (derivable from the repo, relative dates, frontmatter `type:` vs how it reads); on `Stop` the last assistant reply is checked against the reply template (preamble, leads-with-answer, closing question list, unrequested caveats).
Every code file is also checked for a hardcoded external-world fact (model id, API version, vendor endpoint, price) that the stale-facts rule says to verify; `gh pr create|edit` reviews the branch diff against the PR title+body; `mem learn` compares the new brief against the five nearest bay briefs and flags a duplicate.
On `UserPromptSubmit` the prompt is routed against every installed skill's description and, on a clear match (p >= 0.85), one `additionalContext` line names the skill — a hint, never a block; silence it with `JEV_SKILL_HINT=off`.
Advisory only — never a red/green CI boundary: findings print once to stderr and the identical command/reply repeated proceeds unchanged; any error, timeout or missing key fails open.
On demand: `node ~/ops/infra/jev-review/review.mjs --staged | --diff main | --files <p...> | --prose <file>` (`--json`, `--verbose`, `--strict`).
Questions and thresholds are policy in `~/ops/infra/jev-review/questions.mjs`; `selftest.mjs` asserts their invariants plus one live call.
Raw answers (every call, with the thresholds applied) land in `~/.local/state/jev-review/answers.jsonl`, so a threshold change re-routes stored rows with no API cost.
