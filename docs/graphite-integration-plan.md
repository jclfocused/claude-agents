# Graphite Integration Plan for Linear/Jira Workflows

This document details the implementation plan for integrating Graphite stacked PRs into the Linear and Jira planning workflows.

## Overview

Enable the `work-on-feature` commands to optionally use Graphite for stacked PRs, where each sub-issue becomes a stacked PR instead of commits on a single branch.

## Files to Create

### 1. `linear-planning-workflow/agents/execute-issue-graphite.md`

New agent for executing Linear issues with Graphite stacking.

### 2. `jira-planning-workflow/agents/execute-issue-jira-graphite.md`

New agent for executing Jira issues with Graphite stacking.

## Files to Modify

### 1. `linear-planning-workflow/commands/work-on-feature.md`

Add Graphite detection and workflow branching.

### 2. `jira-planning-workflow/commands/work-on-feature.md`

Add Graphite detection and workflow branching.

---

## Detailed Specifications

### Branch Naming Convention

| Branch Type | Format | Example |
|-------------|--------|---------|
| **Base branch** | `{prefix}-{number}-{type}-{description}` | `wha-123-feat-user-authentication` |
| **Sub-issue branches** | `{prefix}-{number}-{description}` | `wha-456-add-login-form` |

- `type` = `feat`, `bug`, or `chore` (base branch only)
- Sub-issue branches skip the type prefix
- All lowercase, hyphens for spaces

### Branch Name Generation Logic

```
Input:
  - issue_key: "WHA-456"
  - title: "Add Login Form"

Steps:
  1. Lowercase the issue key: "wha-456"
  2. Lowercase the title: "add login form"
  3. Replace spaces with hyphens: "add-login-form"
  4. Remove special characters
  5. Combine: "wha-456-add-login-form"

Output:
  - branch_name: "wha-456-add-login-form"
  - commit_message: "WHA-456: Add Login Form"
```

---

## Work-on-Feature Command Flow

### Updated Flow (with Graphite option)

```
/work-on-feature auth-feature

1. Gather Feature Context via Sub-Agent (unchanged)
   - Fetch parent issue and sub-issues

2. Check Graphite Availability
   - Try to detect mcp__graphite__run_gt_cmd tool
   - If available, proceed to step 3
   - If not available, skip to step 5 (normal flow)

3. Ask User About Graphite (NEW)
   Question: "Graphite is available. Use stacked PRs for this feature?"
   - header: "Graphite Stacking"
   - multiSelect: false
   - options:
     - { label: "Yes, use Graphite", description: "Each issue becomes a stacked PR" }
     - { label: "No, use normal git", description: "All work on single branch" }

4. If Using Graphite - Trunk Setup (NEW)

   **Key Insight**: Graphite recommends NOT creating empty branches. Each branch should have actual code changes. The stack of sub-issue branches IS the feature.

   Question: "What branch should sub-issues stack on top of?"
   - header: "Trunk Branch"
   - multiSelect: false
   - options:
     - { label: "develop", description: "Stack on develop (recommended)" }
     - { label: "main", description: "Stack on main" }
     - { label: "Current branch", description: "Stack on your current branch" }

   Execute:
   ```bash
   gt sync
   gt checkout {trunk_branch}  # develop, main, or current
   # No feature branch created - first sub-issue will create its branch on trunk
   ```

   **Stack Structure**:
   ```
   {trunk} <- sub-issue-1 <- sub-issue-2 <- sub-issue-3
   ```

   The first sub-issue creates its branch directly on trunk. Subsequent sub-issues stack on top of each other. When PRs merge, they merge into trunk in order (bottom to top).

5. Normal Branch Setup (existing flow - if not using Graphite)
   - Same as current implementation

6. Work Loop

   For each sub-issue (SEQUENTIAL):

   IF using Graphite:
     - Spawn: execute-issue-graphite (Linear) or execute-issue-jira-graphite (Jira)
     - Agent writes code
     - Agent runs: gt create --all --message "{KEY}: {title}" {branch-name}
     - Agent updates issue with branch name
     - Agent marks issue "In Review" (not "Done")
     - Agent returns success

     ORCHESTRATOR after each issue:
     - gt submit --no-interactive --publish
     - gt sync
     - (User can now review PR while next issue is worked on)

   ELSE (normal flow):
     - Spawn: execute-issue (Linear) or execute-issue-jira (Jira)
     - Agent writes code, commits, marks "Done"

7. Completion

   IF using Graphite:
     - gt submit --stack --no-interactive --publish (final ensure all submitted)
     - Report stack PR URLs
     - Remind: "Issues are 'In Review'. Graphite marks 'Done' when PRs merge."

   ELSE:
     - Normal completion message
```

---

## Execute-Issue-Graphite Agent Specifications

### Tools Required

All tools from `execute-issue` PLUS:
- `mcp__graphite__run_gt_cmd`
- `mcp__graphite__learn_gt`

### Input Parameters

```
- Issue UUID/Key: The specific issue to work on
- Parent Issue ID/Key: The parent feature issue
- Feature State Summary: Current state of other issues
- Base Branch Name: The feature branch this stacks onto (for reference)
```

