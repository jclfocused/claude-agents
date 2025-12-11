# Issue Writing References

## Related Plugin Workflow

| Command/Agent | Purpose |
|---------------|---------|
| `/planFeature` | Auto-generates parent issues with proper structure |
| `linear-mvp-project-creator` | Creates sub-issues with templates |
| `execute-issue` | Uses acceptance criteria to verify completeness |

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

### Relevant
```
❌ "Also add dark mode while we're here"
✓ "Login form follows existing form patterns"
```

### Testable
```
❌ "Handle all edge cases"
✓ "Show error message for invalid email format"
```

## Common Issue Templates

### Vertical Slice Issue
```markdown
## Objective
Implement end-to-end [feature] from UI to database.

## Acceptance Criteria
- [ ] UI: [user interaction works]
- [ ] API: [endpoint responds correctly]
- [ ] Data: [persists/retrieves correctly]
- [ ] Error: [failures handled gracefully]
```

### Refactor Issue
```markdown
## Objective
Refactor [component/area] to [improvement].

## Acceptance Criteria
- [ ] [Old pattern] replaced with [new pattern]
- [ ] All existing tests pass
- [ ] No functional changes to behavior
```

### Bug Fix Issue
```markdown
## Bug Description
[What's happening that shouldn't be]

## Expected Behavior
[What should happen instead]

## Acceptance Criteria
- [ ] [Expected behavior works]
- [ ] Regression test added
```

## Mermaid Diagram Quick Reference

Linear renders Mermaid diagrams natively. **Always include diagrams when flows need to be shown or understood.**

### Flowchart (Most Common)
```markdown
```mermaid
flowchart TD
    A[User Action] --> B{Validation}
    B -->|Valid| C[Process Request]
    B -->|Invalid| D[Show Error]
    C --> E[Update Database]
    E --> F[Return Response]
```
```

### Sequence Diagram (API/Service Flows)
```markdown
```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant A as API
    participant D as Database

    U->>F: Click Submit
    F->>A: POST /api/data
    A->>D: INSERT query
    D-->>A: Success
    A-->>F: 200 OK
    F-->>U: Show confirmation
```
```

### State Diagram (Status Transitions)
```markdown
```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Pending: Submit
    Pending --> Approved: Approve
    Pending --> Rejected: Reject
    Approved --> Published: Publish
    Rejected --> Draft: Edit
    Published --> [*]
```
```

### Entity Relationship Diagram (Data Models)
```markdown
```mermaid
erDiagram
    USER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    PRODUCT ||--o{ LINE_ITEM : "ordered in"
    USER {
        int id PK
        string email
        string name
    }
    ORDER {
        int id PK
        int user_id FK
        date created_at
    }
```
```

### When to Use Each Type
| Diagram Type | Best For |
|--------------|----------|
| `flowchart TD/LR` | User journeys, decision trees, process flows |
| `sequenceDiagram` | API calls, service-to-service communication |
| `stateDiagram-v2` | Status workflows, lifecycle management |
| `erDiagram` | Database schemas, data relationships |
| `classDiagram` | Component architecture, class hierarchies |
