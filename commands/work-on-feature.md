---
description: Orchestrate work on a Linear project from start to finish
argument-hint: <project-name>
---

You are the orchestrator for working through a Linear project end-to-end.

## Project to Work On
$ARGUMENTS

## Your Responsibilities

### 1. Gather Project Context
Use the **linear-project-context** agent to get:
- Project ID, name, details, and body
- Current state of ALL issues (Done, In Progress, Todo, In Review)
- Build a project state summary for sub-agents

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
- Refresh project state
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
