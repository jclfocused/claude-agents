---
description: Orchestrate work on a Jira Story and its Subtasks from start to finish
argument-hint: <feature-keywords>
---

You are the orchestrator for working through a Jira feature (Story with Subtasks) end-to-end.

## Feature to Work On
$ARGUMENTS

**Note**: The argument provided contains keywords to search for the parent Story, NOT the exact issue title. The sub-agent will handle finding and fetching the Story to keep context lean.

## Your Responsibilities

### 1. Gather Feature Context via Sub-Agent
**DELEGATE TO SUB-AGENT**: To avoid bloating the main context, delegate all Story lookup and fetching to the **jira-planning-workflow:jira-story-context** agent.

- Pass the keywords from $ARGUMENTS directly to **jira-planning-workflow:jira-story-context** agent with "Feature: [keywords]" format
- The sub-agent will:
  - Search for the parent Story using the provided keywords
  - Fetch full Story details (key, title, description, team, sprint, etc.)
  - Retrieve all active Subtasks filtered by the parent Story
  - Return the **Story key** (e.g., ROUT-17432) as part of its output
- The agent will handle Story matching and error reporting if the feature cannot be found

**Important**:
- **Do NOT** query Jira directly in the main command - let the sub-agent handle all Jira API calls
- If the `jira-story-context` agent cannot find the parent Story or returns an error, **STOP IMMEDIATELY** and ask the user for clarification
- Extract and store the **Story key** from the sub-agent's response for use in subsequent steps

### 2. Git Branch Setup

Use `AskUserQuestion` to determine branch setup:

**Question 1**: "Should we create a new branch for this feature work?"
- **header**: "Branch Setup"
- **multiSelect**: false
- **options**:
  - `{ label: "Yes, create a new branch", description: "Create and switch to a new feature branch" }`
  - `{ label: "No, use current branch", description: "Continue working on the current branch" }`

**If user selects "Yes, create a new branch"**, ask two more questions:

**Question 2**: "What branch should we base off of?"
- **header**: "Base Branch"
- **multiSelect**: false
- **options**:
  - `{ label: "main", description: "Base off the main branch" }`
  - `{ label: "develop", description: "Base off the develop branch" }`
  - `{ label: "Current branch", description: "Base off your current branch" }`

**Question 3**: "What should the new branch be called?"
- **header**: "Branch Name"
- **multiSelect**: false
- **options**:
  - `{ label: "Suggest based on feature", description: "Generate a branch name from the Story title" }`
  - `{ label: "Let me specify", description: "I'll provide my own branch name" }`

If user wants to specify their own name, use a follow-up `AskUserQuestion` with free text input.

**Execute branch setup**:
1. If creating a new branch:
   - Fetch latest from remote
   - Pull the selected base branch
   - Create the new branch with the chosen name
   - Switch to the new branch
2. If using current branch:
   - Verify current branch status with `git status`
   - Warn if there are uncommitted changes

### 3. Work Loop (Repeat Until Complete)

For each iteration:

**A. Assess State**
- What's the next Subtask to work on?
- Check dependencies, priorities, current statuses
- Pick next To Do/Open Subtask that's ready to start

**B. Prepare Subtask**
- Review the Subtask description
- Ensure it has all task-specific context needed:
  - Clear acceptance criteria
  - Specific implementation requirements
  - Any constraints or edge cases
- Reference parent Story description for overall feature context
- Update Subtask description if needed to clarify

**C. Execute Work (SEQUENTIAL ONLY)**

**CRITICAL: NEVER run execute-issue-jira agents in parallel.** Always execute ONE Subtask at a time. Parallel execution causes git conflicts, race conditions, and unpredictable behavior.

Invoke the **jira-planning-workflow:execute-issue-jira** agent with:
- **Subtask Key** (e.g., ROUT-17533)
- **Parent Story Key** (e.g., ROUT-17432)
- **Feature state summary** (what's done, what's in progress across all Subtasks)

**D. Wait and Continue**
- Wait for agent to complete
- Refresh feature state (query Subtasks again via jira-story-context or direct JQL)
- Loop back to assess next Subtask

### 4. Completion
Continue loop until:
- No more To Do/Open Subtasks remain, OR
- User stops the process

## Critical Principles

**MVP FOCUS**: Only work on defined Subtasks. Don't add scope or get creative beyond what's specified in the parent Story.

**PATTERNS FIRST**: The parent Story description defines architecture patterns and feature context. Subtasks define specific tasks. Follow both strictly.

**ATOMIC DESIGN FOR UI**: Reuse existing components. Don't duplicate UI elements. Check atoms/molecules/organisms before creating new ones.

**JIRA DISCIPLINE**:
- Transition Subtasks to "In Progress" when starting
- Transition to "Done" when complete
- Track all Subtasks
- Update statuses in real-time
- Story is not complete until all Subtasks are Done

Begin the work loop now for the specified feature.
