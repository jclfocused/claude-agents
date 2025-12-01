---
description: Create a Jira Story with flat Subtasks for a new feature
argument-hint: <feature description>
---

You are about to create a comprehensive Jira feature with a parent Story and flat Subtasks.

## Feature Description
$ARGUMENTS

## Step 1: Get Current User

First, identify the current user for assignment:

1. Use `mcp__mcp-atlassian__jira_search` with JQL `assignee = currentUser()` and `limit: 1`
2. Extract the assignee's `display_name` and `email` from the result
3. Store for later assignment (this will be the default assignee)

## Step 2: Sprint and Team Selection

Get available sprints and let user choose:

1. Use `mcp__mcp-atlassian__jira_get_agile_boards` to get boards
2. For each board (typically just one), use `mcp__mcp-atlassian__jira_get_sprints_from_board` with `state: "active"` to get active sprints
3. Also get future sprints with `state: "future"` if needed
4. Use `AskUserQuestion` to prompt the user:
   - **question**: "Which sprint should this feature be added to?"
   - **header**: "Sprint"
   - **multiSelect**: false
   - **options**: Build array with:
     - One option for each sprint: `{ label: "[Sprint Name]", description: "[State]: [Start Date] - [End Date]" }`
     - Last option: `{ label: "No sprint (Backlog)", description: "Create issues without sprint assignment" }`

5. **If user selects a sprint**:
   - Parse team name from sprint name (format: "[Team Name] - Sprint [Number]")
   - Store sprint_id and team_name
   - Example: "DM Team - Sprint 92" → team_name = "DM Team", sprint_id = 1800

6. **If user selects "No sprint"**:
   - Use `AskUserQuestion` to ask about team:
     - **question**: "Which team should own this feature?"
     - **header**: "Team"
     - **multiSelect**: false
     - **options**: Build from known teams (parsed from sprint names) plus:
       - `{ label: "No team assignment", description: "Create issues without team ownership" }`
   - Store team_name (or null if "No team")

## Step 3: Codebase Investigation (Using Parallel Code Explorer Agents)

Before creating the feature issues, investigate the codebase using parallel code-explorer agents:

1. **Dynamically Identify Investigation Areas**: Based on the feature description, determine which 2-4 specific areas of the codebase need investigation:
   - What parts of the codebase will be touched?
   - What similar features exist that we can learn from?
   - What patterns and conventions should we follow?
   - What integration points need to be understood?

2. **Spin Up Parallel Code Explorer Agents**: Use the Task tool with `subagent_type='feature-dev:code-explorer'` to launch multiple agents in parallel:
   - **CRITICAL**: Use the full agent name `feature-dev:code-explorer` (plugin prefix required)
   - **IMPORTANT**: Call multiple Task tools in a single message to run agents in parallel
   - Launch 2-4 agents simultaneously, each investigating a different area
   - Each agent receives a focused prompt describing what to investigate

3. **Consolidate Investigation Findings**: After all parallel agents complete, review and consolidate their findings into a structured summary.

## Step 4: Create Feature Issues

Use the **jira-planning-workflow:jira-mvp-story-creator** agent to create this feature. Pass:
- The project key (typically "ROUT")
- The sprint_id (or null)
- The team_name (or null)
- The assignee email
- The consolidated codebase investigation findings from Step 3

The agent will:

1. **Iterative Clarification Loop** - Ask clarifying questions to ensure full understanding
2. **Create a parent Story** with structured description
3. **Create flat Subtasks** - ALL subtasks directly under the Story (no nesting in Jira)

## Critical Rules to Remember

**MVP SCOPE**: Focus on what makes the feature functional, NOT comprehensive solutions.

**FLAT SUBTASKS**: Jira subtasks cannot have nested subtasks. Use naming conventions to show logical grouping:
- "SLICE 1: Main task"
- "SLICE 1.1: Sub-part of slice 1"
- "SLICE 1.2: Another sub-part"
- "REFACTOR: Code cleanup task"
- "TEST: Testing task"

**TEAM + SPRINT**: Both `customfield_10001` (Team) and `customfield_10020` (Sprint) should be set on all issues when provided.

**JIRA DISCIPLINE** (will be in Story description):
- DO NOT WRITE CODE WITHOUT A JIRA ISSUE IN PROGRESS
- MARK WORK AS DONE IN JIRA WHEN COMPLETE
- AN ISSUE ISN'T DONE UNTIL ALL SUBTASKS ARE DONE
- IF SCOPE IS MISSING, CREATE THE SUBTASK FIRST

Begin by getting the current user and prompting for sprint selection.
