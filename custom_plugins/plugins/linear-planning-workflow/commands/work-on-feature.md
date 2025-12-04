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
- Also extract the **issue identifier** (e.g., "LIN-123") for branch naming

### 2. Check Graphite Availability

**Detect if Graphite MCP is available** by checking if `mcp__graphite__run_gt_cmd` tool exists.

If Graphite is available, use `AskUserQuestion`:

**Question**: "Graphite is available. Would you like to use stacked PRs for this feature?"
- **header**: "Graphite Stacking"
- **multiSelect**: false
- **options**:
  - `{ label: "Yes, use Graphite", description: "Each sub-issue becomes a stacked PR for parallel reviews" }`
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
`{issue-identifier}-{type}-{sanitized-title}`

Example: `lin-123-feat-user-authentication`

Where:
- `{issue-identifier}` = lowercase issue ID (e.g., "lin-123")
- `{type}` = "feat", "bug", or "chore" based on issue type/labels
- `{sanitized-title}` = lowercase, hyphenated title

- **header**: "Branch Name"
- **multiSelect**: false
- **options**:
  - `{ label: "Use suggested: {generated-name}", description: "Auto-generated from issue" }`
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

**IF using Graphite:**

Invoke the **linear-planning-workflow:execute-issue-graphite** agent with:
- **Sub-Issue UUID**
- **Parent Issue ID** (for easy parent issue lookup and context)
- **Feature state summary** (what's done, what's in progress across all sub-issues)

**After agent completes, orchestrator runs:**
```bash
# Submit the current stack state (makes PR visible for review)
gt submit --no-interactive

# Sync to ensure everything is up to date
gt sync
```

This allows reviewers to start reviewing earlier PRs while work continues on later ones.

**IF NOT using Graphite (normal flow):**

Invoke the **linear-planning-workflow:execute-issue** agent with:
- **Sub-Issue UUID**
- **Parent Issue ID** (for easy parent issue lookup and context)
- **Feature state summary** (what's done, what's in progress across all sub-issues)

**D. Wait and Continue**
- Wait for agent to complete
- If using Graphite: run `gt submit --no-interactive` and `gt sync`
- Refresh feature state (**ALWAYS filter issues by parentId** - never query globally)
- Loop back to assess next sub-issue(s)

### 5. Completion

Continue loop until:
- No more Todo sub-issues remain, OR
- User stops the process

**IF using Graphite:**

After all sub-issues are complete:
```bash
# Final submission to ensure all PRs are up
gt submit --stack --no-interactive
```

Report to user:
```
## Feature Work Complete (Graphite Stack)

All sub-issues have been implemented as stacked PRs.

**Stack PRs:** [List the branch names / PR URLs if available]

**Status:** All sub-issues are marked "In Review"

**Next Steps:**
1. Review the stacked PRs in order
2. Approve and merge from bottom to top
3. Graphite will automatically mark Linear issues as "Done" when PRs merge

Use `gt log` to see the full stack structure.
```

**IF NOT using Graphite:**

Normal completion message with summary of work done.

## Critical Principles

**MVP FOCUS**: Only work on defined sub-issues. Don't add scope or get creative beyond what's specified in the parent feature issue.

**PATTERNS FIRST**: The parent issue description defines architecture patterns and feature context. Sub-issues define specific tasks. Follow both strictly.

**ATOMIC DESIGN FOR UI**: Reuse existing components. Don't duplicate UI elements. Check atoms/molecules/organisms before creating new ones.

**LINEAR DISCIPLINE**:
- Mark sub-issues In Progress when starting
- For Graphite flow: Mark "In Review" when complete (Graphite handles "Done" on merge)
- For normal flow: Mark Done when complete
- Track all nested sub-sub-issues
- Update statuses in real-time
- Parent issue is not complete until all sub-issues are done

**GRAPHITE DISCIPLINE** (when using Graphite):
- Each sub-issue = one stacked branch
- Branch naming: `{key}-{description}` (no type prefix for sub-issues)
- Submit after each issue so reviews can start early
- Don't mark "Done" - let Graphite handle it on PR merge

Begin the work loop now for the specified feature.
