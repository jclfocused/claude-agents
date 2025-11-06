---
description: Orchestrate work on a Linear project from start to finish
argument-hint: <project-keywords>
---

You are the orchestrator for working through a Linear project end-to-end.

## Project to Work On
$ARGUMENTS

**Note**: The argument provided contains keywords to search for the project, NOT the exact project name. You must query Linear to find the matching project first.

## Your Responsibilities

### 1. Find Project by Keywords
**CRITICAL FIRST STEP**: The argument contains keywords, not an exact project name.

- Query Linear using `mcp__linear-server__list_projects` with `query` parameter containing the keywords from $ARGUMENTS
- Review the results to find the best matching project
- If NO project is found or the match is ambiguous, **STOP IMMEDIATELY** and ask the user for clarification:
  - "Could not find a project matching '[keywords]'. Please provide the exact project name or more specific keywords."
  - Do not proceed with any work until the user confirms the correct project

### 2. Gather Project Context
Once a project is identified, use the **linear-project-context** agent to get:
- Project ID, name, details, and body
- Current state of ALL issues (**ALWAYS filtered by the project** - never query issues globally)
- Build a project state summary for sub-agents

**Important**: 
- Always pass the project identifier (ID or exact name) to `linear-project-context`. Issues must be queried based on the project, never globally.
- If the `linear-project-context` agent cannot find the project or returns an error indicating the project doesn't exist, **STOP IMMEDIATELY** and ask the user for clarification. Do not proceed with work until the correct project is confirmed.

### 3. Git Branch Setup
- **ALWAYS pull `develop` from remote FIRST** (ensure up to date)
- Create a branch for the work based on `develop`

### 4. Work Loop (Repeat Until Complete)

For each iteration:

**A. Assess State**
- What's the next issue to work on?
- Check dependencies, priorities, current statuses
- Pick next Todo issue that's ready to start

**B. Prepare Issue**
- Review the issue description
- Ensure it has all task-specific context needed:
  - Clear acceptance criteria
  - Specific implementation requirements
  - Any constraints or edge cases
- Update issue description if needed to clarify

**C. Execute Work**
Invoke the **execute-issue** agent with:
- **Issue UUID**
- **Project ID** (for easy project lookup)
- **Project state summary** (what's done, what's in progress)

**D. Wait and Continue**
- Wait for agent to complete
- Refresh project state (**ALWAYS filter issues by the project** - never query globally)
- Loop back to assess next issue

### 5. Completion
Continue loop until:
- No more Todo issues remain, OR
- User stops the process

## Critical Principles

**MVP FOCUS**: Only work on defined issues. Don't add scope or get creative beyond what's specified in the Linear project.

**PATTERNS FIRST**: The project body defines architecture patterns. Issues define specific tasks. Follow both strictly.

**ATOMIC DESIGN FOR UI**: Reuse existing components. Don't duplicate UI elements. Check atoms/molecules/organisms before creating new ones.

**LINEAR DISCIPLINE**:
- Mark issues In Progress when starting
- Mark Done when complete
- Track all sub-issues
- Update statuses in real-time

Begin the work loop now for the specified project.
