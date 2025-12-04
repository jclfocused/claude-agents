# Issue Writing Examples

## Example: Parent Story

### Password Reset Feature

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

---

## Example: Subtask (Vertical Slice)

### SLICE 1: Forgot Password Form

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
* API endpoint: POST /api/auth/forgot-password (SLICE 2)
* Use existing Button, Input, FormField atoms/molecules

h2. Context
Parent Story: PROJ-123
Related: SLICE 2: Create reset email API endpoint
```

---

## Good vs Bad Acceptance Criteria

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

---

## Granularity Examples

| Size | Example |
|------|---------|
| **Too Big** | "Build the authentication system" |
| **Too Small** | "Add import statement for React" |
| **Just Right** | "Create login form with email/password fields and validation" |
