---
description: Update an existing Linear parent feature issue and its sub-issues
argument-hint: <changes to make>
---

You are about to update an existing Linear feature plan (parent issue with nested sub-issues).

## Changes Description
$ARGUMENTS

## Step 1: Find Feature Root Issues

First, list all existing feature root issues:

1. Use `mcp__linear-server__list_issues` with `label: "Feature Root"` to fetch all root feature issues (filter directly by label name - don't check for label existence first)
2. **Filter to active features**: Exclude issues with status "Done" or "Canceled"
3. Use `AskUserQuestion` to prompt the user to select which feature to update:
   - **question**: "Which feature plan should be updated?"
   - **header**: "Feature Selection"
   - **multiSelect**: false
   - **options**: Build array with one option for each feature issue:
     - `label`: "[Issue ID] - [Feature Title] - [Status]"
     - `description`: First 100 chars of issue description or "No description"
4. Store the selected parent issue ID

## Step 2: Load Current Feature State

1. Use `mcp__linear-server__get_issue` to fetch the full parent issue details
2. Use `mcp__linear-server__list_issues` with `parentId` set to the parent issue ID to fetch all sub-issues (and their sub-issues recursively)
3. Analyze the current structure:
   - What sub-issues exist?
   - What is their status (Todo, In Progress, Done)?
   - How are they nested?

## Step 3: Update Feature Plan

Use the **linear-mvp-issue-updater** agent (NOT linear-mvp-project-creator) to update this feature.

Pass to the agent:
- Parent issue ID
- Current parent issue details (title, description, labels, project association)
- All existing sub-issues with their current state
- Changes description from $ARGUMENTS

The agent will:

1. **Re-investigate the codebase** if needed based on the changes
   - If changes are minor (scope adjustments), minimal investigation
   - If changes are significant (new functionality), full investigation like planFeature

2. **Iterative Clarification Loop** - The agent will ask you clarifying questions about the changes:
   - After initial analysis and investigation, agent will ask about ambiguities or approach choices
   - Based on your answers, agent may do additional research
   - Agent will continue asking questions and researching until satisfied with understanding the changes
   - **Be prepared to answer multiple rounds of questions** - this ensures updates are accurate and complete

3. **Update the parent issue description**:
   - Preserve the IMPORTANT section (Linear discipline rules)
   - Update Problem, Solution, Implementation sections as needed
   - Update Codebase Investigation Findings if re-investigation was done
   - Keep "Feature Root" label and project association

4. **Analyze sub-issue changes needed**:
   - **Keep unchanged**: Sub-issues that are still relevant and accurate
   - **Update**: Sub-issues that need description/acceptance criteria changes
   - **Delete**: Sub-issues that are no longer needed (mark as Canceled, don't actually delete)
   - **Add new**: New sub-issues required for the updated scope

5. **Execute changes**:
   - Use `mcp__linear-server__update_issue` to update parent and existing sub-issues
   - Use `mcp__linear-server__create_issue` to add new sub-issues
   - Mark obsolete sub-issues as "Canceled" (use update_issue with state="Canceled")
   - **IMPORTANT**: Never delete completed (Done) sub-issues - they represent finished work

6. **Preserve work in progress**:
   - **NEVER cancel sub-issues that are "In Progress"** - ask user first if they should be updated or left as-is
   - **NEVER cancel sub-issues that are "Done"** - completed work stays completed
   - Only cancel "Todo" sub-issues that are no longer relevant

## Critical Rules

**PRESERVE COMPLETED WORK**: Never modify or cancel sub-issues with status "Done" - they represent finished work.

**PROTECT IN-PROGRESS WORK**: Never cancel sub-issues with status "In Progress" without explicit user confirmation.

**MAINTAIN FEATURE ROOT LABEL**: Always keep the "Feature Root" label on the parent issue.

**KEEP PROJECT ASSOCIATION**: Preserve the project association if one exists.

**MVP SCOPE**: Keep updates focused on what's necessary - don't over-engineer the changes.

Begin by listing all Feature Root issues and prompting for selection.
