# Graphite CLI (gt) - Comprehensive Guide

Graphite simplifies the entire code authoring & reviewing lifecycle for GitHub. It enables **stacking PRs** on top of each other to keep you unblocked and your changes small, focused, and reviewable.

## Table of Contents

1. [What is Stacking?](#what-is-stacking)
2. [Core Concepts](#core-concepts)
3. [The Graphite Philosophy](#the-graphite-philosophy)
4. [Getting Started](#getting-started)
5. [Core Workflow](#core-workflow)
6. [Detailed Workflow Scenarios](#detailed-workflow-scenarios)
7. [The Complete Development Lifecycle](#the-complete-development-lifecycle)
8. [All Commands Reference](#all-commands-reference)
9. [MCP Integration for AI Agents](#mcp-integration-for-ai-agents)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)

---

## What is Stacking?

**Stacking** (or stacked pull requests) is a development workflow where new feature branches are created **on top of existing feature branches**, rather than directly off the main trunk.

Instead of one huge PR with all your changes, you have:
```
main <- PR1 (base changes) <- PR2 (built on PR1) <- PR3 (built on PR2)
```

### Benefits of Stacking

| Benefit | Description |
|---------|-------------|
| **Parallel Development** | Don't wait for one PR to merge before starting the next |
| **Smaller, Focused PRs** | Each PR addresses a distinct part of the feature (tens/hundreds of lines vs thousands) |
| **Faster Reviews** | Reviewers give feedback one piece at a time |
| **Clear History** | Each PR has a clear purpose; easier to revert specific changes |
| **No Mega-Branches** | Changes integrate to main in smaller chunks, reducing merge conflicts |

---

## Core Concepts

### Terminology

| Term | Definition | Example |
|------|------------|---------|
| **Stack** | A sequence of pull requests, each building off its parent | `main <- PR "add API" <- PR "update frontend" <- PR "docs"` |
| **Trunk** | The branch that stacks are merged into | `main` or `master` |
| **Downstack** | The PRs below a given PR in a stack (its ancestors) | If on PR3, downstack = PR2, PR1 |
| **Upstack** | The PRs above a given PR in a stack (its descendants) | If on PR1, upstack = PR2, PR3 |

### How Graphite Manages Stacks

Graphite maintains metadata about branch relationships. When you:
- **Modify a branch**: Graphite automatically rebases all upstack branches
- **Sync with trunk**: Graphite rebases your entire stack onto the latest main
- **Submit**: Graphite creates/updates PRs with correct base branches

---

## The Graphite Philosophy

### The Mental Model: Think in Slices, Not Features

Traditional Git workflow:
```
Feature Branch: 47 files changed, 2,847 insertions, 892 deletions
                One massive PR that takes days to review
```

Graphite workflow:
```
PR1: Database schema changes (5 files, ~100 lines)
PR2: API endpoints (8 files, ~200 lines)
PR3: Business logic (6 files, ~150 lines)
PR4: Frontend components (10 files, ~300 lines)
PR5: Tests (4 files, ~200 lines)
```

### The Key Insight: You're Always Building on Something

Every change you make builds on previous work. Graphite makes this explicit:

```
Without Graphite:
- You work on a feature branch
- You make commits
- Eventually you push one big PR
- You wait... and wait... for review
- Meanwhile, you're blocked or working on unrelated things

With Graphite:
- You make a small, coherent change → PR1
- You immediately continue building → PR2 (stacked on PR1)
- PR1 gets reviewed while you work on PR3
- Feedback on PR1? Fix it, Graphite updates PR2 and PR3 automatically
- PR1 merges, PR2 is now against main, ready to merge
- Continuous flow, never blocked
```

### Why This Matters

1. **Reviewers love small PRs** - A 100-line PR gets reviewed in minutes. A 1000-line PR sits for days.

2. **You stay unblocked** - Don't wait for reviews. Keep building.

3. **Mistakes are isolated** - Bug in PR2? Revert just PR2, not your entire feature.

4. **Progress is visible** - Stakeholders see incremental progress, not radio silence followed by a massive dump.

### How to Think About Breaking Work Into Stacks

Ask yourself: "What's the smallest useful change I can make?"

| Instead of... | Think... |
|---------------|----------|
| "Add user authentication" | PR1: Add user model, PR2: Add auth endpoints, PR3: Add middleware, PR4: Add login UI |
| "Refactor the payment system" | PR1: Extract interface, PR2: Implement new processor, PR3: Migrate existing code, PR4: Remove old code |
| "Add new dashboard" | PR1: Add route/page shell, PR2: Add data fetching, PR3: Add charts, PR4: Add filters |

### The Golden Rules

1. **Each PR should be independently reviewable** - Reviewer should understand it without seeing the rest of the stack

2. **Each PR should leave the codebase in a working state** - Tests pass, app runs (even if feature is incomplete)

3. **Stack from stable to experimental** - Put foundational changes at the bottom, risky changes at the top

4. **Don't be afraid to reorder** - Realized PR3 should be PR1? Use `gt reorder`

---

## Getting Started

### Prerequisites

1. Install Graphite CLI (see [graphite.dev/docs](https://graphite.dev/docs))
2. Authenticate with GitHub:
   ```bash
   gt auth --token <your-token>
   ```
3. Initialize in your repository:
   ```bash
   gt init
   ```

### Quick Verification

```bash
# Check current stack structure
gt log

# Show trunk branch
gt trunk
```

---

## Core Workflow

### 1. Creating Your First PR

```bash
# Start from trunk
gt checkout main

# Make your changes
echo "new feature code" >> feature.js

# Create a branch with commit (stages all, creates branch, commits)
gt create --all --message "feat(api): Add new API endpoint"

# Push and create PR
gt submit
```

### 2. Stacking Additional PRs

While PR1 is in review, continue working:

```bash
# Ensure you're on PR1's branch
gt checkout  # Interactive picker

# Make more changes
echo "frontend code" >> frontend.js

# Stack another PR on top
gt create --all --message "feat(frontend): Add user interface"

# Submit the entire stack
gt submit --stack
```

### 3. Addressing Review Feedback

When reviewers request changes on an earlier PR:

```bash
# Checkout the branch that needs changes
gt checkout feat/api-new-endpoint

# Make the requested changes
vim feature.js

# Amend the commit and auto-restack upstack branches
gt modify --all

# Push updated stack
gt submit --stack
```

### 4. Syncing with Trunk

Keep your stack up-to-date with latest main:

```bash
# Fetch main, rebase all stacks, cleanup merged branches
gt sync
```

### 5. Merging the Stack

Options for merging:

1. **Graphite UI**: Use "Merge Stack" button to merge all PRs in order
2. **Sequential merge**: Merge PR1 first, then PR2 becomes based on main
3. **Merge when ready**: Use `gt submit --merge-when-ready` flag

After merging:

```bash
# Cleanup: delete merged branches, update trunk
gt sync
```

---

## Detailed Workflow Scenarios

### Scenario 1: Starting a New Feature from Scratch

You're about to implement a user profile feature.

```bash
# 1. Start fresh from main
gt sync                    # Get latest main, cleanup old branches
gt checkout main           # Ensure you're on main

# 2. Plan your stack (mentally or in notes):
#    PR1: Add profile database schema
#    PR2: Add profile API endpoints
#    PR3: Add profile UI components
#    PR4: Add profile settings page

# 3. Implement PR1
# ... write your schema migration code ...
gt create -a -m "feat(db): Add user profile schema and migrations"

# 4. Immediately continue to PR2 (don't wait for review!)
# ... write your API code ...
gt create -a -m "feat(api): Add profile CRUD endpoints"

# 5. Continue to PR3
# ... write your components ...
gt create -a -m "feat(ui): Add ProfileCard and ProfileAvatar components"

# 6. Continue to PR4
# ... write your settings page ...
gt create -a -m "feat(ui): Add profile settings page"

# 7. Submit the entire stack for review
gt submit --stack

# 8. Visualize what you've created
gt log
```

### Scenario 2: Addressing Review Feedback Mid-Stack

Reviewer requests changes on PR2, but you're already on PR4.

```bash
# 1. See your current stack
gt log                     # Shows: main <- PR1 <- PR2 <- PR3 <- PR4 (you are here)

# 2. Navigate to the PR that needs changes
gt checkout PR2-branch     # Or use: gt down 2

# 3. Make the requested changes
# ... edit your code ...

# 4. Update the branch (choose one):
gt modify -a               # Amend existing commit (cleaner history)
# OR
gt modify -c -a -m "fix: address review feedback"  # New commit (preserves history)

# 5. Graphite automatically restacks PR3 and PR4 on top of updated PR2

# 6. Push all updates
gt submit --stack

# 7. Return to where you were working
gt top                     # Jump back to PR4
```

### Scenario 3: Main Has Updated While You're Working

Other changes have merged to main. Your stack needs to incorporate them.

```bash
# 1. Sync everything
gt sync

# This does:
# - Fetches latest main
# - Rebases your entire stack onto new main
# - Prompts to delete any merged branches

# 2. If conflicts occur:
# Graphite will tell you which branch has conflicts
# Fix conflicts in your editor
git add .
gt continue

# 3. Push updated stack
gt submit --stack
```

### Scenario 4: Realizing You Need to Reorder PRs

You created PR1 (API) then PR2 (tests), but realize tests should come first.

```bash
# 1. Navigate to the branch you want to reorder from
gt checkout PR2-branch

# 2. Open reorder editor
gt reorder

# 3. In the editor, change the order:
# Before:
#   main
#   PR1-api
#   PR2-tests
#
# After:
#   main
#   PR2-tests
#   PR1-api

# 4. Save and close - Graphite handles the rebasing

# 5. Submit reordered stack
gt submit --stack
```

### Scenario 5: Inserting a PR in the Middle of a Stack

You have PR1 <- PR2 <- PR3, but realize you need something between PR1 and PR2.

```bash
# 1. Checkout PR1 (the branch AFTER which you want to insert)
gt checkout PR1-branch

# 2. Create new branch with --insert flag
# ... write your new code ...
gt create -a -m "feat: new middleware" --insert

# 3. Graphite inserts the new branch and restacks PR2 and PR3 on top

# 4. Submit updated stack
gt submit --stack
```

### Scenario 6: Splitting a PR That Got Too Big

Your PR has multiple unrelated changes that should be separate.

```bash
# 1. Checkout the branch to split
gt checkout big-pr-branch

# 2. Split into multiple branches
gt split

# 3. Graphite walks you through:
#    - Shows each commit
#    - Asks which branch each should go to
#    - Creates new branches as needed

# 4. Submit the now-smaller PRs
gt submit --stack
```

### Scenario 7: Folding/Combining PRs

You have two small PRs that should really be one.

```bash
# 1. Checkout the PR you want to fold INTO its parent
gt checkout child-pr-branch

# 2. Fold it into parent
gt fold

# 3. The child's changes are now part of the parent PR
# Any grandchildren are restacked onto the parent

# 4. Submit
gt submit --stack
```

### Scenario 8: Abandoning Part of a Stack

PR3 in your stack is no longer needed, but PR4 still is.

```bash
# 1. Delete the unwanted branch
gt delete PR3-branch

# 2. Graphite automatically restacks PR4 onto PR2
# (PR4's parent becomes PR2)

# 3. Submit updated stack
gt submit --stack
```

### Scenario 9: Working on Multiple Independent Stacks

You have two unrelated features in progress.

```bash
# Stack A: User profiles
gt checkout main
gt create -a -m "feat(profiles): database schema"
gt create -a -m "feat(profiles): API endpoints"
gt submit --stack

# Stack B: Payment system (independent of Stack A)
gt checkout main          # Start from main, not from Stack A
gt create -a -m "feat(payments): stripe integration"
gt create -a -m "feat(payments): checkout flow"
gt submit --stack

# View all stacks
gt log                    # Shows both stacks branching from main

# Switch between stacks
gt checkout               # Interactive picker shows all branches
```

### Scenario 10: Partial Stack Merge

Only the first 2 PRs in a 4-PR stack are approved.

```bash
# 1. Navigate to the last approved PR
gt checkout PR2-branch

# 2. Merge just PR1 and PR2 via Graphite UI
#    (Or merge PR1 first, then PR2)

# 3. After merge, sync to update everything
gt sync

# 4. PR3 and PR4 are now rebased onto main
# They're still a stack, just with a new base

# 5. Continue development on PR3/PR4 as normal
gt checkout PR4-branch
# ... keep working ...
```

---

## The Complete Development Lifecycle

### Phase 1: Planning Your Stack

Before writing code, think about the logical breakdown:

```
Feature: User Authentication System

Stack Plan:
├── PR1: User model and database migrations
├── PR2: Password hashing utilities
├── PR3: JWT token generation/validation
├── PR4: Login/Register API endpoints
├── PR5: Auth middleware
└── PR6: Login/Register UI
```

**Key Questions:**
- Can each PR be understood in isolation?
- Does each PR leave tests passing?
- What's the dependency order?

### Phase 2: Initial Development

```bash
# Start clean
gt sync
gt checkout main

# Build bottom-up
# PR1: Foundation
gt create -a -m "feat(auth): Add User model with email and password_hash"

# PR2: Utilities (builds on PR1's User model)
gt create -a -m "feat(auth): Add password hashing utilities"

# PR3: Token handling (uses utilities from PR2)
gt create -a -m "feat(auth): Add JWT generation and validation"

# Continue stacking...
```

### Phase 3: Review Cycle

```
Timeline:
Day 1 AM: Submit stack of 4 PRs
Day 1 PM: PR1 approved, PR2 has feedback
Day 2 AM: Fix PR2 feedback, PR3 approved
Day 2 PM: PR1 merged, PR2 approved and merged
Day 3 AM: PR3 and PR4 now on main, merge them
```

```bash
# Day 1 PM: Address PR2 feedback
gt checkout PR2-branch
# ... make fixes ...
gt modify -a
gt submit --stack

# Day 2: Main has changed (PR1 merged)
gt sync                   # Updates everything

# PRs 2-4 are now rebased onto post-PR1 main
```

### Phase 4: Merging

**Option A: Merge All at Once (Graphite UI)**
- Open Graphite dashboard
- Click "Merge Stack"
- All PRs merge in order

**Option B: Sequential Merge**
```bash
# Merge each PR as it's approved
# PR1 approved → merge via GitHub/Graphite
gt sync                   # PR2-4 rebase onto main

# PR2 approved → merge
gt sync                   # PR3-4 rebase onto main

# Continue until all merged
```

**Option C: Auto-Merge When Ready**
```bash
# At submit time, set merge-when-ready
gt submit --stack --merge-when-ready

# PRs will auto-merge in order as they get approved
```

### Phase 5: Cleanup

```bash
# After all PRs merged
gt sync

# Graphite:
# - Updates main to latest
# - Detects merged branches
# - Prompts to delete local branches
# - Cleans up tracking metadata

# Ready for next feature!
gt checkout main
gt log                    # Clean slate
```

### The Daily Graphite Routine

```bash
# Morning: Start fresh
gt sync                   # Get latest, cleanup merged branches

# During Development: Create small commits
gt create -a -m "..."     # New branch for each logical chunk
gt submit                 # Push as you go

# When Feedback Arrives:
gt checkout <branch>      # Go to branch needing changes
gt modify -a              # Make changes, auto-restack
gt submit --stack         # Push updates

# End of Day:
gt sync                   # Incorporate any main changes
gt log                    # Review your stack state
```

---

## All Commands Reference

### Setup Commands

| Command | Description |
|---------|-------------|
| `gt auth` | Authenticate with Graphite for PR management |
| `gt init` | Initialize Graphite in repository, select trunk branch |

### Core Workflow Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `gt create [name]` | `c` | Create new branch stacked on current branch & commit staged changes |
| `gt modify` | `m` | Modify current branch (amend or new commit), auto-restack descendants |
| `gt submit` | `s` | Push branches to GitHub, create/update PRs |
| `gt sync` | - | Sync all branches from remote, rebase stacks, cleanup merged |

#### `gt create` Options

```bash
gt create --all --message "commit message"  # Stage all, set message
gt create -a -m "commit message"            # Short form
gt create --insert                          # Insert branch mid-stack
gt create feature-name                      # Specify branch name
gt branch create feature-name               # Create empty branch (no changes)
```

**Creating Empty Branches (Stack Roots)**:
When you run `gt create` or `gt branch create` with **no staged changes**, Graphite creates an empty branch. This is useful for:
- Creating a feature base branch that serves as the stack root
- Setting up a branch structure before writing code

```bash
# Create an empty base branch for a feature stack
gt checkout develop
gt branch create wha-123-feat-user-auth  # Creates empty branch, Graphite tracks it
# Now all subsequent gt create calls will stack on top of this
```

#### `gt submit` Options

```bash
gt submit                    # Submit current branch + downstack
gt submit --stack            # Submit entire stack
gt submit --draft            # Create as draft PRs
gt submit --reviewers alice  # Assign reviewers
gt submit --merge-when-ready # Auto-merge when approved
gt submit --no-interactive   # Non-interactive (for automation/AI)
```

#### `gt modify` Options

```bash
gt modify --all              # Stage all changes, amend commit
gt modify --commit --all     # Create new commit instead of amend
gt modify -c -a -m "message" # New commit with message
```

### Stack Navigation

| Command | Alias | Description |
|---------|-------|-------------|
| `gt checkout [branch]` | `co` | Switch branches; interactive picker if no branch given |
| `gt up [steps]` | `u` | Move to child branch (upstack) |
| `gt down [steps]` | `d` | Move to parent branch (downstack) |
| `gt top` | `t` | Jump to tip of current stack |
| `gt bottom` | `b` | Jump to base of current stack (closest to trunk) |
| `gt trunk` | - | Show the trunk branch |

### Branch Info

| Command | Alias | Description |
|---------|-------|-------------|
| `gt log` | `l` | Graphical representation of stack(s) |
| `gt log short` / `gt ls` | - | Concise list view |
| `gt log long` | - | Detailed view |
| `gt info [branch]` | - | Display info about current branch |
| `gt parent` | - | Show parent branch |
| `gt children` | - | Show child branches |

### Stack Management

| Command | Alias | Description |
|---------|-------|-------------|
| `gt restack` | `r` | Rebase stack to ensure parent commits are in history |
| `gt reorder` | - | Interactively reorder branches between trunk and current |
| `gt move` | - | Rebase current branch onto different target |
| `gt fold` | - | Fold branch's changes into parent, restack dependencies |
| `gt absorb` | `ab` | Amend staged changes to relevant commits in stack |
| `gt continue` | `cont` | Continue after resolving rebase conflict |
| `gt abort` | - | Abort current operation halted by conflict |

### Branch Management

| Command | Alias | Description |
|---------|-------|-------------|
| `gt delete [name]` | `dl` | Delete branch and metadata, restack children onto parent |
| `gt rename [name]` | `rn` | Rename branch and update metadata |
| `gt track [branch]` | `tr` | Start tracking branch with Graphite |
| `gt untrack [branch]` | `utr` | Stop tracking branch |
| `gt split` | `sp` | Split current branch into multiple branches |
| `gt squash` | `sq` | Squash all commits into single commit |
| `gt pop` | - | Delete branch but retain working tree changes |
| `gt get [branch]` | - | Sync branches from remote for given branch/PR |
| `gt freeze [branch]` | - | Freeze branch and downstack |
| `gt unfreeze [branch]` | - | Unfreeze branch and upstack |
| `gt undo` | - | Undo most recent Graphite mutation |
| `gt unlink [branch]` | - | Unlink PR from branch |
| `gt revert [sha]` | - | Create branch that reverts a trunk commit |

### Graphite Web

| Command | Description |
|---------|-------------|
| `gt pr [branch]` | Open PR page in browser |
| `gt dash` | Open Graphite dashboard |
| `gt merge` | Merge PRs from trunk to current branch via Graphite |

### Configuration

| Command | Description |
|---------|-------------|
| `gt config` | Configure Graphite CLI |
| `gt aliases` | Edit command aliases |
| `gt completion` | Setup bash/zsh tab completion |
| `gt fish` | Setup fish tab completion |

### Learning & Help

| Command | Description |
|---------|-------------|
| `gt demo [name]` | Run interactive demos to learn Graphite |
| `gt guide [title]` | Read extended guides |
| `gt docs` | Show CLI docs |
| `gt changelog` | Show CLI changelog |
| `gt feedback [msg]` | Send feedback to maintainers |

### Global Options

| Option | Description |
|--------|-------------|
| `--help` | Show help for command |
| `--cwd <path>` | Set working directory |
| `--debug` | Write debug output |
| `--interactive` / `--no-interactive` | Enable/disable interactive features |
| `--verify` / `--no-verify` | Enable/disable git hooks |
| `-q, --quiet` | Minimize output |
| `--version` | Show version |

---

## MCP Integration for AI Agents

Graphite provides an MCP (Model Context Protocol) server for AI agent integration. This enables AI assistants to create, manage, and submit stacked PRs programmatically.

### Available MCP Tools

#### `mcp__graphite__run_gt_cmd`

Execute any `gt` command programmatically.

**Parameters:**
- `args` (array): Command arguments, e.g., `["create", "-m", "feat: foo"]`
- `cwd` (string): Working directory (absolute path) - **REQUIRED**
- `why` (string): One-line description of why you're running this command

**Example:**
```json
{
  "args": ["create", "--all", "--message", "feat: add user authentication"],
  "cwd": "/path/to/project",
  "why": "Creating first branch in the stack for auth feature"
}
```

#### `mcp__graphite__learn_gt`

Retrieve comprehensive documentation about using Graphite for stacking PRs.

**Parameters:** None

---

### AI Agent Workflow - The Complete Guide

#### Critical Rules for AI Agents

| DO | DON'T |
|----|-------|
| Use `gt create` to commit | Use `git commit` |
| Use `gt submit --no-interactive` to push | Use `git push` |
| Write code BEFORE creating branches | Create empty branches first |
| Get user confirmation on stack structure | Assume a stack structure |
| Use `--no-interactive` flag | Rely on interactive prompts |

#### The AI Agent Stack Building Process

**Phase 1: Planning (ALWAYS DO THIS FIRST)**

Before writing any code, present the user with the proposed stack structure:

```
I'll implement this feature using a stack of PRs:

PR1: feat(db): Add user table migration
     - Creates users table with email, password_hash columns
     - Adds necessary indexes

PR2: feat(api): Add user registration endpoint
     - POST /api/users endpoint
     - Input validation
     - Password hashing

PR3: feat(api): Add user login endpoint
     - POST /api/auth/login endpoint
     - JWT token generation

PR4: test: Add authentication tests
     - Unit tests for user service
     - Integration tests for endpoints

Does this stack structure look good? Should I proceed?
```

**Phase 2: Implementation**

After user confirms, implement each PR sequentially:

```bash
# === PR1 ===
# 1. Write the code for PR1
# [AI writes migration files, model files, etc.]

# 2. Stage all changes
git add .

# 3. Create the branch with commit
gt create --all --message "feat(db): Add user table migration"

# === PR2 ===
# 1. Write the code for PR2 (builds on PR1)
# [AI writes endpoint code, validators, etc.]

# 2. Stage and create
git add .
gt create --all --message "feat(api): Add user registration endpoint"

# === Continue for each PR ===
```

**Phase 3: Submission**

After all PRs are created:

```bash
# Submit the entire stack
gt submit --no-interactive

# Get the PR URL to share with user
gt pr
```

#### Complete AI Agent Example

```bash
# User request: "Add user authentication to the app"

# Step 1: Sync to ensure clean state
gt sync

# Step 2: Ensure on main branch
gt checkout main

# Step 3: Present stack plan to user and get confirmation
# [AI presents plan, user confirms]

# Step 4: Implement PR1
# [AI writes: db/migrations/001_create_users.sql]
# [AI writes: src/models/user.ts]
git add .
gt create --all --message "feat(db): Add user model and migrations"

# Step 5: Implement PR2 (automatically stacked on PR1)
# [AI writes: src/routes/auth.ts]
# [AI writes: src/services/password.ts]
git add .
gt create --all --message "feat(api): Add registration endpoint with password hashing"

# Step 6: Implement PR3
# [AI writes: src/middleware/auth.ts]
# [AI writes: src/services/jwt.ts]
git add .
gt create --all --message "feat(api): Add login endpoint with JWT tokens"

# Step 7: Implement PR4
# [AI writes: tests/auth.test.ts]
git add .
gt create --all --message "test: Add authentication endpoint tests"

# Step 8: Submit all PRs
gt submit --no-interactive

# Step 9: Report to user
# "I've created a stack of 4 PRs for the authentication feature.
#  View the first PR at: [URL from gt pr output]"
```

#### Handling Modifications Mid-Stack

If user requests changes to an already-created PR:

```bash
# Navigate to the branch that needs changes
gt checkout <branch-name>

# Make the code changes
# [AI modifies files]

# Update the branch (amend existing commit)
git add .
gt modify --all

# Graphite automatically restacks all dependent branches

# Re-submit the updated stack
gt submit --no-interactive
```

#### Handling Errors and Edge Cases

**If not initialized:**
```bash
gt init
# Select trunk branch when prompted (usually 'main')
```

**If conflicts during restack:**
```bash
# Fix conflicts in files
git add .
gt continue
```

**If need to abort an operation:**
```bash
gt abort
```

**If need to see current state:**
```bash
gt log
# Or for more detail:
gt info
```

#### MCP Command Examples for Common Operations

**Check current stack:**
```json
{"args": ["log"], "cwd": "/path/to/project", "why": "Viewing current stack state"}
```

**Sync with remote:**
```json
{"args": ["sync"], "cwd": "/path/to/project", "why": "Syncing with latest main"}
```

**Navigate to branch:**
```json
{"args": ["checkout", "feature-branch"], "cwd": "/path/to/project", "why": "Switching to feature branch"}
```

**Create PR:**
```json
{"args": ["create", "--all", "--message", "feat: add feature"], "cwd": "/path/to/project", "why": "Creating new PR in stack"}
```

**Submit stack:**
```json
{"args": ["submit", "--stack", "--no-interactive"], "cwd": "/path/to/project", "why": "Submitting entire stack to GitHub"}
```

**Modify existing PR:**
```json
{"args": ["modify", "--all"], "cwd": "/path/to/project", "why": "Amending PR with new changes"}
```

**View PR in browser:**
```json
{"args": ["pr"], "cwd": "/path/to/project", "why": "Getting PR URL for user"}
```

#### AI Agent Checklist

Before starting:
- [ ] User has confirmed stack structure
- [ ] Repository is initialized with `gt init`
- [ ] Working directory is clean (no uncommitted changes)
- [ ] On correct starting branch (usually main)

For each PR:
- [ ] Write ALL code for this PR first
- [ ] Stage with `git add .`
- [ ] Create with `gt create --all --message "..."`

After all PRs:
- [ ] Submit with `gt submit --no-interactive`
- [ ] Share PR URL with user

---

## Best Practices

### Stack Size

- **Ideal**: 2-5 PRs per stack
- **Each PR**: 50-300 lines of changes
- **Rule of thumb**: If a PR takes more than 30 mins to review, split it

### Commit Messages

Follow conventional commits for automatic PR title generation:
```
feat(scope): description     # New feature
fix(scope): description      # Bug fix
refactor(scope): description # Code refactor
test(scope): description     # Tests
docs(scope): description     # Documentation
```

### Sync Frequency

```bash
# Sync at least daily to avoid large conflicts
gt sync
```

### When to Restack

- After making mid-stack changes with `gt modify`
- After resolving conflicts
- Before submitting PRs

### Handling Conflicts

```bash
# If sync/restack stops due to conflict:
# 1. Fix conflicts in files
# 2. Stage resolved files
git add <resolved-files>
# 3. Continue operation
gt continue
# 4. If you want to abort instead:
gt abort
```

---

## Troubleshooting

### "Your branch and origin/main have diverged"

```bash
# Fix by syncing - Graphite will rebase your stack onto latest main
gt sync
```

### Merge Conflicts During Restack

```bash
# 1. Check which branch has conflicts
# 2. Resolve conflicts in your editor
# 3. Stage fixes
git add .
# 4. Continue
gt continue
```

### Wrong Branch for Commit

```bash
# If you committed to wrong branch:
# Option 1: Split the branch
gt split

# Option 2: Reset and recreate
git reset HEAD~1
gt create --all --message "correct message"
```

### Lost Track of Stack Structure

```bash
# Visualize your stacks
gt log

# See detailed info about current branch
gt info
```

### Graphite Metadata Issues

```bash
# Re-track a branch manually
gt track <branch>

# Untrack and re-track if needed
gt untrack <branch>
gt track <branch>
```

### Undo Last Operation

```bash
# Undo most recent Graphite mutation
gt undo
```

---

## Quick Reference Card

```
# Creating & Submitting
gt create -a -m "message"    # Create branch with commit
gt submit --stack            # Submit entire stack
gt submit --no-interactive   # For automation

# Navigation
gt up / gt down              # Move in stack
gt top / gt bottom           # Jump to ends
gt checkout                  # Interactive picker

# Updating
gt modify -a                 # Amend + restack
gt sync                      # Update from trunk

# Visualization
gt log                       # See stack graph
gt ls                        # Short list

# Conflict Resolution
gt continue                  # After fixing conflicts
gt abort                     # Cancel operation
```

---

## Resources

- **Documentation**: https://graphite.dev/docs
- **Cheatsheet**: https://graphite.dev/docs/cheatsheet
- **Tutorial Videos**: https://www.youtube.com/@withgraphite
- **Community Slack**: https://community.graphite.dev
- **Troubleshooting**: https://graphite.dev/docs/troubleshooting
