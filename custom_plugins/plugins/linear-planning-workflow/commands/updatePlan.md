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

## Step 3: Determine Change Scope

Classify the changes as:

**Minor Changes** (skip Step 4 - no codebase investigation needed):
- Scope clarifications
- Acceptance criteria refinements
- Sub-issue description updates
- Small additions/removals

**Major Changes** (proceed to Step 4 - codebase investigation required):
- New functionality being added
- Different technical approach
- Significant refactoring requirements
- New integrations or dependencies

## Step 4: Codebase Investigation (Only If Major Changes - Using Parallel Code Explorer Agents)

If changes are major, investigate the codebase using parallel code-explorer agents:

1. **Dynamically Identify Investigation Areas**: Based on the change description, determine which 2-3 specific areas need investigation:
   - What parts of the codebase are affected by the changes?
   - What new functionality patterns do we need to understand?
   - What similar features already implement what's being added?
   - What integration points will be modified?
   - What dependencies will be impacted?
   - Example areas (adapt based on changes): "Areas implementing similar functionality", "Integration points that need updating", "New patterns required"

2. **Spin Up Parallel Code Explorer Agents**: Use the Task tool with `subagent_type='feature-dev:code-explorer'` to launch multiple agents in parallel:
   - **CRITICAL**: Use the full agent name `feature-dev:code-explorer` (plugin prefix required)
   - **IMPORTANT**: Call multiple Task tools in a single message to run agents in parallel
   - Launch 2-3 agents simultaneously, each investigating a different aspect you identified
   - Each agent receives a focused prompt describing what to investigate related to the changes
   - Agent prompts should be specific and clear about the investigation goal
   - Example: One agent investigates "Code areas affected by the new functionality", another investigates "Similar features to understand implementation patterns"

3. **Consolidate Investigation Findings**: After all parallel agents complete, review and consolidate their findings into a structured summary that will be passed to the linear-mvp-issue-updater agent.

## Step 5: Update Feature Plan

Use the **linear-planning-workflow:linear-mvp-issue-updater** agent (NOT linear-mvp-project-creator) to update this feature.

Pass to the agent:
- Parent issue ID
- Current parent issue details (title, description, labels, project association)
- All existing sub-issues with their current state
- Changes description from $ARGUMENTS
- Codebase investigation findings from Step 4 (if major changes, otherwise null/empty)

The agent will:

1. **Iterative Clarification Loop** - The agent will ask you clarifying questions about the changes:
   - Agent will ask about ambiguities or approach choices based on the investigation findings
   - Agent will continue asking questions until satisfied with understanding the changes
   - **Be prepared to answer multiple rounds of questions** - this ensures updates are accurate and complete

2. **Update the parent issue description**:
   - Preserve the IMPORTANT section (Linear discipline rules)
   - Update Problem, Solution, Implementation sections as needed
   - Update Codebase Investigation Findings if investigation was done (from Step 4)
   - Keep "Feature Root" label and project association

3. **Analyze sub-issue changes needed**:
   - **Keep unchanged**: Sub-issues that are still relevant and accurate
   - **Update**: Sub-issues that need description/acceptance criteria changes
   - **Delete**: Sub-issues that are no longer needed (mark as Canceled, don't actually delete)
   - **Add new**: New sub-issues required for the updated scope

4. **Execute changes**:
   - Use `mcp__linear-server__update_issue` to update parent and existing sub-issues
   - Use `mcp__linear-server__create_issue` to add new sub-issues
   - Mark obsolete sub-issues as "Canceled" (use update_issue with state="Canceled")
   - **IMPORTANT**: Never delete completed (Done) sub-issues - they represent finished work

5. **Preserve work in progress**:
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
