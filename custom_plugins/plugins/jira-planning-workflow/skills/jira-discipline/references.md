# Jira Discipline References

## Related Plugin Commands

| Command/Agent | How It Enforces Discipline |
|---------------|----------------------------|
| `/planFeature` | Creates properly structured Stories with Subtasks |
| `/work-on-feature` | Orchestrates work through Subtasks sequentially |
| `execute-issue-jira` agent | Auto-transitions "In Progress" before work, "Done" after |
| `jira-mvp-story-creator` | Embeds discipline rules in Story descriptions |

## Quick Reference Card

```
┌────────────────────────────────────────────────────────┐
│              JIRA DISCIPLINE QUICK REFERENCE            │
├────────────────────────────────────────────────────────┤
│                                                         │
│  BEFORE CODING:                                         │
│    1. Find or create Jira issue                         │
│    2. Transition issue to "In Progress"                 │
│    3. Then start coding                                 │
│                                                         │
│  AFTER CODING:                                          │
│    1. Commit changes                                    │
│    2. Transition issue to "Done"                        │
│    3. Don't batch updates                               │
│                                                         │
│  UNEXPECTED WORK:                                       │
│    1. Stop coding                                       │
│    2. Create Subtask first                              │
│    3. Transition to "In Progress"                       │
│    4. Then continue                                     │
│                                                         │
│  PARENT STORIES:                                        │
│    → Not done until ALL Subtasks are done               │
│                                                         │
└────────────────────────────────────────────────────────┘
```

## Subtask Naming Convention

Since Jira Subtasks are flat (no nesting), use naming prefixes:
```
SLICE 1: Main vertical slice
SLICE 1.1: Sub-part of slice 1
SLICE 2: Another vertical slice
REFACTOR: Cleanup task
TEST: Testing task
BUG: Bug fix discovered during work
```

## Why Discipline Matters

- **Visibility** - Team knows what's being worked on
- **Traceability** - Every code change linked to an issue
- **Accountability** - Clear ownership and measurable progress
