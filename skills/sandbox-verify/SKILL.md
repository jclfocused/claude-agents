---
name: sandbox-verify
description: Headless browser smoke test of a preview deploy or local build BEFORE reporting UI work done — resolves the preview URL, loads key routes, captures console errors and full-page screenshots, checks wrong-language strings, overflow/clipping, and that the specific changed element actually renders. Use after implementing any UI/frontend change and before telling Justin it's done; when the user says "verify the preview", "smoke the sandbox", "check the preview", "screenshot the change", "did the UI change actually land", or reports that shipped UI looks wrong. Also use for every UI/UX PR to publish matched before/after screenshots and useful short interaction recordings.
---

# Sandbox Verify

Prove a UI change works by looking at it headlessly — Justin is not the test harness.
**Every UI/UX PR requires before/after screenshots in its description.** Capture and inspect them, upload them where reviewers can open them, and verify the rendered comparison. After UI/UX revisions, refresh affected After screenshots **and videos** before review; retain the original Before baseline. See [PR visual evidence](references/pr-visual-evidence.md), including short flow recordings. Share the PR and stable branch preview; local artifact paths alone do not complete delivery.

**Project skills win:** if the current repo has its own verify/preview skill in
`.claude/skills/` (e.g. `verify-preview`, `check-server`, `test-local-pipeline`),
prefer it for route lists, URLs, check names, and DB topology. This skill is the
global core: use it directly when no project skill exists, and as the engine the
project skills defer to.

## 1. Resolve the target URL

Preview deploy (PR exists, Cloudflare check green):

```bash
~/.claude/skills/sandbox-verify/scripts/resolve-preview-url.sh [PR] [--project <pages-project>]
```

Order: Cloudflare check-run summary (**Branch Preview URL** row — the persistent
per-branch alias, never the per-deploy hash) → `*.pages.dev` in PR comments →
branch-slug formula. Probes reachability; 302/401 = access-protected but deployed,
404 = not deployed. Per-repo facts and the slug formula: `references/preview-urls.md`.

Local build (nothing pushed yet): start the dev server in background, wait for the
listen line, use `http://localhost:<port>`. Kill it when done (only servers you started).

Close everything the smoke starts, on finish AND on failure, and give it a lifetime: the dev
server, any betterwright `--session` you opened, any throwaway database. In a script, set
`trap '<stop each one>' EXIT` straight after starting them. Start a dev server that has to outlive
a single command as a unit with a deadline, so a crashed lane cannot leave it running for weeks:
`systemd-run --user --unit=verify-<slug> -p RuntimeMaxSec=12h --working-directory="$PWD" npm run dev`,
then `systemctl --user stop verify-<slug>` at the end. (41 `tsx watch` processes once sat 17–52
days in a dead ssh scope.) The hourly `lfos-host-reaper` (`~/.claude/automation/logs/host-reaper.log`)
reports leftovers. It is the safety net, not the cleanup.

## 2. Pick routes

- The route(s) rendering the code you changed — mandatory.
- The app's landing/home route — cheap regression canary.
- Route list from the project verify skill if one exists; otherwise trace the diff
  to its pages (router config, file-based routing).

## 3. Run the smoke

**betterwright first** — the `betterwright` MCP server is registered on this box
(`claude mcp list` → betterwright ✔) and the CLI is on PATH. It is interactive, so you
can click through auth, and its proof screenshot comes back inline:

```
mcp__betterwright__browser  code: "await page.goto('<url>'); await snapshot({interactive:true}); return screenshot({kind:'proof'})"
```
CLI equivalent: `betterwright run -c "await page.goto('<url>'); return screenshot({kind:'proof'})"`.
Console output is in the returned `console` array; artifacts land under `artifacts[].path`.
Full workflow (snapshot refs, `human.click`, captcha, site packs): the `browser` skill.

**Fallback — the tested Playwright script**, when you want the batch route sweep
(overflow math, per-route text dumps, `--selector` assertions) in one shot (Xvfb is
installed and works on this box if a headed run is ever needed):

