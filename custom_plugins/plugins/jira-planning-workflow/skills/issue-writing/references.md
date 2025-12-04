# Issue Writing References

## Related Plugin Workflow

| Command/Agent | Purpose |
|---------------|---------|
| `/planFeature` | Auto-generates Stories with proper structure |
| `jira-mvp-story-creator` | Creates Subtasks with templates |
| `execute-issue-jira` | Uses acceptance criteria to verify completeness |

## Writing Quality Checklist

```
□ Could a new team member understand this without context?
□ Are acceptance criteria specific and testable?
□ Is the scope clear (what's included AND excluded)?
□ Are dependencies and related issues linked?
□ Are relevant code locations referenced?
```

## The SMART Framework Expanded

### Specific
```
❌ "Login works"
✓ "User can enter email and password on login form"
```

### Measurable
```
❌ "Good user experience"
✓ "Form submits in under 200ms"
```

### Achievable
```
❌ "Build the entire auth system"
✓ "Create login form with email/password fields"
```

### Testable
```
❌ "Handle all edge cases"
✓ "Show error message for invalid email format"
```

## Common Issue Templates

### Vertical Slice Subtask
```
h2. Objective
Implement end-to-end [feature] from UI to database.

h2. Acceptance Criteria
* UI: [user interaction works]
* API: [endpoint responds correctly]
* Data: [persists/retrieves correctly]
* Error: [failures handled gracefully]
```

### Bug Fix Subtask
```
h2. Bug Description
[What's happening that shouldn't be]

h2. Expected Behavior
[What should happen instead]

h2. Acceptance Criteria
* [Expected behavior works]
* Regression test added
```
