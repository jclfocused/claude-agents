---
name: jira-discipline
description: Use this skill when discussing code changes, implementation work, feature status, or when starting/completing development tasks. Reminds about Jira issue tracking discipline - always having an issue in progress before writing code, transitioning to done, and creating Subtasks for unexpected scope. Triggers when users mention implementing features, writing code, or checking on work status.
---

# Jira Discipline Skill

This skill ensures proper Jira issue tracking discipline is maintained throughout development conversations.

## When to Use

Apply this skill when:
- Users mention they're about to start coding something
- Discussing implementation without mentioning a Jira issue
- Users complete work and might forget to update Jira
- Unexpected scope or bugs are discovered during work
- Checking on feature or work status
- Users mention working on multiple things simultaneously

## Core Discipline Rules

### Rule 1: No Code Without an Issue
**Never write code without a Jira issue in "In Progress" status.**

Before any implementation work:
1. Ensure a Jira issue exists for the work
2. Transition the issue to "In Progress"
3. Only then begin writing code

If no issue exists, create one first.

### Rule 2: Transition Work Complete
**When work is done, immediately transition in Jira.**

Upon completing any task:
1. Commit the code changes
2. Transition the Jira issue to "Done"
3. Don't batch status updates - do it immediately

### Rule 3: Track All Active Work
**If working on multiple features, all relevant issues should be "In Progress".**

Working on a Story AND a bug fix?
- Both issues should be "In Progress"
- Transition both when their respective work completes

### Rule 4: Subtasks Are Mandatory
**A Story is NOT done until all Subtasks are done.**

- Track progress at the Subtask level
- Transition each Subtask to "Done" as completed
- Parent Story stays open until all Subtasks are complete

### Rule 5: Create Missing Scope
**If you discover work that needs doing but has no issue, create a Subtask first.**

Unexpected situations:
- Found a bug while implementing? Create a bug Subtask first
- Need to refactor something? Create a REFACTOR Subtask first
- Missing functionality discovered? Create a new Subtask first

Always: Create Subtask → Transition "In Progress" → Do work → Transition "Done"

## Jira Status Transitions

Unlike Linear where you set status directly, Jira uses **transitions**:

```
To Do → In Progress → Done
          ↓
     (If blocked)
          ↓
       Blocked → In Progress → Done
```

Use `mcp__mcp-atlassian__jira_get_transitions` to see available transitions for an issue, then `mcp__mcp-atlassian__jira_transition_issue` to execute them.

## Gentle Reminders

### When User Says They're Starting Work
> "Before we begin, let's make sure there's a Jira issue for this work. Is there an existing issue we should transition to 'In Progress', or should we create a Subtask?"

### When User Completes Something
> "Great work! Don't forget to transition the Jira issue to 'Done' to keep tracking accurate."

### When Unexpected Work Appears
> "This looks like new scope that wasn't in the original Story. Let's create a Subtask for it before we implement it, so it's properly tracked."

### When Discussing Multiple Tasks
> "Since we're working on multiple things, let's make sure all the relevant Jira issues are transitioned to 'In Progress' so the team has visibility."

## Subtask Naming Convention

Since Jira Subtasks are flat (no nesting), use naming prefixes:
- `SLICE 1: Main vertical slice`
- `SLICE 1.1: Sub-part of slice 1`
- `SLICE 2: Another vertical slice`
- `REFACTOR: Cleanup task`
- `TEST: Testing task`

## Common Scenarios

### Scenario: Quick Fix
User: "Let me just quickly fix this bug..."

Response: "Before making the fix, let's create a bug Subtask in Jira (or find the existing one) and transition it to 'In Progress'. This keeps our tracking accurate even for quick fixes."

### Scenario: Scope Creep
User: "While I'm in here, I should also refactor this..."

Response: "Good catch on the refactoring need! Let's create a REFACTOR Subtask for that work first. That way it's tracked independently and we maintain clear scope on the original Subtask."

### Scenario: Forgotten Update
User: "I finished that feature yesterday."

Response: "Nice! Is the Jira issue transitioned to 'Done'? Let's update it now if not, so the sprint status stays accurate."

## Integration with Workflow

This discipline integrates with:
- `/planFeature` - Creates properly structured Stories with Subtasks
- `/work-on-feature` - Enforces status tracking during execution
- `execute-issue-jira` agent - Automatically manages transitions

The discipline rules are embedded in Story descriptions so any AI or developer working on Subtasks sees them.

Remember: **Jira is the source of truth. Keep it accurate.**
