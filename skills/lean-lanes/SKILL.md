---
name: lean-lanes
description: The lane shape every build workflow uses since 2026-10-11 — one warm builder, one cold reviewer, two rounds maximum, Sonnet where it fits, computer use on Sol in Codex. Use when authoring a Workflow or spawning agents for implementation work.
---

# Lean lanes

Binding rule: `~/.claude/CLAUDE.md` § "Lane economy". This file is the template.

## Why

Insights phase A, 2026-10-11: 15 lanes, 126 agents, 39.3M tokens; 15 wrote code, 111 checked or merged it. Member billing item 10: 14 review rounds, two days. Each spawn is cold (~25k tokens of CLAUDE.md, then plan + code + diff re-read, ~310k tokens per agent). Fewer, warmer agents.

## Lane shape

```
builder (warm, owns the lane)          reviewer (cold, narrow brief)
  build → gates → PR ──────────────▶  diff + one-page contract
  read findings ◀────────────────────  findings, BLOCKING narrow
  fix BLOCKING, list the rest
  round 2 only if a BLOCKING came back; never round 3
  merge what is green, file follow-ups
```

Per lane: 2 agents (3 when round two happens). Not 9.

## Models

| Lane | Model | Effort |
|---|---|---|
| Builder, money/auth/tenancy/privacy/sync | `claude-opus-5-5[1m]` | high |
| Builder, well-specified, one PR, brief names files and tests | `claude-sonnet-5-5[1m]` | high |
| Reviewer, money/auth/tenancy/privacy | `claude-opus-5-5[1m]` | high |
| Reviewer, everything else | `claude-sonnet-5-5[1m]` | high |
| Merge/CI babysit, docs, sweeps, catalogue updates | `claude-sonnet-5-5[1m]` | high |
| UX screenshot pass, browser checks, vendor consoles, any computer use | Sol 6.1 in Codex | xhigh |
| Hard design, multi-repo refactor, judge of money | `claude-opus-5-5[1m]` | high |
| Mechanical leaf with a deterministic check: codemod/rename, fixture or generated-file regeneration, catalogue/changelog/taxonomy row, exact diff plan, CI-babysit polling; classification/routing | `claude-haiku-5-5[1m]` | high |

