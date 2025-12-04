# Jira Discipline Examples

## Example: Full Discipline Flow

```
User: "I want to add a dark mode toggle"

✓ CORRECT FLOW:
1. Check Jira for existing issue → None found
2. Create Subtask: "SLICE 1: Add dark mode toggle"
3. Transition Subtask to "In Progress"
4. Implement feature
5. Discover need for color token refactor
6. STOP → Create Subtask "REFACTOR: Color tokens for theming"
7. Transition refactor Subtask to "In Progress"
8. Complete refactor → Transition to "Done"
9. Continue dark mode → Complete → Transition to "Done"
10. All Subtasks done → Parent Story can be transitioned to "Done"

✗ WRONG FLOW:
1. Start coding dark mode immediately
2. Refactor colors "while in there"
3. Finish everything
4. Create issue after the fact
5. Transition to "Done" immediately
   → No tracking, no visibility, no traceability!
```

---

## Scenario: Quick Fix

**User**: "Let me just quickly fix this bug..."

**Response**: "Before making the fix, let's create a BUG Subtask in Jira (or find the existing one) and transition it to 'In Progress'. This keeps our tracking accurate even for quick fixes."

---

## Scenario: Scope Creep

**User**: "While I'm in here, I should also refactor this..."

**Response**: "Good catch! Let's create a REFACTOR Subtask for that work first. That way it's tracked independently and we maintain clear scope on the original Subtask."

---

## Scenario: Forgotten Update

**User**: "I finished that feature yesterday."

**Response**: "Nice! Is the Jira Subtask transitioned to 'Done'? Let's update it now if not, so the sprint status stays accurate."

---

## The Discipline Checklist

Before starting any work:
```
□ Issue exists in Jira
□ Issue is assigned to me
□ Issue is transitioned to "In Progress"
□ I understand the acceptance criteria
```

When discovering new scope:
```
□ Stop current work
□ Create new Subtask with prefix (SLICE, REFACTOR, BUG, TEST)
□ Transition new Subtask to "In Progress"
□ Resume work
```

When completing work:
```
□ Code is committed
□ Tests pass
□ Subtask is transitioned to "Done"
□ Update happened immediately (not batched)
```
