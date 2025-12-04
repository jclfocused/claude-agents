---
name: issue-writing
description: Use this skill when writing, reviewing, or discussing issue descriptions, acceptance criteria, or task breakdowns. Ensures consistent, high-quality issue structure that any developer or AI can pick up and execute. Triggers when drafting issues, defining requirements, or when users ask "how should I write this issue?" or "what should the acceptance criteria be?"
---

# Issue Writing Skill

This skill guides the creation of well-structured, actionable Linear issues that any developer or AI can pick up and execute independently.

## When to Use

Apply this skill when:
- Writing or drafting issue descriptions
- Defining acceptance criteria for tasks
- Breaking down features into sub-issues
- Reviewing existing issues for clarity
- Users ask how to document requirements
- Converting conversations into actionable issues

## Issue Structure Template

### For Parent Feature Issues

```markdown
## IMPORTANT: Linear Issue Discipline
[Standard discipline rules - see linear-discipline skill]

---

## Problem
[1-2 sentences: Why does this feature need to exist?]

## Solution
[1-2 sentences: What are we building to solve this?]

## High-Level Implementation
[Bullet points: Key technical decisions, patterns, technologies]

## Codebase Investigation Findings
[What patterns to follow, similar features, code locations]

## Atomic Design Components (if UI)
[Existing components to reuse, new components needed]

## Out of Scope / Deferred
[Explicitly list what we're NOT doing in this iteration]
```

### For Sub-Issues / Tasks

```markdown
## Objective
[1-2 sentences: What specific thing needs to be done?]

## Acceptance Criteria
- [ ] [Specific, testable criterion 1]
- [ ] [Specific, testable criterion 2]
- [ ] [Specific, testable criterion 3]

## Implementation Notes
- Relevant files: [paths]
- Patterns to follow: [reference parent or existing code]
- Dependencies: [other issues or external factors]

## Context
Parent: [Link to parent issue]
Related: [Links to related issues if any]
```

## Writing Good Acceptance Criteria

### The SMART Framework
- **Specific**: Clear about what exactly needs to happen
- **Measurable**: Can objectively verify if it's done
- **Achievable**: Within scope of this single issue
- **Relevant**: Directly related to the objective
- **Testable**: Can be validated by running/checking

### Good Examples
```markdown
- [ ] User can enter email and password on login form
- [ ] Form validates email format before submission
- [ ] Successful login redirects to /dashboard
- [ ] Failed login shows error message below form
- [ ] Loading state shown during API call
```

### Bad Examples
```markdown
- [ ] Login works (too vague)
- [ ] Good user experience (not measurable)
- [ ] Handle all edge cases (not specific)
- [ ] Fast performance (not testable without metrics)
```

## Principles for Issue Writing

### 1. Self-Contained Context
An issue should contain everything needed to understand and execute it. Someone reading it for the first time should be able to start work without asking questions.

### 2. What, Not How
Describe WHAT needs to be accomplished, not HOW to do it. Let the implementer make technical decisions within the constraints.

```markdown
# Good
"User can filter the product list by category"

# Bad
"Add a dropdown component that calls the filterProducts()
function with the selected category ID parameter"
```

### 3. Appropriate Granularity
- Too big: "Build the authentication system"
- Too small: "Add import statement for React"
- Just right: "Create login form with email/password fields and validation"

### 4. Link to Resources
Include relevant links:
- Design mockups or Figma links
- API documentation
- Related PRs or issues
- Relevant code files

### 5. State Assumptions
If there are assumptions made, state them explicitly:
```markdown
## Assumptions
- API endpoint /api/auth/login exists and returns JWT
- Error responses follow standard format { error: string }
```

## Common Patterns

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

## Current Problem
[Describe the code smell or issue]

## Desired State
[Describe what good looks like]

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

## Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Observe bug]

## Acceptance Criteria
- [ ] [Expected behavior works]
- [ ] Regression test added
```

## Anti-Patterns to Avoid

- **Vague objectives**: "Improve the dashboard"
- **Missing acceptance criteria**: Assuming it's obvious
- **Implementation prescription**: Over-specifying the how
- **Hidden dependencies**: Not mentioning blockers
- **Scope creep in description**: Adding "nice to haves"

## Real-World Issue Example

### Parent Feature Issue (Created by `/planFeature`)

```markdown
## IMPORTANT: Linear Issue Discipline

All development work must be tracked through Linear issues.
- Before starting work: Mark issue "In Progress"
- Upon completion: Mark issue "Done"
- Missing scope: Create sub-issue first, then proceed

A parent issue is NOT done until all sub-issues are done.

---

## Problem
Users cannot reset their password if they forget it, leading to
support tickets and account abandonment.

## Solution
Implement a password reset flow via email with secure token validation.

## High-Level Implementation
- Use existing email service (SendGrid integration)
- JWT tokens with 1-hour expiry for reset links
- Rate limiting: max 3 reset requests per hour per email

## Codebase Investigation Findings
- Auth patterns: src/services/auth/ - follow AuthService pattern
- Email templates: src/templates/email/ - use BaseEmailTemplate
- Similar feature: Email verification flow in src/features/verify/

## Out of Scope / Deferred
- SMS-based reset (future iteration)
- Security questions (not planned)
- Admin password reset capability (separate feature)
```

### Sub-Issue (Vertical Slice)

```markdown
## Objective
Create the "Forgot Password" form that captures user email and
triggers the reset email.

## Acceptance Criteria
- [ ] Form displays email input with validation
- [ ] Submit button disabled until valid email entered
- [ ] Success state shows "Check your email" message
- [ ] Error state shows message if email not found (generic for security)
- [ ] Loading state shown during API call
- [ ] Rate limit error displayed if exceeded

## Implementation Notes
- Relevant files: src/features/auth/components/
- Pattern to follow: LoginForm component structure
- API endpoint: POST /api/auth/forgot-password (to be created in SLICE 2)
- Use existing Button, Input, FormField atoms/molecules

## Context
Parent: [Password Reset Feature]
Related: [SLICE 2: Create reset email API endpoint]
```

## References

### Related Plugin Workflow
- `/planFeature` command - Auto-generates parent issues with this structure
- `linear-mvp-project-creator` agent - Creates sub-issues with proper templates
- `execute-issue` agent - Uses acceptance criteria to verify completeness

### Writing Quality Checklist
```
□ Could a new team member understand this without context?
□ Are acceptance criteria specific and testable?
□ Is the scope clear (what's included AND excluded)?
□ Are dependencies and related issues linked?
□ Are relevant code locations referenced?
```

Remember: **A good issue can be executed by anyone who reads it.**
