---
name: session-handoff
description: Prep a session for /clear — reconcile auto-memory, verify git state, run quick gates, log the session to the session index, and hand Justin a resume opener. Use when the user says "prep for a clear", "handoff", "update memory and prep for a clear", "wrap up this session", "safe to clear?", at the end of a feature, or when context is getting heavy (~150-200k tokens).
---

# Session Handoff

Formalizes the pre-/clear ritual. Goal: a fresh session can pick up exactly where this one left off, with zero stale memory. Run all six steps in order; none are optional.

## 1. Reconcile auto-memory

Auto-memory for the current project lives at
`~/.claude/projects/<cwd with '/' replaced by '-'>/memory/MEMORY.md` (plus topic files in the same `memory/` dir). It is already in context — edit it directly.

- Record new architecture, decisions, and gotchas from this session.
- **Delete or mark deprecated** anything this session replaced. Stale memory is worse than none (global rule). A new design entry without removing the old one is a failed reconcile.
- If a change is unmerged, say so explicitly: `(on branch X, uncommitted)` / `(PR open, not merged)`.
- Deeper checklist: `references/memory-reconciliation.md` — read it if the session changed architecture or core flows.

## 2. Verify git state — list it explicitly

```bash
git branch --show-current
git status --porcelain
git log --oneline @{upstream}..HEAD 2>/dev/null || git log --oneline -5
git stash list
```

Report to Justin, item by item: current branch, every uncommitted file, every unpushed commit, any stashes. Never say "working tree is mostly clean" — enumerate. If the repo is a meta-repo with sub-repos (e.g. `~/code/what-if`, `~/code/coworking-mng-not-shit`), run the same four commands in the ROOT and in EVERY sub-repo (not just the ones touched — a lane before you may have left one dirty or parked on a merged feature branch) and report one line per repo: `<repo>: <branch> · <n> dirty · <n> unpushed`. The root count includes evidence dirs (`verify-shots/`, `research/`, `docs/`); a nonzero root count is a defect to fix, not a note (Justin, 2026-09-15, after 363 dirty entries piled up in the coworking root).

**Never leave the repo dirty (Justin, 2026-10-08, after 727 dirty paths piled up in ops).** Enumerating is not enough — finish by making `git status --porcelain` empty: commit real work in small grouped commits with explicit paths and push (`env -u GITHUB_TOKEN -u GH_TOKEN`); backup-move scratch/probe files to `~/.claude/backups/<repo>-<what>-<date>/` (never rm); gitignore runtime markers; keep raw logs/dumps >1M on disk but out of git via `.gitignore` (precedent: ops `5352880`). The only pass-through: a live peer session's genuinely in-flight files — name them explicitly in the handoff. Wait out a peer's `index.lock`; never delete it.

## 3. Run repo quick-gates (if cheap)

If the repo has a project-specific verify/check skill in `.claude/skills/`, prefer it over generic commands. Otherwise run the cheap gates for this repo — see `references/repo-quick-gates.md` for per-repo commands and environment facts. Typical: `npx tsc --noEmit`, `npm run lint`, `flutter analyze`.

Skip anything slow (full builds, e2e); this is a status snapshot, not CI. Note the result either way: "tsc clean, lint clean" or "tsc: 3 errors in X (pre-existing on this branch? — flag it, next session owns it)".

## 4. Write open items + next steps into memory

In the same MEMORY.md, add/refresh a short section:

```markdown
## Handoff (2026-07-04)
- Branch: feat/xyz — 2 unpushed commits, tsc clean
- WORKED: <claim> — <evidence: test name, run id, URL, sha, screenshot>
- DID NOT work: <approach> — <the exact error string>
- NOT tried yet: <option>; <option>
- Open: <unfinished item 1>; <item 2>
- Next: <the single most likely next action>
- Watch out: <trap the next session would hit>
```

The three middle lines are **mandatory** — they are what stops the next session
re-walking this one's ground:

- **WORKED** carries evidence. A claim with no test/run/URL/sha attached is not a
  success — write it under NOT tried yet instead.
- **DID NOT work** carries the exact error, verbatim. The point is that nobody
  retries it; "auth was flaky" is useless, `401 invalid_grant on refresh` is not.
- **NOT tried yet** is the untouched option list. Empty means you actually
  exhausted the space — say so; don't leave the line off.

Overwrite the previous Handoff section — do not accumulate them.

## 5. Append to the session index

```bash
~/.claude/skills/session-handoff/scripts/log-session.sh <repo-name> "<branch>" "<one-line topic>"
```

Appends `date, session-id, branch, topic` (tab-separated) to `~/.claude/session-index/<repo-name>.tsv`, creating dir/file as needed. Session id is taken from `$CLAUDE_SESSION_ID` if set; pass it as a 4th arg otherwise. Use the repo directory name (e.g. `what-if`, `hyperglot-workspace`, `issues-to-action`). A SessionEnd hook may also log automatically — this is the human-readable rich version; write it anyway.

## 6. Tell Justin it's safe to /clear

Finish with a short message (concise — no play-by-play):

- "Memory reconciled, git state: <one line>, gates: <one line>. Safe to /clear."
- Give the exact resume opener for the next session, and point it at the epistemic
  lines so it doesn't re-walk dead ends, e.g.:
  > Resume with: "Continue what-if feat/xyz — finish the invoice PDF export; read the Handoff section first (WORKED / DID NOT work / NOT tried yet)."

If anything is NOT safe (uncommitted work in a risky state, red gate, a live process like the i2a Telegram test), say so before recommending /clear.
