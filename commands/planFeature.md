---
description: Create a Linear MVP project with issues for a new feature
argument-hint: <feature description>
---

You are about to create a comprehensive Linear MVP project for a new feature.

## Feature Description
$ARGUMENTS

## Instructions

Use the **linear-mvp-project-creator** agent to create this project. The agent will:

1. **Investigate the codebase** thoroughly to understand:
   - Existing patterns and architecture
   - Similar features that already exist
   - Bad patterns that need refactoring
   - Atomic design components (for UI features)

2. **Create a Linear project** with a body structured as:
   - **IMPORTANT section** with Linear issue discipline rules
   - **Problem** statement
   - **Solution** approach
   - **High-level implementation** details
   - **Codebase investigation findings**
   - **Atomic design components** (if UI feature)

3. **Create issues** following these principles:
   - Top-level issues = Vertical slices (potential PRs)
   - Include sub-issues for logical breakdown
   - Add refactor issues for bad patterns found
   - Add atomic design component creation issues if needed
   - Include basic testing tasks
   - Each issue must be self-contained (any AI can pick it up)

## Critical Rules to Remember

**MVP SCOPE**: Focus on what makes the feature functional, NOT comprehensive solutions. Ship something that works, iterate later.

**REFACTOR AS YOU TOUCH**: If bad patterns are found, create refactor issues to fix them as we work in that area.

**ATOMIC DESIGN FOR UI**: Use existing components or create new ones following atomic design principles (atoms/molecules/organisms).

**LINEAR DISCIPLINE** (will be in project body):
- DO NOT WRITE CODE WITHOUT A LINEAR ISSUE IN PROGRESS
- MARK WORK AS DONE IN LINEAR WHEN COMPLETE
- IF DOING MULTIPLE FEATURES, MARK ALL ISSUES AS IN PROGRESS
- THIS INCLUDES SUB ISSUES
- AN ISSUE ISN'T DONE UNTIL ALL SUB ISSUES ARE DONE
- IF SCOPE IS MISSING, CREATE THE ISSUE FIRST

Launch the agent now with this feature description.
