---
name: create-start-work
description: Scaffold a project-specific start-work skill. This is the global blueprint — use it to create .claude/skills/start-work/SKILL.md in a project.
argument-hint: [linear-issue-id]
disable-model-invocation: true
allowed-tools: Task, Read, AskUserQuestion, TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, TaskList, ToolSearch, EnterPlanMode, ExitPlanMode, Glob, Grep
---

# Start Work on Linear Issue — Blueprint

**This is a global blueprint.** Projects should create their own `.claude/skills/start-work/SKILL.md` that references project-specific agents and skills.

## What a Project Version Should Include

The project-specific version should customize:

1. **Agent references** — Point to `.claude/agents/` definitions for the project's stack
2. **Skill references** — Point to `.claude/skills/team-*/SKILL.md` for project-specific workflows
3. **Build commands** — Project-specific build, lint, test commands
4. **Branch naming** — Project-specific conventions
5. **Linear team name** — The team in Linear this project belongs to

## Standard 7-Phase Flow

### Phase 1: Setup (Inline)
- Verify Linear MCP connection via ToolSearch
- Fetch issue details
- Check for project agents (spawn meta-agent builders if missing)
- Determine scope (backend/frontend/full-stack/migration)

### Phase 2: Research (Team-Based)
- Read `.claude/skills/team-research/SKILL.md` and follow it
- Creates research team, spawns Explore teammates, synthesizes findings

### Phase 3: Planning + Linear Sync (Plan Mode)
- Enter plan mode
- Write implementation plan using research findings (do NOT re-explore)
- Create Linear sub-issues directly (orchestrator does this, NOT sub-agents)
- Exit plan mode for user approval

### Phase 4: Branch Setup (Post-Approval)
- Create feature branch from main

### Phase 5: Implementation (Team-Based)
- Read `.claude/skills/team-implement/SKILL.md` and follow it
- Spawn specialist teammates, map sub-issues to tasks, monitor progress

### Phase 6: Review (Team-Based)
- Read `.claude/skills/team-review/SKILL.md` and follow it
- Parallel pre-PR checks (build, lint, Linear sync, code review)

### Phase 7: Ship (Team-Based)
- Read `.claude/skills/team-ship/SKILL.md` and follow it
- Commit, push, PR, Linear update, team shutdown

## Responsibility Split

| Action | Who |
|--------|-----|
| Create Linear issues | **Orchestrator** (Phase 3, plan mode) |
| Update Linear status during impl | **linear-manager agent** (Phase 5) |
| Create issues during impl if needed | **linear-manager agent** |
| Verify Linear sync before PR | **Orchestrator** (Phase 6) |
| Update parent to "In Review" | **Orchestrator** (Phase 7) |
| Research (codebase exploration) | **Explore agents** in team (Phase 2) |
