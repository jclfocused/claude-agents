# Sync Patterns: Plan File ↔ Linear

Patterns for keeping the plan file and Linear issues synchronized. **The orchestrator does all Linear operations directly** — no sub-agent delegation.

## Mapping Plan Sections to Linear Issues

### Section-to-Issue Mapping

Plan file sections map to Linear sub-issues:

```markdown
# Plan File Structure          →  Linear Structure

## Overview                    →  Parent Issue Description
## Step 1: [Migration]         →  Sub-issue 1 (tagged [Migration])
## Step 2: [Backend]           →  Sub-issue 2 (tagged [Backend])
## Step 3: [Frontend]          →  Sub-issue 3 (tagged [Frontend])
## Verification                →  Part of parent issue
```

### Tracking Mappings

Keep a mapping in the plan file to track relationships:

```markdown
## Linear Issue Mappings
- Parent: LAS-808 (uuid: abc-123)
- Step 1 [Migration]: LAS-809 (uuid: def-456)
- Step 2 [Backend]: LAS-810 (uuid: ghi-789)
- Step 3 [Frontend]: LAS-811 (uuid: jkl-012)
```

## Sync Operations

### Adding a New Section

When a new section is added to the plan, create a sub-issue directly:

```
mcp__linear__create_issue(
  title: "[Backend] Add student results API",
  team: "LaserFocused",
  parentId: "<parent-uuid>",
  state: "Todo",
  description: "## Acceptance Criteria\n- [ ] Returns student answers\n- [ ] Includes audio URLs"
)
```

### Modifying a Section

When a section is modified, update the corresponding issue directly:

```
mcp__linear__update_issue(
  issueId: "<sub-issue-uuid>",
  description: "[updated section content]"
)
```

### Removing a Section

When a section is removed:

1. **Ask user for confirmation** before canceling
2. Cancel the issue directly:

```
mcp__linear__update_issue(
  issueId: "<sub-issue-uuid>",
  state: "Canceled"
)
```

**Important:** Never delete issues — cancel them so there's a record.

## Status Management

### Issue Status Flow

**CRITICAL: ALL new issues MUST be created with status "Todo"**

```
Planning (plan mode)          →  "Todo" (ALWAYS)
Approved & Ready              →  "Todo"
Work Started (implementation) →  "In Progress" (linear-manager handles this)
PR Created                    →  "In Review" (orchestrator handles this)
Merged/Complete               →  "Done"
Abandoned                     →  "Canceled"
```

### Who Manages Status at Each Phase

| Phase | Who | What |
|-------|-----|------|
| Planning | Orchestrator | Creates issues, all "Todo" |
| Implementation | linear-manager agent | Updates to "In Progress" / "Done" |
| Review | Orchestrator | Verifies all "Done" |
| Ship | Orchestrator | Sets parent to "In Review" |

## Sync Triggers

### When to Sync

Sync to Linear at these points:

1. **Initial creation** - When first setting up Linear tracking
2. **Major section changes** - Adding/removing steps
3. **Content updates** - When acceptance criteria change significantly
4. **Before ExitPlanMode** - Final sync to ensure consistency

### When NOT to Sync

Don't sync for:

- Minor wording changes (typos, formatting)
- Adding internal notes/comments in plan
- Reordering within a section

## Error Handling

### Linear MCP Unavailable

If Linear MCP is not accessible:

1. **Warn user** that Linear sync is unavailable
2. **Continue planning** in plan file only
3. **Offer to sync later** when Linear is available

### Verification Before ExitPlanMode

Always verify before exiting plan mode:

1. Every major plan section has a Linear sub-issue
2. Parent issue description matches plan overview
3. All sub-issues are in "Todo" status
4. Sub-issue IDs are recorded in the plan file

```
mcp__linear__get_issue(id: "<parent-id>", includeRelations: true)
```

Check the children list matches the plan sections.
