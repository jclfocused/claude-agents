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

**IMPORTANT: Transition Parent Story to In Progress**

After successfully retrieving the parent Story, **immediately transition it to "In Progress"**:

1. First, get available transitions: `mcp__mcp-atlassian__jira_get_transitions({ issue_key: "{story_key}" })`
2. Find the transition ID for "In Progress" (or similar status like "Start Progress")
3. Execute the transition: `mcp__mcp-atlassian__jira_transition_issue({ issue_key: "{story_key}", transition_id: "{transition_id}" })`

This signals that work on the feature has begun. Do NOT skip this step.

### 2. Determine Version Control Workflow

**Step 1: Check if git is initialized**

Run `git status` to check if the current directory is a git repository.

**If NOT a git repository:**
1. Run `git init`
2. Set default branch to main: `git branch -M main`
3. Inform user: "Initialized git repository with main branch"
4. Proceed with normal git workflow (Graphite requires existing repo)

**Step 2: Check Graphite availability (only if git is already initialized)**

Check if `mcp__graphite__run_gt_cmd` tool exists in your available tools.

**IF Graphite tool exists**, ask the user:

Use `AskUserQuestion`:
- **Question**: "Graphite is available. Would you like to use stacked PRs for this feature?"
- **header**: "Graphite Stacking"
- **multiSelect**: false
- **options**:
  - `{ label: "Yes, use Graphite", description: "Each Subtask becomes a stacked PR for parallel reviews" }`
  - `{ label: "No, use normal git", description: "All work committed to a single feature branch" }`

**IF Graphite tool does NOT exist**, silently proceed with normal git workflow. Do NOT mention Graphite to the user.

**Store the workflow choice** - this determines which agent to use later.

### 3. Git Branch Setup

**IF using Graphite:**

Graphite recommends NOT creating empty branches. In Graphite's model:
- Each branch is an atomic changeset with actual code changes
- The stack of Subtask branches IS the feature
- All branches stack on the trunk (develop/main) and merge into it in order

Use `AskUserQuestion` to determine the trunk branch:

**Question**: "What branch should Subtasks stack on top of?"
- **header**: "Trunk Branch"
- **multiSelect**: false
- **options**:
  - `{ label: "develop", description: "Stack on develop (recommended)" }`
  - `{ label: "main", description: "Stack on main" }`
  - `{ label: "Current branch", description: "Stack on your current branch" }`

**Execute Graphite setup:**
```bash
# Sync Graphite first
gt sync

# Checkout the trunk branch - this is where all Subtasks will eventually merge
gt checkout {trunk_branch}
```

**No separate feature branch is created.** The first Subtask will create its branch directly on the trunk, and subsequent Subtasks stack on top of each other. The stack structure will be:

```
{trunk} <- subtask-1 <- subtask-2 <- subtask-3
```

When PRs merge, they merge into trunk in order (bottom to top). Graphite handles updating base branches automatically.

**IF NOT using Graphite (normal flow):**

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

**Execute non-Graphite branch setup:**
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
# Submit the current stack state (makes PR visible for review, NOT as draft)
gt submit --no-interactive --publish

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
- If using Graphite: run `gt submit --no-interactive --publish` and `gt sync`
- Refresh feature state (query Subtasks again via jira-story-context or direct JQL)
- Loop back to assess next Subtask

### 5. Completion

Continue loop until:
- No more To Do/Open Subtasks remain, OR
- User stops the process

**IMPORTANT: Transition Parent Story to Done**

When all Subtasks are complete, **transition the parent Story to "Done"**:

1. Get available transitions: `mcp__mcp-atlassian__jira_get_transitions({ issue_key: "{story_key}" })`
2. Find the transition ID for "Done" (or similar status like "Resolve", "Complete")
3. Execute the transition: `mcp__mcp-atlassian__jira_transition_issue({ issue_key: "{story_key}", transition_id: "{transition_id}" })`

Do NOT forget this step - the parent Story must be marked Done when the feature is complete.

**IF using Graphite:**

After all Subtasks are complete:
```bash
# Final submission to ensure all PRs are up
gt submit --stack --no-interactive --publish
```

Report to user:
```
## Feature Work Complete (Graphite Stack)

All Subtasks have been implemented as stacked PRs.

**Parent Story:** {story_key} marked as Done
**Stack PRs:** [List the branch names / PR URLs if available]

**Status:** All Subtasks are marked "In Review"

**Next Steps:**
1. Review the stacked PRs in order
2. Approve and merge from bottom to top

Use `gt log` to see the full stack structure.
```

**IF NOT using Graphite:**

After marking parent Story Done, report completion with summary of work done.

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
