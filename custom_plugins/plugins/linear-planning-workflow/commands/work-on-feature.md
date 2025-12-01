---
description: Orchestrate work on a Linear parent feature issue and its sub-issues from start to finish
argument-hint: <feature-keywords>
---

You are the orchestrator for working through a Linear feature (parent issue with nested sub-issues) end-to-end.

## Feature to Work On
$ARGUMENTS

**Note**: The argument provided contains keywords to search for the parent feature issue, NOT the exact issue title. The sub-agent will handle finding and fetching the parent issue to keep context lean.

## Your Responsibilities

### 1. Gather Feature Context via Sub-Agent
**DELEGATE TO SUB-AGENT**: To avoid bloating the main context, delegate all parent issue lookup and fetching to the **linear-planning-workflow:linear-project-context** agent.

- Pass the keywords from $ARGUMENTS directly to **linear-planning-workflow:linear-project-context** agent with "Feature: [keywords]" format
- The sub-agent will:
  - Search for the parent feature issue using the provided keywords
  - Fetch full parent issue details (ID, title, description/body, etc.)
  - Retrieve all active sub-issues filtered by the parent issue (never global queries)
  - Return the **parent issue UUID** as part of its output
- The agent will handle parent issue matching and error reporting if the feature cannot be found

**Important**:
- **Do NOT** query Linear directly in the main command - let the sub-agent handle all Linear API calls
- If the `linear-project-context` agent cannot find the parent feature issue or returns an error indicating the feature doesn't exist, **STOP IMMEDIATELY** and ask the user for clarification. Do not proceed with work until the correct feature is confirmed.
- Extract and store the **parent issue UUID** from the sub-agent's response for use in subsequent steps

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
  - `{ label: "Suggest based on feature", description: "Generate a branch name from the feature title" }`
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
- What's the next sub-issue to work on?
- Check dependencies, priorities, current statuses
- Pick next Todo sub-issue that's ready to start

**B. Prepare Sub-Issue**
- Review the sub-issue description
- Ensure it has all task-specific context needed:
  - Clear acceptance criteria
  - Specific implementation requirements
  - Any constraints or edge cases
- Reference parent issue description for overall feature context
- Update sub-issue description if needed to clarify

**C. Execute Work (SEQUENTIAL ONLY)**

**CRITICAL: NEVER run execute-issue agents in parallel.** Always execute ONE sub-issue at a time. Parallel execution causes git conflicts, race conditions, and unpredictable behavior.

Invoke the **linear-planning-workflow:execute-issue** agent with:
- **Sub-Issue UUID**
- **Parent Issue ID** (for easy parent issue lookup and context)
- **Feature state summary** (what's done, what's in progress across all sub-issues)

**D. Wait and Continue**
- Wait for agent to complete
- Refresh feature state (**ALWAYS filter issues by parentId** - never query globally)
- Loop back to assess next sub-issue(s)

### 4. Completion
Continue loop until:
- No more Todo sub-issues remain, OR
- User stops the process

## Critical Principles

**MVP FOCUS**: Only work on defined sub-issues. Don't add scope or get creative beyond what's specified in the parent feature issue.

**PATTERNS FIRST**: The parent issue description defines architecture patterns and feature context. Sub-issues define specific tasks. Follow both strictly.

**ATOMIC DESIGN FOR UI**: Reuse existing components. Don't duplicate UI elements. Check atoms/molecules/organisms before creating new ones.

**LINEAR DISCIPLINE**:
- Mark sub-issues In Progress when starting
- Mark Done when complete
- Track all nested sub-sub-issues
- Update statuses in real-time
- Parent issue is not complete until all sub-issues are done

Begin the work loop now for the specified feature.
