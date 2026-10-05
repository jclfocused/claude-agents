---
name: claude-mods
description: House rules for building, reviewing and installing Claude Code mods on this box. A mod is an in-process plugin of function hooks that can add panes, a band above the prompt, spinner and status text, toasts, /commands that run without a turn, model-callable tools, and tool.call or prompt.submit rewrites. Use when Justin asks for a mod, wants a pane, band, status entry or toast inside Claude Code, wants a /command that answers instantly, asks whether a settings hook should become a mod, wants to review or install a third-party mod, or says "mods", "ui.render", "AbovePrompt", "hooks.json modules" or "register(on". Wraps the built-in `plugin-authoring` skill (load it too: it lays this build's types and starts hot reload) with verified box facts, the repo and release path, the dev loop, test-kit rules, hard don'ts and observability. Do not use for settings shell hooks (update-config), skills (create-skill), MCP servers (mcp-connector-build) or the settings statusLine script.
---

# Claude Code mods on this box

**Verified (2.1.289, 2026-10-05).** Mods went GA on 2026-10-01 and need 2.1.287 or later. A mod is a plugin: `hooks/hooks.json` holds `{"modules":["./register.ts"]}`, and the module exports `register(on, options)`. Hooks have the shape `($, e, next)`. Calling `next(e)` passes the event on, `next({...e, x})` rewrites it, and not calling `next` answers it. The module has no DOM and no Node, so all I/O goes through `$`. Hooks run in `claude -p` too. Only the terminal and the Desktop Code tab draw (not `-p`, the SDK, VS Code or the Remote Control view).

**Two facts drive every design decision:**
- **Fail-open.** A hook that throws, runs past its 10 s budget (time inside `next`/`$` calls does not count) or returns a bad shape before `next` is *skipped*. A deny returned after `await next(e)` does not stop the tool, and three worker crashes unload every mod for the session.
- **Not sandboxed, and above our guards.** A mod runs as Justin. One that answers `tool.call` without `next` skips the settings PreToolUse guards beneath it, and there is no `sec-default` here (no managed settings).

**Read first:**
- the built-in skill `plugin-authoring` (file layout, types, hot reload)
- `references/kit-rules.md` (validator, test kit, runtime facts and debug shapes, each one cost an iteration)
- `examples/probe-mod/` (a working mod with a state contract and tests, validate + test green)
- the opportunity map `~/ops/docs/design/claude-mods.md` (what to build, the hook migration verdicts, unverified items)
- research: `mem research search "claude code mods"`

## Where it goes

| Thing | Location |
|---|---|
| LFOS mod source (planned, not built yet) | `~/ops/apps/claude-mods/<mod>/`, in the marketplace `lfos` (`.claude-plugin/marketplace.json`) |
| Feature work | worktree `/home/justin/worktrees/ops/<branch-slug>` |
| Installed copy | directory marketplace on a release tree `~/prod/lfos-mods/current -> releases/<sha>/`, built by a deploy script from merged `origin/main` |
| Scratch or one-off mod in a live session | `plugin-authoring`'s `~/.claude/dev-mods/<session>/` (needs Justin's interactive "Enable hot reloading" answer, never loads in `-p`) |
| A mod for a product repo | that product's own repo, never the workspace repo |

FAIL: `claude plugin marketplace add ~/ops/apps/claude-mods`, which serves an editing checkout, so every save changes every session.
PASS: install from the release tree, and develop with `--plugin-dir` pointed at a worktree.

## Dev loop

1. Run `git worktree add /home/justin/worktrees/ops/<slug> -b feat/<x> origin/main`.
2. In tmux, run `claude --plugin-dir <worktree>/apps/claude-mods/<mod>`. This hot-reloads on save and overrides the installed copy for that session only.
3. Iterate with `claude plugin test <dir>`.
4. Smoke-test headless: `claude -p --plugin-dir <dir> --model claude-haiku-4-5-20251001 --debug-file <scratch>/debug.log "<prompt>"`, then `grep -i <mod> <scratch>/debug.log | head -n 20`.
5. Prove the UI with `tmux capture-pane -p` at 160 and 90 columns. Headless never draws, so a band is UNVERIFIED until a capture shows it.
6. In `$.process.run`, use absolute binaries (node is `/home/justin/.nvm/versions/node/v22.22.2/bin/node`), because nvm is not on PATH there.

**Gates before commit:** `claude plugin validate <dir>` (read the `hooks:`/`calls:` lines), `claude plugin test <dir>`, and `tsc -p <dir>`, since validate and test do not type-check. Regenerate types after every Claude Code upgrade. The ops repo has no CI, so these are the gate.

