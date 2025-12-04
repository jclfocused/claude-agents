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

### 2. Check Graphite Availability

**Detect if Graphite MCP is available** by checking if `mcp__graphite__run_gt_cmd` tool exists.

If Graphite is available, use `AskUserQuestion`:

**Question**: "Graphite is available. Would you like to use stacked PRs for this feature?"
- **header**: "Graphite Stacking"
- **multiSelect**: false
- **options**:
  - `{ label: "Yes, use Graphite", description: "Each Subtask becomes a stacked PR for parallel reviews" }`
  - `{ label: "No, use normal git", description: "All work committed to a single feature branch" }`

**Store the user's choice** - this determines which agent and workflow to use.

### 3. Git Branch Setup

Use `AskUserQuestion` to determine branch setup:

**Question 1**: "Should we create a new branch for this feature work?"
- **header**: "Branch Setup"
- **multiSelect**: false
- **options**:
  - `{ label: "Yes, create a new branch", description: "Create and switch to a new feature branch" }`
  - `{ label: "No, use current branch", description: "Continue working on the current branch" }`

**If user selects "Yes, create a new branch"**, ask:

**Question 2**: "What branch should we base off of?"
- **header**: "Base Branch"
- **multiSelect**: false
- **options**:
  - `{ label: "main", description: "Base off the main branch" }`
  - `{ label: "develop", description: "Base off the develop branch" }`
  - `{ label: "Current branch", description: "Base off your current branch" }`

**Question 3**: "What should the new branch be called?"

Generate a default branch name using the convention:
`{issue-key}-{type}-{sanitized-title}`

Example: `rout-17432-feat-user-authentication`

Where:
- `{issue-key}` = lowercase issue key (e.g., "rout-17432")
- `{type}` = "feat", "bug", or "chore" based on issue type
- `{sanitized-title}` = lowercase, hyphenated title

- **header**: "Branch Name"
- **multiSelect**: false
- **options**:
  - `{ label: "Use suggested: {generated-name}", description: "Auto-generated from Story" }`
  - `{ label: "Let me specify", description: "I'll provide my own branch name" }`

If user wants to specify their own name, use a follow-up `AskUserQuestion` with free text input.

**Execute branch setup**:

**IF using Graphite:**
```bash
# Sync Graphite first
gt sync

# Checkout the base branch
gt checkout {base_branch}  # main, develop, or current

# Create the feature branch (regular git for the base)
git checkout -b {feature_branch_name}
```

**IF NOT using Graphite (normal flow):**
1. If creating a new branch:
   - Fetch latest from remote
   - Pull the selected base branch
   - Create the new branch with the chosen name
   - Switch to the new branch
2. If using current branch:
   - Verify current branch status with `git status`
   - Warn if there are uncommitted changes

### 4. Work Loop (Repeat Until Complete)

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

**IF using Graphite:**

Invoke the **jira-planning-workflow:execute-issue-jira-graphite** agent with:
- **Subtask Key** (e.g., ROUT-17533)
- **Parent Story Key** (e.g., ROUT-17432)
- **Feature state summary** (what's done, what's in progress across all Subtasks)

**After agent completes, orchestrator runs:**
```bash
# Submit the current stack state (makes PR visible for review)
gt submit --no-interactive

# Sync to ensure everything is up to date
gt sync
```

This allows reviewers to start reviewing earlier PRs while work continues on later ones.

**IF NOT using Graphite (normal flow):**

Invoke the **jira-planning-workflow:execute-issue-jira** agent with:
- **Subtask Key** (e.g., ROUT-17533)
- **Parent Story Key** (e.g., ROUT-17432)
- **Feature state summary** (what's done, what's in progress across all Subtasks)

**D. Wait and Continue**
- Wait for agent to complete
- If using Graphite: run `gt submit --no-interactive` and `gt sync`
- Refresh feature state (query Subtasks again via jira-story-context or direct JQL)
- Loop back to assess next Subtask

### 5. Completion

Continue loop until:
- No more To Do/Open Subtasks remain, OR
- User stops the process

**IF using Graphite:**

After all Subtasks are complete:
```bash
# Final submission to ensure all PRs are up
gt submit --stack --no-interactive
```

Report to user:
```
## Feature Work Complete (Graphite Stack)

All Subtasks have been implemented as stacked PRs.

**Stack PRs:** [List the branch names / PR URLs if available]

**Status:** All Subtasks are marked "In Review"

**Next Steps:**
1. Review the stacked PRs in order
2. Approve and merge from bottom to top
3. Graphite will automatically transition Jira issues when PRs merge

Use `gt log` to see the full stack structure.
```

**IF NOT using Graphite:**

Normal completion message with summary of work done.

## Critical Principles

**MVP FOCUS**: Only work on defined Subtasks. Don't add scope or get creative beyond what's specified in the parent Story.

**PATTERNS FIRST**: The parent Story description defines architecture patterns and feature context. Subtasks define specific tasks. Follow both strictly.

**ATOMIC DESIGN FOR UI**: Reuse existing components. Don't duplicate UI elements. Check atoms/molecules/organisms before creating new ones.

**JIRA DISCIPLINE**:
- Transition Subtasks to "In Progress" when starting
- For Graphite flow: Transition to "In Review" when complete (Graphite handles "Done" on merge)
- For normal flow: Transition to "Done" when complete
- Track all Subtasks
- Update statuses in real-time
- Story is not complete until all Subtasks are Done

**GRAPHITE DISCIPLINE** (when using Graphite):
- Each Subtask = one stacked branch
- Branch naming: `{key}-{description}` (no type prefix for Subtasks)
- Submit after each Subtask so reviews can start early
- Don't transition to "Done" - let Graphite handle it on PR merge

Begin the work loop now for the specified feature.
