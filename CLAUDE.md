# Global Development Standards

## Critical Rules

**NEVER use `--no-verify`** - Fix hook issues, don't bypass them.
**NEVER assume caching** - Errors are real. Check imports, paths, exports.
**NEVER push code** - Commits stay local until pipelines configured.
**ALWAYS test builds** - Run `npm run build` before committing.
**NEVER blame external factors** - Problems are almost ALWAYS in your code/config, not caching, stale deploys, Docker issues, or environment. Investigate the actual code first.
**NEVER kill user applications** - Do NOT pkill/kill Chrome, browsers, Slack, or any user apps. Only kill processes YOU started (npm, gradle, xcodebuild, build processes, etc.).
**NEVER request Copilot reviews** - Do NOT use `request_copilot_review` or any GitHub Copilot review tools.

## **NEVER ASSUME TESTS ARE "PRE-EXISTING FAILURES"**

**Failing tests ALWAYS need to be fixed.** No exceptions unless the user explicitly says to skip them.

- If a test fails, it means something is broken - investigate and fix it
- Do NOT assume test failures are "pre-existing" or "unrelated to changes"
- Do NOT suggest skipping tests or using `--no-verify`
- Do NOT use `eslint-disable` comments to bypass issues
- Do NOT use `@ts-ignore` or implicit `any` types as shortcuts
- Fix tests properly with correct types and logic

## Node.js
- Use Node.js 22 by default
- Install packages without versions: `npm install pkg1 pkg2`
- Verify latest with `npm view [package] version`

## Git Workflow

1. Check git status (clean working directory)
2. Create feature branch
3. Implement + test
4. Run `npm run build` (must pass)
5. Run `npm run lint` (must pass)
6. Commit with descriptive message

## Code Changes

Use Edit/Write tools directly. Workflow:
1. Read/Glob/Grep to understand context
2. Edit/Write to make changes
3. Test and verify
4. Commit

## Debugging

**ALWAYS assume your code is broken first.** Never attribute bugs to timing issues, caching, stale deploys, race conditions, or external factors as a first explanation. These are lazy conclusions that waste time.

1. **Investigate the actual code path** — trace data flow, read the queries, check the logic
2. **External factors are the LAST hypothesis**, not the first — only blame timing/caching/deployment if you have conclusively ruled out every code-level explanation
3. **"It works sometimes" does NOT mean it's a timing issue** — intermittent bugs are almost always conditional logic bugs (e.g., duplicate detection, state filtering, missing edge cases)
4. **Read error messages and query results** — don't guess at what they might contain

When "X is not defined":
- Check if X is imported
- Check import path is correct
- Check X is exported from source
- Check for typos

**Never restart services as first debugging step.**

## Background Tasks

- Check existing background processes first
- Use `run_in_background: true` for long-running processes
- Monitor with `BashOutput`
- Kill and restart external processes in your shell to maintain control

## Quality Gates

Before marking work done:
- [ ] Tests pass
- [ ] Build passes
- [ ] Lint passes
- [ ] Regression tests fixed

## 1Password (Secret Management)

Secrets are stored in 1Password, accessible via the `op` CLI. **Never hardcode secrets** — fetch from 1Password.

- **Account**: `my.1password.eu` (always pass `--account` flag)
- **Vaults**: `What-If` (Linear, Cloudflare, Supabase, Grafana, Render, Sentry, Codacy), `Hyperglot` (Apple/ASC, Supabase, Google), `Dev Tools` (GitHub, Claude Code, Gemini, Jira, Postman)
- **Fetch**: `op read "op://Vault/Item/field" --account my.1password.eu`
- **Use `/1password` skill** for full reference on fetching, storing, and injecting secrets

## Notion (MCP)

- General patterns only (not project-specific)
- Search with tags array: `["vue", "testing"]`
- Project-specific → CLAUDE.md in repo
