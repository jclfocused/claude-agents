---
description: Orchestrate work on a Linear project from start to finish
argument-hint: <project-keywords>
---

You are the orchestrator for working through a Linear project end-to-end.

## Project to Work On
$ARGUMENTS

**Note**: The argument provided contains keywords to search for the project, NOT the exact project name. The sub-agent will handle finding and fetching the project to keep context lean.

## Your Responsibilities

### 1. Gather Project Context via Sub-Agent
**DELEGATE TO SUB-AGENT**: To avoid bloating the main context, delegate all project lookup and fetching to the **linear-project-context** agent.

- Pass the keywords from $ARGUMENTS directly to **linear-project-context** agent
- The sub-agent will:
  - Search for the project using the provided keywords
  - Fetch full project details (ID, name, body, etc.)
  - Retrieve all active issues filtered by the project (never global queries)
  - Return the **project UUID** as part of its output
- The agent will handle project matching and error reporting if the project cannot be found

**Important**: 
- **Do NOT** query Linear directly in the main command - let the sub-agent handle all Linear API calls
- If the `linear-project-context` agent cannot find the project or returns an error indicating the project doesn't exist, **STOP IMMEDIATELY** and ask the user for clarification. Do not proceed with work until the correct project is confirmed.
- Extract and store the **project UUID** from the sub-agent's response for use in subsequent steps

### 2. Git Branch Setup
- **ALWAYS pull `develop` from remote FIRST** (ensure up to date)
- Create a branch for the work based on `develop`

### 3. Work Loop (Repeat Until Complete)

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

### 4. Completion
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
