---
name: issue-writing
description: Use this skill when writing, reviewing, or discussing issue descriptions, acceptance criteria, or task breakdowns. Ensures consistent, high-quality issue structure that any developer or AI can pick up and execute. Triggers when drafting issues, defining requirements, or when users ask "how should I write this issue?" or "what should the acceptance criteria be?"
---

# Issue Writing Skill

This skill guides the creation of well-structured, actionable Jira issues that any developer or AI can pick up and execute independently.

## When to Use

Apply this skill when:
- Writing or drafting issue descriptions
- Defining acceptance criteria for tasks
- Breaking down features into Subtasks
- Reviewing existing issues for clarity
- Users ask how to document requirements
- Converting conversations into actionable issues

## Issue Structure Template

### For Parent Stories

```
h2. IMPORTANT: Jira Issue Discipline
[Standard discipline rules - see jira-discipline skill]

---

h2. Problem
[1-2 sentences: Why does this feature need to exist?]

h2. Solution
[1-2 sentences: What are we building to solve this?]

h2. High-Level Implementation
[Bullet points: Key technical decisions, patterns, technologies]

h2. Codebase Investigation Findings
[What patterns to follow, similar features, code locations]

h2. Atomic Design Components (if UI)
[Existing components to reuse, new components needed]

h2. Out of Scope / Deferred
[Explicitly list what we're NOT doing in this iteration]
```

### For Subtasks

```
h2. Objective
[1-2 sentences: What specific thing needs to be done?]

h2. Acceptance Criteria
* [Specific, testable criterion 1]
* [Specific, testable criterion 2]
* [Specific, testable criterion 3]

h2. Implementation Notes
* Relevant files: [paths]
* Patterns to follow: [reference parent or existing code]
* Dependencies: [other Subtasks or external factors]

h2. Context
Parent Story: [PROJ-XXX]
Related: [Links to related issues if any]
```

## Writing Good Acceptance Criteria

### The SMART Framework
- **Specific**: Clear about what exactly needs to happen
- **Measurable**: Can objectively verify if it's done
- **Achievable**: Within scope of this single Subtask
- **Relevant**: Directly related to the objective
- **Testable**: Can be validated by running/checking

### Good Examples
```
* User can enter email and password on login form
* Form validates email format before submission
* Successful login redirects to /dashboard
* Failed login shows error message below form
* Loading state shown during API call
```

### Bad Examples
```
* Login works (too vague)
* Good user experience (not measurable)
* Handle all edge cases (not specific)
* Fast performance (not testable without metrics)
```

## Principles for Issue Writing

### 1. Self-Contained Context
An issue should contain everything needed to understand and execute it. Someone reading it for the first time should be able to start work without asking questions.

### 2. What, Not How
Describe WHAT needs to be accomplished, not HOW to do it. Let the implementer make technical decisions within the constraints.

```
Good: "User can filter the product list by category"

Bad: "Add a dropdown component that calls the filterProducts()
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
```
h2. Assumptions
* API endpoint /api/auth/login exists and returns JWT
* Error responses follow standard format { error: string }
```

## Common Patterns

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

### Refactor Subtask
```
h2. Objective
Refactor [component/area] to [improvement].

h2. Current Problem
[Describe the code smell or issue]

h2. Desired State
[Describe what good looks like]

h2. Acceptance Criteria
* [Old pattern] replaced with [new pattern]
* All existing tests pass
* No functional changes to behavior
```

### Bug Fix Subtask
```
h2. Bug Description
[What's happening that shouldn't be]

h2. Expected Behavior
[What should happen instead]

h2. Steps to Reproduce
# [Step 1]
# [Step 2]
# [Observe bug]

h2. Acceptance Criteria
* [Expected behavior works]
* Regression test added
```

## Jira Formatting Notes

Jira uses Wiki markup, not Markdown:
- Headers: `h1.`, `h2.`, `h3.`
- Bold: `*bold*`
- Bullets: `*` or `-`
- Numbered list: `#`
- Code: `{{inline}}` or `{code}block{code}`
- Links: `[title|url]`

## Anti-Patterns to Avoid

- **Vague objectives**: "Improve the dashboard"
- **Missing acceptance criteria**: Assuming it's obvious
- **Implementation prescription**: Over-specifying the how
- **Hidden dependencies**: Not mentioning blockers
- **Scope creep in description**: Adding "nice to haves"

## Real-World Issue Example

### Parent Story (Created by `/planFeature`)

```
h2. IMPORTANT: Jira Issue Discipline

All development work must be tracked through Jira issues.
* Before starting work: Transition issue to "In Progress"
* Upon completion: Transition issue to "Done"
* Missing scope: Create Subtask first, then proceed

A Story is NOT done until all Subtasks are done.

---

h2. Problem
Users cannot reset their password if they forget it, leading to
support tickets and account abandonment.

h2. Solution
Implement a password reset flow via email with secure token validation.

h2. High-Level Implementation
* Use existing email service (SendGrid integration)
* JWT tokens with 1-hour expiry for reset links
* Rate limiting: max 3 reset requests per hour per email

h2. Codebase Investigation Findings
* Auth patterns: src/services/auth/ - follow AuthService pattern
* Email templates: src/templates/email/ - use BaseEmailTemplate
* Similar feature: Email verification flow in src/features/verify/

h2. Out of Scope / Deferred
* SMS-based reset (future iteration)
* Security questions (not planned)
* Admin password reset capability (separate feature)
```

### Subtask (Vertical Slice)

```
h2. Objective
Create the "Forgot Password" form that captures user email and
triggers the reset email.

h2. Acceptance Criteria
* Form displays email input with validation
* Submit button disabled until valid email entered
* Success state shows "Check your email" message
* Error state shows message if email not found (generic for security)
* Loading state shown during API call
* Rate limit error displayed if exceeded

h2. Implementation Notes
* Relevant files: src/features/auth/components/
* Pattern to follow: LoginForm component structure
* API endpoint: POST /api/auth/forgot-password (to be created in SLICE 2)
* Use existing Button, Input, FormField atoms/molecules

h2. Context
Parent Story: PROJ-123
Related: SLICE 2: Create reset email API endpoint
```

## References

### Related Plugin Workflow
- `/planFeature` command - Auto-generates Stories with this structure
- `jira-mvp-story-creator` agent - Creates Subtasks with proper templates
- `execute-issue-jira` agent - Uses acceptance criteria to verify completeness

### Writing Quality Checklist
```
□ Could a new team member understand this without context?
□ Are acceptance criteria specific and testable?
□ Is the scope clear (what's included AND excluded)?
□ Are dependencies and related issues linked?
□ Are relevant code locations referenced?
```

Remember: **A good issue can be executed by anyone who reads it.**
