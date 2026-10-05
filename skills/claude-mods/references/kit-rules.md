# Validator, test kit and runtime rules — learned on 2.1.289 (2026-10-05)

Each rule cost an iteration on the probe mod (`../examples/probe-mod`, validate + test green). The d.ts laid into `<mod>/.claude-plugin/types/` is the authority; re-check after a Claude Code upgrade.

## Validator (`claude plugin validate <dir>`)

1. **`$` may only be passed to a function declared at the top level of the module** (a top-level `function`, or a const bound to one). A closure defined inside `register` fails:
   `$ is passed to "out", which is not a function declared at the top of this file`. Hoist helpers.
2. **Every `$.state` value used through `atom`/`read`/`update` must be declared** in a types contract named in `plugin.json` as `"types": "./types/index.d.ts"`:
   ```ts
   export type ProbeHealth = { text: string }
   declare module 'claude-code' { interface PluginState { 'lf-probe': { health: ProbeHealth | null } } }
   ```
   Missing → `lf-probe.health is not declared`.
3. Read the `hooks:` and `calls:` lines of its output — that is the review surface (what the module hooks, which `$` methods it calls).
4. validate and test do **not** type-check. Run `tsc -p <dir>` (after the engine has loaded the mod once, so `.claude-plugin/types/tsconfig.json` exists).

## Test kit (`claude plugin test <dir>`, `*.test.ts`, imports from `claude-code/testing`)

5. **The test's `on` hooks stand in for the engine.** No `$` noun has an implementation until the test answers it; unanswered → `no implementation for clock.now`, and the plugin's hook is skipped.
6. **Noun answers are `{ value }`**: `on('clock.now', () => ({ value: n }))`, `on('fs.write', () => ({ value: undefined }))`. A bare value → `returned something that is not a result object`.
7. **A `tool.call` answer is `{ result: <tool output> }` or `{ deny }`.** Bash: `{ result: { stdout, stderr, interrupted } }`. A `{ text }` answer → `returned neither { result } nor { deny }`.
8. **The test's `$` has no `fs`.** Capture what the plugin writes by answering `fs.write` in the test — also the clean way to assert side effects.
9. `$.tool.call` in a test raises `classic.PreToolUse` beneath the plugin's `tool.call`, same order as live.
10. UI tests: mount through the test's `ui` noun on a named surface; loop the body over `['terminal', 'desktop'] as const`.

## Runtime facts (proven live, `claude -p --plugin-dir`)

| Fact | Evidence |
|---|---|
| Mods load and their hooks fire in `claude -p`; nothing draws there | debug: `hooks module lf-probe@inline loaded (worker, environment 1, tier user)` |
| `$.ui.status` in `-p` is a no-op | `no status row in a headless session` |
| Order: `tool.call` enter → `classic.PreToolUse` → settings PreToolUse shell hooks → tool → `tool.call` exit | settings hooks run *inside* the mod's `next()` |
| `$.http.fetch('http://127.0.0.1:7311/health')` works (loopback allowed) | 200 in 65 ms |
| `$.process.run(argv, init?)` — argv is an **array**, not `{argv}` | `git exited 0 in 5ms` |
| `$.fs.write` replaces the whole file; there is no append | keep lines in memory, rewrite |
| `$.store` persists across sessions; `$.state` is per session; module variables reset on every hot reload | marker read back in run 2 |
| Worker hop ≈ 1–3 ms; 5 settings PreToolUse shell hooks ≈ 57 ms | mod overhead is below the shell hooks it sits on |
| `command.run` output is prefixed with the plugin name by the engine | don't add it yourself |

## Debug log shapes

- Load: `hooks module <name>@inline loaded (...)`, `plugin.register: <name> ... admitted`
- Refused tree: `ui.render (<Component>): a hook returned a tree that does not validate` + reason
- Hot-reload sessions also print a dim transcript line: `<plugin>: ui.render (<Component>) refused: <reason>; the engine drew its own`
- Headless smoke: `claude -p --plugin-dir <dir> --model claude-haiku-4-5-20251001 --debug-file <scratch>/debug.log "<prompt>"`, then `grep -i <name> <scratch>/debug.log | head -n 20`.
