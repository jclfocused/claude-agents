---
description: Create a single Linear issue with codebase research and optional feature parent association
argument-hint: <issue description>
---

You are about to create a single Linear issue with proper codebase investigation.

## Issue Description
$ARGUMENTS

## Step 1: Feature Root Selection

First, list all existing Feature Root issues for optional parent association:

1. Use `mcp__linear-server__list_issue_labels` to find the "Feature Root" label ID
2. Use `mcp__linear-server__list_issues` with `label: "Feature Root"` to fetch all root feature issues
3. **Filter to active features**: Exclude issues with status "Done" or "Canceled"
4. Use `AskUserQuestion` to prompt the user with all active features plus a "no parent" option:
   - **question**: "Should this issue be associated with a feature parent?"
   - **header**: "Parent Feature Selection"
   - **multiSelect**: false
   - **options**: Build array with:
     - First option: `{ label: "No Parent", description: "Create standalone issue without parent association" }`
     - Remaining options: One for each feature root with:
       - `label`: "[Issue ID] - [Feature Title] - [Status]"
       - `description`: First 100 chars of issue description or "No description"
5. Store the selected parent issue ID (or null if "No Parent" was selected)

## Step 2: Create Issue with Research

Use the **linear-issue-creator** agent to create this issue. Pass:
- Issue description from $ARGUMENTS
- Selected parent issue ID (or null if standalone)
- If parent was selected, also pass the parent's project ID for project association

The agent will:

1. **Investigate the codebase** to understand context:
   - If parent feature exists, load parent issue description for architectural context
   - Search for relevant existing code patterns
   - Identify files that will likely be modified
   - Find similar implementations to reference
   - **Keep investigation focused** - this is for one issue, not a full feature

2. **Create a single issue** with:
   - Clear title summarizing the work
   - Description including:
     - What needs to be done (clear objective)
     - Why it's needed (context)
     - Acceptance criteria (how to verify it's done)
     - Relevant code locations from investigation
     - Links to related issues if applicable
   - Set status to "Todo"
   - Set parentId if feature parent was selected
   - Include project association if parent has one
   - Add appropriate labels

3. **Keep it focused**: This creates ONE issue, not multiple sub-issues

## Critical Rules

**FOCUSED INVESTIGATION**: Don't over-investigate. This is for a single issue, not a full feature plan.

**FOLLOW PARENT CONTEXT**: If a parent feature was selected, respect the patterns and approaches defined in that parent issue.

**CLEAR ACCEPTANCE CRITERIA**: The issue should be immediately actionable by any developer/AI.

**MVP MINDSET**: Focus on what needs to be done, not exhaustive possibilities.

Begin by listing Feature Root issues and prompting for selection.
