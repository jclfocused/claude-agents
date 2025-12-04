# Linear Discipline Examples

## Example: Full Discipline Flow

```
User: "I want to add a dark mode toggle"

✓ CORRECT FLOW:
1. Check Linear for existing issue → None found
2. Create issue: "Add dark mode toggle"
3. Mark issue "In Progress"
4. Implement feature
5. Discover need for color token refactor
6. STOP → Create sub-issue "Refactor color tokens for theming"
7. Mark refactor issue "In Progress"
8. Complete refactor → Mark "Done"
9. Continue dark mode → Complete → Mark "Done"
10. All sub-issues done → Parent can be marked "Done"

✗ WRONG FLOW:
1. Start coding dark mode immediately
2. Refactor colors "while in there"
3. Finish everything
4. Create issue after the fact
5. Mark as "Done" immediately
   → No tracking, no visibility, no traceability!
```

---

## Scenario: Quick Fix

**User**: "Let me just quickly fix this bug..."

**Response**: "Before making the fix, let's create a bug issue in Linear (or find the existing one) and mark it 'In Progress'. This keeps our tracking accurate even for quick fixes."

**Why it matters**:
- Bug fixes without issues get lost in history
- No way to track how often bugs occur
- No link between code change and reason

---

## Scenario: Scope Creep

**User**: "While I'm in here, I should also refactor this..."

**Response**: "Good catch on the refactoring need! Let's create a separate sub-issue for that refactor work first. That way it's tracked independently and we maintain clear scope on the original issue."

**Why it matters**:
- Original issue stays focused
- Refactor can be prioritized separately if needed
- Clear separation of concerns in git history

---

## Scenario: Forgotten Update

**User**: "I finished that feature yesterday."

**Response**: "Nice! Is the Linear issue marked as 'Done'? Let's update it now if not, so the project status stays accurate."

**Why it matters**:
- Project velocity tracking is accurate
- Team knows work is complete
- Stakeholders have visibility

---

## Scenario: Multiple Active Tasks

**User**: "I'm working on the auth feature but also fixing that CSS bug."

**Response**: "Since we're working on multiple things, let's make sure both Linear issues are marked 'In Progress' so the team has visibility into all active work."

**Why it matters**:
- Team knows what you're actively working on
- Prevents duplicate work
- Clear picture of work in flight

---

## The Discipline Checklist

Before starting any work:
```
□ Issue exists in Linear
□ Issue is assigned to me
□ Issue is marked "In Progress"
□ I understand the acceptance criteria
```

When discovering new scope:
```
□ Stop current work
□ Create new sub-issue
□ Add to parent issue
□ Mark new issue "In Progress"
□ Resume work
```

When completing work:
```
□ Code is committed
□ Tests pass
□ Issue is marked "Done"
□ Update happened immediately (not batched)
```
