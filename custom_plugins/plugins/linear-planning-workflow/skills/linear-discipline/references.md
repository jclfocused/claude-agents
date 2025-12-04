# Linear Discipline References

## Related Plugin Commands

| Command/Agent | How It Enforces Discipline |
|---------------|----------------------------|
| `/planFeature` | Creates properly structured issues upfront |
| `/work-on-feature` | Orchestrates work through issues sequentially |
| `execute-issue` agent | Auto-marks "In Progress" before work, "Done" after |
| `linear-mvp-project-creator` | Embeds discipline rules in parent issue descriptions |

## Quick Reference Card

```
┌────────────────────────────────────────────────────────┐
│              LINEAR DISCIPLINE QUICK REFERENCE          │
├────────────────────────────────────────────────────────┤
│                                                         │
│  BEFORE CODING:                                         │
│    1. Find or create Linear issue                       │
│    2. Mark issue "In Progress"                          │
│    3. Then start coding                                 │
│                                                         │
│  AFTER CODING:                                          │
│    1. Commit changes                                    │
│    2. Mark issue "Done"                                 │
│    3. Don't batch updates                               │
│                                                         │
│  UNEXPECTED WORK:                                       │
│    1. Stop coding                                       │
│    2. Create sub-issue first                            │
│    3. Mark "In Progress"                                │
│    4. Then continue                                     │
│                                                         │
│  PARENT ISSUES:                                         │
│    → Not done until ALL sub-issues are done             │
│                                                         │
└────────────────────────────────────────────────────────┘
```

## Why Discipline Matters

### Visibility
- Team knows what's being worked on
- Stakeholders can track progress
- Blockers are surfaced early

### Traceability
- Every code change linked to an issue
- History of what was done and why
- Easy to understand past decisions

### Accountability
- Clear ownership of work
- Measurable progress
- Prevents work from falling through cracks

## External Resources

- [Linear Documentation](https://linear.app/docs)
- [Issue Tracking Best Practices](https://linear.app/method)
