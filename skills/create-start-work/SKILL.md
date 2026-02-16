---
name: create-start-work
description: Create a project-specific start-work skill for a meta-repo workspace. Scaffolds the full development lifecycle from issue to PR. Use when the user asks to "create start-work", "set up start-work", "add start-work skill", or wants to set up a development workflow for a meta-repo.
argument-hint: "[optional workspace path]"
disable-model-invocation: true
---

# Create a Project-Specific Start-Work Skill

You are creating a `/start-work` skill inside a meta-repo's `.claude/skills/start-work/SKILL.md`. This skill will orchestrate the full development lifecycle for that specific project.

## Context Awareness

Check the conversation context. The user may have just set up a meta-repo with `/setup-meta-repo`, or they might reference an existing workspace. Use `$ARGUMENTS` if provided, otherwise infer the target workspace from context or the current working directory.

---

## The Development Phases

Every start-work skill follows this phased lifecycle. The generated skill MUST include all of these:

| # | Phase | What Happens |
|---|-------|-------------|
| 0 | Track | Create phase tracker tasks for visibility |
| 1 | Setup | Fetch issue details, determine scope (which sub-repo(s)), enter plan mode |
| 2 | Research | Create a research team with Explore agents to investigate the codebase in parallel |
| 3 | Plan | Write implementation plan, break into sub-tasks, exit plan mode for user approval |
| 4 | Branch | Create feature branch from base branch in target sub-repo(s) |
| 5 | Implement | Create an implementation team, spawn specialists, monitor progress |
| 6 | Review | Code review of all changes, fix blocking issues |
| 7 | Ship | Commit, push, create PR, update status, shutdown teams, report |

**Phases 2 and 3 happen inside plan mode.** Plan mode is entered at the end of Phase 1 and exited at the end of Phase 3 when the user approves.

---

## Step 1: Research the Workspace

Before asking questions, understand what you're working with:

- Read the root `CLAUDE.md` — understand the sub-repos, their roles, tech stacks
- Check each sub-repo's `CLAUDE.md` — dev commands, build commands, test commands, ports
- Check for existing `.claude/agents/` — what agents already exist?
- Check for existing `.claude/skills/` — what skills are already set up?
- Check `.mcp.json` — what MCP servers are configured?

---

## Step 2: Ask Clarifying Questions

Use `AskUserQuestion`. Skip anything obvious from context.

**Always ask:**
- **Does the team use Linear?** — "Do you use Linear for project management, or should the workflow use raw Claude Code plan mode?"

**Ask if not obvious from context:**
- **Base branch** — What branch do you develop from? (e.g., `develop`, `main`)
- **PR target** — Same as base branch? (usually yes)
- **Branch naming** — What convention? (e.g., `feat/TF-123-description`, `tf-123-description`)
- **Commit style** — Conventional commits? Include ticket ID?

**If Linear:**
- **Branch ticket extraction** — How to extract ticket ID from branch name? (e.g., branch `wha-123-foo` -> ticket `WHA-123`)
- **Ticket prefix** — What's the project prefix in Linear? (e.g., `WHA`, `TF`)

---

## Step 3: Generate the Start-Work Skill

Create `.claude/skills/start-work/SKILL.md` in the workspace root.

### Key Principles for the Generated Skill

1. **Phase gates** — Each phase has explicit pass/fail criteria. Don't proceed until the gate passes.

2. **Teams, not bare agents** — ALWAYS `TeamCreate` before spawning agents. Never use `Task()` without `team_name`.

3. **Research uses Explore teams** — Phase 2 creates a research team with Explore agent teammates scoped to the in-scope sub-repos. The generated skill should describe creating research tasks based on the sub-repos discovered in Phase 1, NOT hardcode specific sub-repo names.

4. **Plan mode for Phases 2-3** — Research and planning both happen inside plan mode. This keeps it read-only until the user approves.

5. **The generated skill can reference creating project-specific agents** — If the workspace doesn't have `.claude/agents/` for its sub-repos, the start-work skill should note that the orchestrator can spawn agent builder tasks to create them on-the-fly based on the project's stack. Don't prescribe specific agents in the generated skill — let the orchestrator determine what's needed per-project.

6. **Implementation team composition is dynamic** — The generated skill should describe spawning specialists based on the scope (which sub-repos are in play), plus always including a test-runner. Don't hardcode agent names — describe the pattern.

