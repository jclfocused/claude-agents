---
name: linear-discipline
description: Use this skill when discussing code changes, implementation work, feature status, or when starting/completing development tasks. Reminds about Linear issue tracking discipline - always having an issue in progress before writing code, marking work as done, and creating issues for unexpected scope. Triggers when users mention implementing features, writing code, or checking on work status.
---

# Linear Discipline Skill

This skill ensures proper Linear issue tracking discipline is maintained throughout development conversations.

## When to Use

Apply this skill when:
- Users mention they're about to start coding something
- Discussing implementation without mentioning a Linear issue
- Users complete work and might forget to update Linear
- Unexpected scope or bugs are discovered during work
- Checking on feature or work status
- Users mention working on multiple things simultaneously

## Core Discipline Rules

### Rule 1: No Code Without an Issue
**Never write code without a Linear issue in "In Progress" status.**

Before any implementation work:
1. Ensure a Linear issue exists for the work
2. Mark the issue as "In Progress"
3. Only then begin writing code

If no issue exists, create one first.

### Rule 2: Mark Work Complete
**When work is done, immediately update Linear.**

Upon completing any task:
1. Commit the code changes
2. Mark the Linear issue as "Done"
3. Don't batch status updates - do it immediately

### Rule 3: Track All Active Work
**If working on multiple features, all relevant issues should be "In Progress".**

Working on authentication AND a bug fix?
- Both issues should be "In Progress"
- Update both when their respective work completes

### Rule 4: Sub-Issues Are Mandatory
**A parent issue is NOT done until all sub-issues are done.**

- Track progress at the sub-issue level
- Mark each sub-issue "Done" as completed
- Parent issue stays open until all children are complete

### Rule 5: Create Missing Scope
**If you discover work that needs doing but has no issue, create one first.**

Unexpected situations:
- Found a bug while implementing? Create a bug issue first
- Need to refactor something? Create a refactor issue first
- Missing functionality discovered? Create a sub-issue first

Always: Create issue → Mark "In Progress" → Do work → Mark "Done"

## Gentle Reminders

### When User Says They're Starting Work
> "Before we begin, let's make sure there's a Linear issue for this work. Is there an existing issue we should mark 'In Progress', or should we create one?"

### When User Completes Something
> "Great work! Don't forget to mark the Linear issue as 'Done' to keep tracking accurate."

### When Unexpected Work Appears
> "This looks like new scope that wasn't in the original issue. Let's create a sub-issue for it before we implement it, so it's properly tracked."

### When Discussing Multiple Tasks
> "Since we're working on multiple things, let's make sure all the relevant Linear issues are marked 'In Progress' so the team has visibility."

## Status Flow

```
Todo → In Progress → Done
         ↓
    (If blocked)
         ↓
      Blocked → In Progress → Done
```

## Common Scenarios

### Scenario: Quick Fix
User: "Let me just quickly fix this bug..."

Response: "Before making the fix, let's create a bug issue in Linear (or find the existing one) and mark it 'In Progress'. This keeps our tracking accurate even for quick fixes."

### Scenario: Scope Creep
User: "While I'm in here, I should also refactor this..."

Response: "Good catch on the refactoring need! Let's create a separate sub-issue for that refactor work first. That way it's tracked independently and we maintain clear scope on the original issue."

### Scenario: Forgotten Update
User: "I finished that feature yesterday."

Response: "Nice! Is the Linear issue marked as 'Done'? Let's update it now if not, so the project status stays accurate."

## Integration with Workflow

This discipline integrates with:
- `/planFeature` - Creates properly structured issues
- `/work-on-feature` - Enforces status tracking during execution
- `execute-issue` agent - Automatically manages status transitions

The discipline rules are embedded in parent issue descriptions so any AI or developer working on sub-issues sees them.

Remember: **Linear is the source of truth. Keep it accurate.**