### Execution Workflow

```
Step 1: Verify MCP Access
- Test Linear/Jira MCP tools
- Test Graphite MCP tools
- If either unavailable, STOP and report

Step 2: Gather Full Context
- Get issue details (same as normal agent)
- Get parent issue description (architecture, patterns)
- Review feature state

Step 3: Learn Repository Patterns
- Use Glob/Grep/Read to understand patterns
- Check for existing components (atomic design)

Step 4: Mark Issue "In Progress"
- Linear: mcp__linear-server__update_issue with state: "In Progress"
- Jira: mcp__mcp-atlassian__jira_transition_issue

Step 5: Execute Work (MVP Scope Only)
- Write code directly using Edit/Write tools
- NEVER build or run the application
- Implement ONLY what the issue specifies
- Follow parent issue architecture
- Reuse existing components

Step 6: Create Stacked Branch with Graphite
- Generate branch name: {key}-{sanitized-title}
- Execute:
  ```bash
  gt create --all --message "{KEY}: {title}" {branch-name}
  ```
- Verify branch created with gt log

Step 7: Update Issue with Branch Name
- Linear: Update description or add comment with branch name
- Jira: Add comment with branch name
- Format: "**Graphite Branch:** `{branch-name}`"

Step 8: Mark Issue "In Review"
- Linear: Update state to "In Review"
- Jira: Transition to "In Review" status
- NOTE: Do NOT mark as "Done" - Graphite handles that on PR merge

Step 9: Return Summary
```
### Issue Execution Complete: [Issue Title]

**Issue Key:** {KEY}
**Status:** In Review
**Graphite Branch:** {branch-name}

### Work Completed
- [Summary of implementation]
- [Key changes]
- [Acceptance criteria met]

### Files Modified
- path/to/file1.ts
- path/to/file2.tsx

### Patterns Followed
- [Architecture patterns applied]
- [Components reused]

### Graphite
- Branch created: {branch-name}
- Commit: {KEY}: {title}
- Ready for orchestrator to submit

Ready for next issue.
```
```

### Key Differences from Normal Agent

| Aspect | Normal Agent | Graphite Agent |
|--------|--------------|----------------|
| Committing | `git add && git commit` | `gt create --all --message "..." {branch}` |
| Pushing | Never | Never (orchestrator handles) |
| Branch | Works on existing | Creates stacked branch per issue |
| Final status | "Done" | "In Review" |
| Issue tracking | N/A | Adds branch name to issue |

### What the Agent Does NOT Do

- Does NOT run `gt submit` (orchestrator handles)
- Does NOT mark issue as "Done" (Graphite handles on merge)
- Does NOT build, run, or test the application
- Does NOT use GitHub CLI

---

## Graphite Commands Reference

### Commands Used by Agents

```bash
# Create stacked branch with specific name
gt create --all --message "{KEY}: {title}" {branch-name}

# View current stack (for verification)
gt log
```

### Commands Used by Orchestrator

```bash
# Initial setup
gt sync
gt checkout {base_branch}

# After each issue completes
gt submit --no-interactive --publish
gt sync

# Final submission
gt submit --stack --no-interactive --publish
```

---

## Status Flow

### Linear Statuses

```
Normal flow:  Todo → In Progress → Done
Graphite:     Todo → In Progress → In Review → (Done on PR merge)
```

### Jira Statuses

```
Normal flow:  To Do → In Progress → Done
Graphite:     To Do → In Progress → In Review → (Done on PR merge)
```

---

## Error Handling

### Graphite Not Initialized

If `gt` commands fail because repo not initialized:
```bash
gt init
# Select trunk branch (main/develop)
```

### Conflicts During Stack

If conflicts occur:
1. Stop immediately
2. Report which issue/branch has conflicts
3. User can:
   - `gt checkout {branch}` to fix
   - `gt modify -a` to amend
   - Resume with `/work-on-feature`

### Issue Fails Mid-Stack

1. Stop - don't continue to next issue
2. Report failure with branch name
3. Since each issue is submitted after completion, partial stack is visible
4. User fixes and resumes

---

## Testing Checklist

Before considering implementation complete:

- [ ] Graphite detection works (available vs not available)
- [ ] User can opt-in/opt-out of Graphite
- [ ] Base branch selection works (main/develop/current)
- [ ] Feature branch naming convention applied correctly
- [ ] Sub-issue branch naming convention applied correctly
- [ ] `gt create` with explicit branch name works
- [ ] Issues updated with branch names
- [ ] Issues marked "In Review" (not "Done")
- [ ] Orchestrator submits after each issue
- [ ] Orchestrator syncs after submit
- [ ] Final stack submission works
- [ ] Normal (non-Graphite) flow still works unchanged

---

## Implementation Order

1. Create `execute-issue-graphite.md` (Linear)
2. Create `execute-issue-jira-graphite.md` (Jira)
3. Update `work-on-feature.md` (Linear)
4. Update `work-on-feature.md` (Jira)
5. Test full workflow
6. Commit all changes
