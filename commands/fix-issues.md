---
description: Create Linear issues for reported bugs or problems
argument-hint: <bug description, logs, error messages, etc.>
---

You are about to create Linear issues for reported bugs or problems.

## Bug/Issue Description
$ARGUMENTS

## Instructions

Use the **create-bug** agent to create issues for these problems. The agent will:

1. **Analyze the reported problems** to understand:
   - What error or bug is occurring
   - Relevant error messages or logs
   - Steps to reproduce (if provided)
   - Impact on the system

2. **Investigate the codebase** to understand:
   - Where the problem likely exists
   - Related code areas that may be affected
   - Similar issues or patterns

3. **Create Linear issues** for each problem with:
   - Clear bug description
   - Reproduction steps (if available)
   - Error messages/logs included
   - Acceptance criteria (how to verify the fix)
   - Associated to the specified project
   - Status set to "Todo"
   - Appropriate labels (typically "bug")

4. **Break down complex bugs** into:
   - Main issue with description
   - Sub-issues for related problems or investigation steps
   - All issues associated to the project

## Critical Rules

**ONE ISSUE PER BUG**: Each distinct bug or problem should be its own Linear issue.

**PROJECT ASSOCIATION**: All issues must be associated to a Linear project. If no project is specified, you may need to query available projects or ask the user.

**TODO STATUS**: All issues created must be set to "Todo" status (never "Triage").

**APPROPRIATE LABELS**: Apply relevant labels like "bug" to help categorize the issues.

**CLEAR DESCRIPTIONS**: Include error messages, logs, and any reproduction steps in the issue description.

Launch the agent now with the bug/issue description.

