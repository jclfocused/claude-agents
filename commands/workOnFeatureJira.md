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
**DELEGATE TO SUB-AGENT**: To avoid bloating the main context, delegate all Story lookup and fetching to the **jira-story-context** agent.

- Pass the keywords from $ARGUMENTS directly to **jira-story-context** agent with "Feature: [keywords]" format
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
- **ALWAYS pull `develop` from remote FIRST** (ensure up to date)
- Create a branch for the work based on `develop`

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

Invoke the **execute-issue-jira** agent with:
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

### 5. Final Code Review with Codex

After ALL Subtasks are complete, run an automated code review using OpenAI Codex:

```bash
codex exec --model gpt-5.1-codex-max -c model_reasoning_effort=xhigh --yolo "Review all the changes on this branch compared to develop (git diff develop...HEAD). Provide a comprehensive code review noting any bugs, issues, or improvements. If you find issues that should be fixed, make the edits directly. Output a summary of your review and any changes made."
```

**Process:**
1. Run the codex command after all Subtasks are complete
2. Wait for Codex to complete its review
3. If Codex makes any edits, review them briefly to ensure they align with the feature scope
4. If Codex's changes are out of scope, revert them with `git checkout -- <file>`
5. Commit any valid fixes Codex made with a message like "fix: address code review feedback"

**Important:**
- This step is MANDATORY before considering the feature complete
- Run this ONCE at the end, not after each Subtask
- The review covers all changes across the entire feature branch

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