## Hard don'ts

1. **No enforcement only in a mod.** Guards (bash-guard, context-guard-*, no-anthropic-api, secret scans) stay settings shell hooks, which are also shared with Codex. A mod may add UI or a stricter retry on top. With every mod unloaded, the box must behave as it does today.
2. **Never loosen.** No `tool.check` hook, no `allow` from `classic.PreToolUse`/`classic.PermissionRequest`, no answering `tool.call` without `next`, no `updatedInput`/`updatedToolOutput`, and never rely on a deny after `await next`.
3. **No model or agent calls from mod code:** no `$.model.complete/fork`, `$.agent.spawn`, `$.prompt.submit` or `$.mcp.call`. Code-made model calls route through Codex per CLAUDE.md, and `$.model` bills the session's Claude credential.
4. **Keep context lean.** No `prompt.compose` sections. Context from `prompt.submit` is one line, sent only when state changes (for example, a same-branch peer appears), and pinned by a kit test.
5. **Collector: GETs and `POST /event` only.** Never `/api/act/*`, approve/deny/answer verbs, `/health/deep` or `OBS_HEALTH_TOKEN`, and never POST from a timer, a render hook or a model-callable tool. Human gates (production merge, prod-data writes, outbound sends, money, conservation toggles) are never a mod button. Link to the dashboard by full URL instead.
6. **Render from state only.** No awaited I/O in `ui.render`, `session.start` (it blocks the first prompt) or `session.end` (shared cut with `session-index.sh`). Fetch on `$.clock.every`/`turn.complete`, write to `$.state`, and read it while drawing. No busy loops.
7. **Untrusted text renders as `Text`.** Put no emails, prompts, command text or `action_payload` in events or UI.

## Drawing facts

- No StatusLine render site exists. `$.ui.status(text)` adds a status entry, and `~/.claude/statusline.sh` stays the status line.
- A Pane opened unasked (from a timer or `session.start`) seats only at 144 or more columns. When the person opens one (a command or a button), it seats at any width. When `isPlaced:false`, fall back to a text answer of 25 lines or fewer.
- One owner for the AbovePrompt band. Return `next(e)` when there is nothing to show or `e.props.hasSurvey` is set.
- Size to `e.props.bodyColumns`, use single-width glyphs (`▁▂▃▄▅▆▇█`, no emoji), and draw a grid of cells as one `Raster`, not a Box per cell.
- Keep drawing state in `$.state`, declared in `types/index.d.ts`. Module variables reset on every hot reload. Use `$.store` for state that must outlive the session.

## Observability (definition of done)

- Send a fire-and-forget `POST http://127.0.0.1:7311/event` with `source:"claude-mod"` and kind `mod.<object>_<action>`. Record each kind in the taxonomy in `~/ops/docs/design/claude-mods.md` before the first send.
- Every mod emits `mod.session_loaded` (release sha, Claude Code version, interactive) and `mod.hook_failed` (fingerprint `<mod>:<event>:<errorKind>`) from a `.catch`.
- Add a `jobs:` row in `deploy/observability/manifest.yaml` (precedent: `jev_review`), one Grafana panel and an alert for no check-in in 24 h while sessions run.
- Proof is one pasted event id per new kind.

## Reviewing or installing a third-party mod

1. Get the files, then run `claude plugin validate ./mod` without loading it.
2. Read the `hooks:` and `calls:` lines. Red flags:
   - `tool.check`, `classic.PermissionRequest`, or a `tool.call` that answers without `next`
   - `$.http.fetch` to any non-loopback host
   - `$.process.run`, or `$.fs.write` outside the plugin root
   - `$.env.set`, `$.model.*`, `$.agent.spawn`, `$.mcp.call`
   - `prompt.compose`, or `session.append` rewrites
3. Install through a marketplace pinned to a version, never a live checkout. `/plugin` shows `N mods active · names`.
4. Turn everything off with `--safe-mode`, or `"disableAllHooks": true`, which also stops our settings hooks, so avoid it here.

## Worked example: the probe

`examples/probe-mod/hooks/register.ts`:
- `session.start` registers `/lfprobe`, fetches `127.0.0.1:7311/health`, runs `git rev-parse` and writes `$.state` + `$.store`.
- `tool.call` times `await next(e)` and returns the result unchanged.
- `classic.PreToolUse` logs the ordering.
- `ui.render {component:'AbovePrompt'}` reads `$.state` only and yields `next(e)` when it has nothing to show.

`tests/probe.test.ts` answers every `$` noun with `{ value }` and asserts the enter → PreToolUse → exit order. Copy its shape for a new mod, rename the plugin and state key, and delete what it doesn't need.
