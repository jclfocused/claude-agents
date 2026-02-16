---
name: setup-meta-repo
description: Set up or update a meta-repo workspace containing multiple sub-repos. Creates CLAUDE.md files, .mcp.json, .claude/settings.local.json, and initializes git. Use when the user asks to "set up a meta repo", "init workspace", "setup workspace", "create workspace config", "set up meta-repo", or references setting up a multi-repo workspace.
disable-model-invocation: true
argument-hint: "[optional workspace name]"
---

# Setup Meta-Repo Workspace

You are setting up (or updating) an **organizational meta-repo** — a root directory that houses multiple independent sub-repos/projects. The meta-repo itself is NOT where feature work happens. It exists for shared configuration, Claude Code skills, and workspace organization.

## Context Awareness

This skill can be invoked at any point in conversation. Check surrounding context — the user might say "/setup-meta-repo" while already in a directory, or "set up this workspace", or reference a specific location. Use `$ARGUMENTS` if provided, otherwise use the current working directory.

## Process Overview

1. Ask clarifying questions
2. Discover sub-repos
3. Research each sub-repo
4. Create/update CLAUDE.md in each sub-repo
5. Create/update root CLAUDE.md
6. Set up .mcp.json
7. Set up .claude/settings.local.json
8. Initialize git repo on main (if not already a repo)

---

## Step 1: Ask Clarifying Questions

Use `AskUserQuestion` to gather what you need. Only ask what you can't infer from context.

Likely questions:
- **Workspace name**: What should this workspace be called? (suggest one based on directory name)
- **Sub-repos to include**: Should all subdirectories be treated as sub-repos, or only specific ones?
- **Docker Compose**: Is there a docker-compose setup? If so, which sub-repo owns it?
- **Special rules**: Any workspace-wide rules (e.g., specific sub-repo owns migrations, shared services)?

Skip questions where the answer is obvious from context or directory contents.

---

## Step 2: Discover Sub-Repos

Scan the root directory for sub-directories. **Ignore** these:
- `.claude/`
- `.git/`
- `node_modules/`
- `.vscode/`
- `__pycache__/`
- Any hidden directories (starting with `.`)
- Any known build/output directories

Each remaining directory is a potential sub-repo. Verify by checking for indicators:
- `.git/` directory inside it
- `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`
- `README.md`
- `Makefile`, `Dockerfile`, `docker-compose.yml`
- Source code files

List the discovered sub-repos and confirm with the user if unclear.

---

## Step 3: Research Each Sub-Repo

For each sub-repo, gather information by reading key files. Do this in parallel where possible using the Explore subagent or direct reads.

### Files to look for (read what exists):
- `package.json` — name, scripts (dev, build, test, start), dependencies, tech stack
- `requirements.txt` / `pyproject.toml` / `Pipfile` — Python dependencies
- `go.mod` / `Cargo.toml` — Go/Rust dependencies
- `README.md` — project description, setup instructions
- `Makefile` — available commands
- `Dockerfile` / `docker-compose.yml` — containerization setup
- `.env.example` / `.env.local.example` — environment variables needed
- `tsconfig.json` / `vite.config.*` / `next.config.*` — framework indicators
- `CLAUDE.md` — existing Claude instructions (if already present)
- Source directory structure (e.g., `src/`, `app/`, `lib/`, `cmd/`)

### Information to extract per sub-repo:
1. **What it is** — one-line description of purpose
2. **Technology stack** — language, framework, major dependencies
3. **How to run it** — dev server command, port, build command, test command
4. **Key directories** — where source code, tests, config live
5. **Special notes** — database ownership, migration commands, environment requirements

---

## Step 4: Create/Update CLAUDE.md in Each Sub-Repo

For each sub-repo, check if `CLAUDE.md` exists.

### If CLAUDE.md does NOT exist — Create it

Write a `CLAUDE.md` tailored to that specific repo with:

```markdown
# [Repo Name]

[One-line description of what this repo does]

## Tech Stack
- **Language**: [e.g., TypeScript, Python 3.11+]
- **Framework**: [e.g., React 18, FastAPI, Next.js]
- **Key Dependencies**: [major ones]

## Getting Started

### Install dependencies
```bash
[install command]
```

### Run development server
```bash
[dev command with port]
```

### Run tests
```bash
[test command]
```

### Build
```bash
[build command]
```

## Project Structure
```
[directory tree of key folders]
```

## Key Patterns
- [Any conventions discovered from reading the code]

## Rules
- [Repo-specific rules like "don't restart dev server", "migrations run from here", etc.]
```