```bash
node ~/.claude/skills/sandbox-verify/scripts/smoke.mjs \
  --out <scratchpad>/smoke \
  --base https://<preview>.pages.dev \
  --selector '<css-of-the-element-you-changed>' \
  / /route-a /route-b
```

Per route it: loads, scrolls end-to-end (lazy content), then captures full-page
screenshot (`<slug>.png`), rendered text (`<slug>.txt`), console errors + pageerrors,
failed/4xx+ requests, horizontal overflow with offending elements, and per
`--selector` an existence/visibility assertion plus an element-only screenshot
(`<slug>.sel-N.png`). Exit 1 = findings; `summary.json` has the details.
Repeat with `--viewport 390x844` when the change affects mobile layout.

First run only: `cd ~/.claude/skills/sandbox-verify/scripts && npm install && npx playwright install chromium`.

Auth-protected routes: prefer betterwright to log in — `mcp__betterwright__browser_login`
(or `credentials.fill({id, submit:true})` inside a `betterwright run` snippet) fills from
the encrypted vault without the secret entering the transcript. Otherwise use a test
account via the project's documented seed credentials — never Justin's real account.

## 4. Inspect what you captured

For marketing pages, also apply the [fresh-context marketing review](../style-inspiration-research/references/marketing-evidence.md#fresh-context-marketing-review). Use a fresh reviewer in the current harness (Codex stays in Codex). Check the buyer, claim, product evidence and purchase questions as well as layout. A clean browser run proves rendering/interaction, not audience comprehension or conversion.

- **Console errors / failed requests**: any = not done. Fix first.
- **Wrong-language strings**: grep each `<slug>.txt` against sentinel strings from the
  repo's other locale files, plus `undefined` / `[object Object]` / raw i18n keys.
  Exact recipe: `references/language-check.md`. (This caught Estonian-in-Ukrainian once.)
- **Overflow/clipping**: script reports elements crossing the viewport edge; confirm
  in the screenshot it's a real defect, not an intentional carousel.
- **THE element you changed**: open `<slug>.sel-0.png` with Read and verify it is
  present AND styled as intended — right size, right position, not default-unstyled.
  A tiling slider shipped wrong three times because nobody screenshotted the slider
  itself. A passing `--selector` count is necessary, not sufficient — look at the pixels.
- **UX/UI review — always, not only "does it work"**: judge every changed screen at 1440 and
  390 against the [UX/UI rubric](references/ux-ui-review.md) (layout, hierarchy, component
  consistency, spacing, type, contrast, states, copy, affordances, motion, responsive). Write
  the `## UX/UI review` section and a `UI VERDICT: APPROVE|CHANGES` line; the overall
  `VERDICT: APPROVE` needs the journeys AND the UI to pass. A functional APPROVE shipped a
  clunky Insights Home (2026-10-15).

## 5. Report

Only after step 4 is clean, including `UI VERDICT: APPROVE`. Read the screenshots yourself
(orchestrators too, not only the lane) before telling Justin a UI change is done:

```
SendUserFile: full-page screenshot(s) of the changed route(s) + the element close-up,
caption naming route, viewport, and preview URL. Then say it's done.
```

If findings remain, report them as findings with the evidence — not as "done".

## Failure handling

- Preview 404s → deploy didn't happen; check the Cloudflare check-run, don't screenshot prod instead.
- Blank screenshot / 0 console errors on an SPA → app likely crashed before logging;
  check `<slug>.txt` (empty = crash), re-run with `--timeout 60000`.
- Playwright "Executable doesn't exist" → `cd scripts && npx playwright install chromium`.
- Any failure, including an abandoned run, still ends with the step 1 teardown: stop the dev
  server, close your betterwright session and drop the throwaway database you started.

## Designing the gate itself

This skill is the runbook for smoking one UI change. For gate DESIGN questions — legibility
floors on a compare/diff view, animation end-state proof, a check that is green while the user
says nothing changed — use the `verification-gates` skill.