7. **Memory checkpoints** — After each phase gate passes, the orchestrator MUST update its auto memory (the persistent memory at `~/.claude/projects/<project>/memory/MEMORY.md` that Claude Code provides). Write the current phase, issue/task ID, team name, branch name, sub-issue/task mappings, and scope. This is NOT a random markdown file — it's Claude Code's built-in memory that persists across sessions and survives context compaction. On resume, the orchestrator reads its memory first to determine where it left off. The generated skill should include explicit "Update memory checkpoint" steps after every phase gate.

8. **Anti-patterns section** — Include common mistakes to avoid (bare agents without teams, skipping phases, re-exploring after research, etc.)

### Linear Mode vs Raw Mode

**If the team uses Linear**, the generated skill should:
- Fetch issue details from Linear MCP in Phase 1
- Create sub-issues in Linear during Phase 3 (orchestrator creates them directly via MCP, NEVER delegates to agents)
- Include a linear-manager equivalent in the implementation team to sync task status back to Linear
- Update parent issue status at key milestones (In Progress, In Review)
- Include the ticket ID in branch names, commits, and PR title
- Use `ToolSearch` to load Linear MCP tools before calling them

**If the team does NOT use Linear**, the generated skill should:
- Accept a plain-text description of the work as `$ARGUMENTS` instead of a ticket ID
- Use Claude Code plan mode natively — research, write plan, get user approval
- Skip all Linear-specific steps (no MCP calls, no issue creation, no status updates)
- Still follow the same phase structure (setup → research → plan → branch → implement → review → ship)
- Use task lists (`TaskCreate`/`TaskUpdate`) for tracking instead of Linear

### Customization Points

Replace these with project-specific values:

| Placeholder | Source |
|:------------|:-------|
| Base branch | User answer (e.g., `develop`, `main`) |
| Branch naming pattern | User answer |
| Sub-repo names and descriptions | From root CLAUDE.md |
| Dev/build/test/lint commands per sub-repo | From each sub-repo's CLAUDE.md |
| Commit message format | User answer |
| PR template | User answer or generate from project conventions |
| Linear ticket prefix | User answer (Linear mode only) |
| Docker / migration ownership | From root CLAUDE.md |

### Structure of the Generated Skill

The generated `SKILL.md` should follow this structure:

```
---
name: start-work
description: Start work on [a Linear issue / a task]. Orchestrates the full development lifecycle from [issue/task] to PR.
argument-hint: [issue-id or task description]
disable-model-invocation: false
allowed-tools: [appropriate tools list]
---

# Start Work

## Hard Rules
[Project-specific rules + universal rules like "always TeamCreate before agents"]

## Anti-Patterns
[Common mistakes table]

## Phase Overview
[Table of all 8 phases with gates]

## Phase 0: Track
[Create tracker tasks + write initial memory checkpoint]

## Phase 1: Setup
[Fetch issue/understand task, determine scope, enter plan mode]
→ Memory checkpoint: issue ID, scope, target repos

## Phase 2: Research (Inside Plan Mode)
[Create research team, spawn Explore agents for in-scope repos, synthesize, cleanup team]
→ Memory checkpoint: research summary location, team status

## Phase 3: Plan (Inside Plan Mode)
[Write plan, create sub-tasks (in Linear or TaskList), exit plan mode]
→ Memory checkpoint: sub-issue/task mappings, plan approved

## Phase 4: Branch
[Create feature branch from base branch in target sub-repos]
→ Memory checkpoint: branch name(s)

## Phase 5: Implement
[Create impl team, spawn specialists + test-runner (+ linear-manager if Linear), monitor]
→ Memory checkpoint: team name, agent names, task statuses

## Phase 6: Review
[Code review in impl team, fix blocking issues]
→ Memory checkpoint: review status, findings resolved

## Phase 7: Ship
[Commit, push, PR, status update, shutdown, report]
→ Memory checkpoint: clear active workflow (done)
```

---

## Step 4: Verify and Report

After creating the skill:

- Verify the file exists at `.claude/skills/start-work/SKILL.md`
- Check it's under 500 lines (use supporting files if needed)
- Tell the user:
  - How to invoke it: `/start-work <issue-id>` (Linear) or `/start-work <description>` (raw)
  - That it will enter plan mode for research + planning before writing any code
  - That they approve the plan before implementation begins
  - That they may want to create project-specific agents in `.claude/agents/` over time as they refine the workflow