### If CLAUDE.md DOES exist — Review and Update

Read the existing CLAUDE.md. Check that it includes:
- [ ] How to run the dev server (with port)
- [ ] How to run tests
- [ ] How to build
- [ ] Technology stack
- [ ] Project structure / key directories
- [ ] Any repo-specific rules

If any of these are missing or outdated based on what you discovered in Step 3, update the file. **Do not overwrite user-written content** — add missing sections, update outdated info.

---

## Step 5: Create/Update Root CLAUDE.md

Create a root `CLAUDE.md` following this structure (use the what-if example as a model):

```markdown
# [Workspace Name]

This is an **organizational meta-repo**. It exists to house shared Claude Code skills, configuration files (`.claude/`, `.mcp.json`), and workspace settings. It is **not** a repo where feature branches are created. All feature work happens in the individual sub-repos below.

## Git Rules

- **Do NOT create feature branches here.** Feature branches belong in the sub-repos.
- **Only commit here** when updating workspace-level files: `CLAUDE.md`, `.gitignore`, `.mcp.json`, `.claude/` skills, or workspace config.
- Each subdirectory is its own git repo. Always `cd` into the subdirectory before running git commands for that project.

```
[workspace-name]/                (this repo - organizational workspace)
├── .claude/                     # Shared Claude Code skills & config
├── .mcp.json                    # MCP server configuration
├── [sub-repo-1]/                # [description] - separate git repo
├── [sub-repo-2]/                # [description] - separate git repo
└── [sub-repo-N]/                # [description] - separate git repo
```

---

## Sub-Repos

### [sub-repo-1]/

**[One-line description]**

- **Technology**: [stack summary]
- **Dev Server**: [port info if applicable]
- **Run**: `cd [sub-repo-1] && [dev command]`
- See `@[sub-repo-1]/CLAUDE.md`

### [sub-repo-2]/
[... repeat for each sub-repo ...]

---

## Key Rules

- **Git**: Separate repos per subdirectory, always `cd` first
- **Feature branches**: Create in sub-repos, never in this workspace repo
- [Any docker compose rules]
- [Any migration ownership rules]
- [Any shared service rules]
```

**Important**: The root CLAUDE.md must clearly state that **no functionality work happens in the root** — always `cd` into the specific sub-repos.

---

## Step 6: Set Up .mcp.json

Create `.mcp.json` in the root if it doesn't exist:

```json
{
  "mcpServers": {}
}
```

If it already exists, leave it as-is. Tell the user they can configure MCP servers later (Linear, GitHub, Render, etc.) using the `/mcp-project-config` skill if available.

---

## Step 7: Set Up .claude/settings.local.json

Create `.claude/settings.local.json` if it doesn't exist:

```json
{
  "permissions": {
    "allow": []
  }
}
```

If `.claude/` directory doesn't exist, create it. If settings already exist, leave them as-is.

---

## Step 8: Initialize Git Repo

If the root is NOT already a git repo:

1. Run `git init`
2. Run `git checkout -b main` (ensure we're on main)
3. Create a `.gitignore` that includes sensible defaults **and all discovered sub-repo directories**. Sub-repos are their own git repos and must NOT be tracked by the root meta-repo:

```
# Sub-repos (each is its own git repo)
backend/
frontend/
mobile/
# ^^^ Replace with actual discovered sub-repo directory names

# Standard ignores
node_modules/
.env
.env.local
*.log
.DS_Store
```

**This is critical** — without ignoring sub-repos, the root git repo would try to track them as subdirectories or submodules, which defeats the purpose of the meta-repo structure.

4. Stage the workspace files: `CLAUDE.md`, `.gitignore`, `.mcp.json`, `.claude/settings.local.json`
5. Create initial commit: "Initialize meta-repo workspace"

If it IS already a git repo:
- Verify we're on `main` branch
- Do NOT create a commit automatically — let the user decide when to commit

---

## Step 9: Summary

After completing all steps, provide a summary:

- List all sub-repos found and whether CLAUDE.md was created or updated
- Show the root CLAUDE.md structure
- Mention .mcp.json and settings.local.json status
- Remind the user:
  - All feature work happens in sub-repos, not the root
  - They can configure MCP servers in .mcp.json when ready
  - They can add shared skills to `.claude/skills/`