Effort is `high` at least on every lane (Justin, 2026-10-11). Haiku 5.5 (from $0.10/$0.50 per MTok; docs: "classification, routing, extraction, and subagent tasks", no coding claim; an Opus advisor over a Haiku executor gained nothing in Anthropic's measurements) never gets feature code, diagnosis or review — only leaves whose acceptance is `tsc`/lint/test, with the plan owned by Opus or Sonnet. Model choice per lane may be delegated to a Jev Choice (`~/.claude/skills/jev`) over this table; code keeps the hard constraints and Jev picks within the allowed set.

Agent tool: `model: "sonnet"` / `"opus"` map to the `[1m]` ids via `settings.json`. Workflow `agent({model})` takes the full id.

Codex computer use:

```sh
codex exec -m gpt-6.1-sol -c model_reasoning_effort=xhigh --dangerously-bypass-approvals-and-sandbox \
  -C <repo> "<task>. Use the browser skill (betterwright). Return the screenshot paths and a 10-line verdict." </dev/null
```

## Warm continuation (Agent tool, main session)

```
Agent({ name: "lane-B3", model: "sonnet", prompt: BUILD_BRIEF })        // completes with PR url
Agent({ name: "review-B3", model: "sonnet", prompt: REVIEW_BRIEF(pr) }) // completes with findings
SendMessage({ to: "lane-B3", message: `Review findings: ${findings}. Fix BLOCKING, list the rest in the PR body, merge when green.` })
```

A send to a **completed** agent resumes it from its transcript — the builder keeps its context. A send to a **running** workflow lane spawns a duplicate writer: never do that.

## Workflow script template

```js
export const meta = { name: 'lean-build', description: 'One builder, one independent reviewer, one fix round at most, per lane', phases: [{ title: 'Lanes' }] }
const OPUS = 'claude-opus-5-5[1m]', SONNET = 'claude-sonnet-5-5[1m]'
const B = { type: 'object', properties: { pr: { type: 'string' }, worktree: { type: 'string' }, base: { type: 'string' } }, required: ['pr', 'worktree', 'base'] }
const R = { type: 'object', properties: { blocking: { type: 'array', items: { type: 'string' } }, followUps: { type: 'array', items: { type: 'string' } }, merged: { type: 'boolean' } }, required: ['blocking', 'followUps', 'merged'] }
// Workflow agent() cannot resume a finished agent, so the reviewer is its own step with the SCRIPT's brief (never the
// builder's — a builder briefing its own reviewer anchors it), and a cold fix step runs only when BLOCKING came back.
// Normal path 2 agents; BLOCKING path 4; never a third review.
async function lane(id, crit, contract) {
  const model = crit ? OPUS : SONNET, effort = 'high'   // Justin 2026-10-11: high at least, every lane
  const b = await agent(`Build lane ${id} end to end: worktree, code, tests, gates, PR against the brief's base. Do not merge.`, { label: `build ${id}`, phase: 'Lanes', model, effort, schema: B })
  const review = n => agent(`Review ${b.pr} (worktree ${b.worktree}, base ${b.base}) — round ${n}. Contract: ${contract}. Read the diff and the files it touches; not the plan. BLOCKING only: wrong money, double write, auth/tenancy hole, data loss, red build/test, a Done-when clause not met. Everything else is a follow-up. If nothing is BLOCKING, merge the PR with squash once checks are green and set merged=true.`, { label: `review ${id} r${n}`, phase: 'Lanes', model, effort, schema: R })
  let r = await review(1)
  if (r.blocking.length) {
    await agent(`Fix these BLOCKING findings on ${b.pr} (worktree ${b.worktree}), re-run affected gates, push: ${JSON.stringify(r.blocking)}. Do not merge.`, { label: `fix ${id}`, phase: 'Lanes', model, effort })
    r = await review(2)   // round 2 only because round 1 had a BLOCKING; the hook denies a round 3
  }
  return { id, pr: b.pr, merged: r.merged, followUps: r.followUps, unresolved: r.blocking }
}
const CRIT = args.crit || {}, CONTRACT = args.contract || {}
return parallel(args.lanes.map(id => () => lane(id, !!CRIT[id], CONTRACT[id] || 'the brief\'s Done-when clauses')))
```

Dependencies between lanes: chain with `.then()` as before. One UX screenshot lane at the end of the phase (Sol in Codex, [UX/UI rubric](../sandbox-verify/references/ux-ui-review.md)), not per PR. In the main session (Agent tool) the warm pattern above is better: the orchestrator briefs the reviewer and resumes the builder by name.

## Reviewer brief

```
Review PR <url> (branch <b>, base <base>, worktree <wt>) for lane <id>.
Contract (one page, in this message): <paste the lane's Done-when + the 3–6 clauses that apply>.
Read the diff (`git diff <base>...HEAD`) and the files it touches. Do not read the plan, the spec or the IA map.
BLOCKING only: wrong money charged or summed, double write, auth or tenancy hole, data loss, red build or test, a Done-when clause of the contract not met<, PII in logs — if privacy lane>.
Everything else is NON-BLOCKING: display inconsistency, an edge the contract never named, naming, structure, taste.
Output: numbered findings, each BLOCKING or NON-BLOCKING, file:line, one-line fix. Last line: VERDICT: APPROVE | CHANGES (CHANGES only with ≥1 BLOCKING). Do not pad. 15 minutes.
```

## Convergence rule

- Round 1: review. Round 2: only if round 1 had a BLOCKING. No round 3 — merge green, file the rest.
- A reviewer that returns a new BLOCKING every round on the same PR is finding *scope*, not *bugs*: stop, write the class as one follow-up, merge.
- "Thin client by construction" style rewrites mid-review are a new lane, not a fix round.

## Jev as the lane router (tested 2026-10-11, advisory)

`node ~/ops/infra/lane-router/route.mjs "<lane brief>"` → `{"model":"opus|sonnet|haiku|sol","reason":…}` (key: `set -a; . ~/.config/jev/jev.env; set +a`; TypeSafe API directly, `jev-1.13.0`, ~700 tokens). One request: kind (build/review/mechanical/browser/design/docs/other), model by this table, critical Noul (money/auth/tenancy/personal data/encryption). Code keeps the constraints: browser → Sol; critical ≥ 0.5 → Opus; design/other → Opus; confidence < 0.7 → one tier up. Labelled test `~/ops/infra/lane-router/test.mjs`: 15/16, the miss a safe haiku→sonnet step-up, every critical case on Opus. Use it when authoring a workflow to pick each lane's model; it never gates money, auth or production, and the orchestrator may overrule with a reason.

## Production gate — real browser, Sol or Astra

Nothing merges or promotes to production without a real-browser pass by Codex Sol 6.1 (Astra when Justin names it for that merge) on the preview/hosted-dev deployment: the changed user journeys end to end **and a UX/UI review of every changed screen at 1440 and 390 against [the rubric](../sandbox-verify/references/ux-ui-review.md)** (functional APPROVE alone shipped a clunky Insights Home, 2026-10-15), screenshots + a verdict file in `verify-shots/<lane>/` with a `## UX/UI review` section, `UI VERDICT: APPROVE|CHANGES` and the overall `VERDICT: APPROVE|CHANGES` (APPROVE only when journeys and UI pass), run after the reviewer's APPROVE and before `gh pr merge` into `main`. Unit/e2e green never substitutes. The orchestrator Reads the screenshots itself before telling Justin a UI change is done. The per-phase UX pass and this gate are the same run when a phase ships as one release.

