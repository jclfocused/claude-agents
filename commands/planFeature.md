---
description: Create a Linear MVP parent issue with nested sub-issues for a new feature
argument-hint: <feature description>
---

You are about to create a comprehensive Linear feature with a parent issue and nested sub-issues.

## Feature Description
$ARGUMENTS

## Step 1: Project Selection

First, list all existing Linear projects with their current status:

1. Use `mcp__linear-server__list_projects` with `limit: 250` to fetch all projects
2. **Filter out completed projects**: Exclude any projects where `status.name` is "Completed" or "Canceled"
3. Use `AskUserQuestion` to prompt the user with all active/planned projects:
   - **question**: "Which project should this feature be associated with?"
   - **header**: "Project Association"
   - **multiSelect**: false
   - **options**: Build array with:
     - First option: `{ label: "No Project Association", description: "Create issues without linking to any project" }`
     - Remaining options: One for each project with:
       - `label`: "[Project Name] - [Status Name]"
       - `description`: Project summary if available (truncate to 100 chars), or "No description"
4. Store the selected project ID based on user's choice:
   - If user selects first option: store null
   - Otherwise: store the corresponding project ID from the selected option

## Step 2: Codebase Investigation (Using Parallel Code Explorer Agents)

Before creating the feature issues, investigate the codebase using parallel code-explorer agents:

1. **Dynamically Identify Investigation Areas**: Based on the feature description, determine which 2-4 specific areas of the codebase need investigation:
   - What parts of the codebase will be touched?
   - What similar features exist that we can learn from?
   - What patterns and conventions should we follow?
   - What integration points need to be understood?
   - Example areas (adapt based on feature): "Current frontend component structure", "API endpoint patterns", "Database schema for similar features", "Authentication flow", "Testing patterns"

2. **Spin Up Parallel Code Explorer Agents**: Use the Task tool with `subagent_type='feature-dev:code-explorer'` to launch multiple agents in parallel:
   - **CRITICAL**: Use the full agent name `feature-dev:code-explorer` (plugin prefix required)
   - **IMPORTANT**: Call multiple Task tools in a single message to run agents in parallel
   - Launch 2-4 agents simultaneously, each investigating a different area you identified
   - Each agent receives a focused prompt describing what to investigate
   - Agent prompts should be specific and clear about the investigation goal
   - Example: One agent investigates "Current frontend component structure and reusable UI patterns", another investigates "Existing API endpoint architecture and routing patterns"

3. **Consolidate Investigation Findings**: After all parallel agents complete, review and consolidate their findings into a structured summary that will be passed to the linear-mvp-project-creator agent.

## Step 3: Create Feature Issues

Use the **linear-mvp-project-creator** agent to create this feature. Pass:
- The selected project ID (or null) to the agent
- The consolidated codebase investigation findings from Step 2

**IMPORTANT**: The agent will ensure the parent issue is labeled with "Feature Root" for easy identification and filtering of all root feature issues.

The agent will:

1. **Iterative Clarification Loop** - The agent will ask you clarifying questions to ensure full understanding:
   - Agent will ask questions about ambiguities, approach choices, or missing requirements based on the investigation findings
   - Agent will continue asking questions until satisfied with understanding
   - **Be prepared to answer multiple rounds of questions** - this ensures a well-planned feature

2. **Create a parent issue** with description structured as:
   - **IMPORTANT section** with Linear issue discipline rules
   - **Problem** statement
   - **Solution** approach
   - **High-level implementation** details
   - **Codebase investigation findings** (from Step 2)
   - **Atomic design components** (if UI feature)

3. **Create nested issues** following these principles:
   - All issues as direct sub-issues of the parent or nested further
   - Top-level sub-issues = Vertical slices (potential PRs)
   - Include deeper nesting for logical breakdown
   - Add refactor issues for bad patterns found
   - Add atomic design component creation issues if needed
   - Include basic testing tasks
   - Each issue must be self-contained (any AI can pick it up)

## Critical Rules to Remember

**MVP SCOPE**: Focus on what makes the feature functional, NOT comprehensive solutions. Ship something that works, iterate later.

**REFACTOR AS YOU TOUCH**: If bad patterns are found, create refactor issues to fix them as we work in that area.

**ATOMIC DESIGN FOR UI**: Use existing components or create new ones following atomic design principles (atoms/molecules/organisms).

**LINEAR DISCIPLINE** (will be in parent issue description):
- DO NOT WRITE CODE WITHOUT A LINEAR ISSUE IN PROGRESS
- MARK WORK AS DONE IN LINEAR WHEN COMPLETE
- IF DOING MULTIPLE FEATURES, MARK ALL ISSUES AS IN PROGRESS
- THIS INCLUDES SUB ISSUES
- AN ISSUE ISN'T DONE UNTIL ALL SUB ISSUES ARE DONE
- IF SCOPE IS MISSING, CREATE THE ISSUE FIRST

Begin by listing projects and prompting for selection.