```sh
codex exec -m gpt-6.1-sol -c model_reasoning_effort=xhigh --dangerously-bypass-approvals-and-sandbox -C <repo> \
  "Real-browser QA of <preview url> for PR <url>: drive the changed journeys (<list>) with the browser skill, screenshot each step into verify-shots/<lane>/, then review every changed screen at 1440 and 390 against ~/.claude/skills/sandbox-verify/references/ux-ui-review.md. Write verify-shots/<lane>/BROWSER-QA.md with journey findings, a ## UX/UI review section (BLOCKING/NON-BLOCKING findings + screenshots), a UI VERDICT: APPROVE|CHANGES line, and a last line VERDICT: APPROVE only when the journeys and the UI pass, else VERDICT: CHANGES." </dev/null
BROWSER_QA=verify-shots/<lane>/BROWSER-QA.md env -u GITHUB_TOKEN -u GH_TOKEN gh pr merge <n> --squash
```

## Enforcement

`~/.claude/hooks/prod-browser-qa-gate.sh` (PreToolUse Bash) denies `gh pr merge` whose PR targets `main`/`master`/`production` unless the command carries `BROWSER_QA=<existing verdict path>` (a file, or a directory holding one, with both `UI VERDICT: APPROVE` and `VERDICT: APPROVE` lines; test `prod-browser-qa-gate.test.sh`) or `BROWSER_QA=none:<reason>` (docs-only, infra-only, non-UI service). `~/.claude/hooks/lane-economy-guard.sh` (PreToolUse on Bash, Agent, Workflow) denies: any review/fix round numbered ≥ 3 (`codex exec`/`claude -p` prompts, `-rN-prompt` files, Agent prompts); Workflow scripts with a while-loop that spawns agents without a `budget.` bound, a round/attempt loop above 2, a refute vote panel, or a per-item adversarial-verify `.map(… agent(\`…verify`)` fan-out. Dimension reviewers (`Review … for ${d.key}`) stay allowed: they are the work, not a check on it. Opt-out for a shape Justin explicitly asked for: the literal `LANE_ECONOMY_OVERRIDE` in the script or prompt.

## Budgets

Feature lane 90 min · review 15 min · fix round 30 min · screenshot pass 20 min. Over 1.5× inspect the tree; over 2× kill and finish from the tree.
