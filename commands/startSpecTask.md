# Start Specification Task Command

Execute the next pending or in-progress task from a specification's task list.

## Usage

```bash
/startSpecTask <spec_name> [--reset]
```

## Arguments

1. **spec_name** (required) - Name of the specification with tasks (e.g., "user-authentication")
2. **--reset** (optional) - Reset all in-progress tasks to pending before starting

## Command Overview

This command:

1. Finds the next task to execute (in-progress or pending)
2. Updates task status to in-progress
3. Displays task details and instructions including agent assignments
4. Reminds about working directory (repository root, not .kiro parent)
5. Executes the task using specified agents for each phase
6. Updates status to complete when done

## Task Status Format

Tasks use this checkbox format:
- `- [ ]` Pending (not started)
- `- [-]` In Progress
- `- [x]` Complete

## Important: Worktrees, Branches, and Agents

### Worktree and Branch Strategy
- **Feature Worktree**: One worktree for the entire feature/specification
  - Created once at the beginning (Task #0)
  - Named: `feature/[spec-name]`
  - Location: `../[spec-name]` relative to main repo
  - This is the base branch for all task work
- **Task Branches**: Regular branches within the worktree
  - Created when starting each individual task (not in advance)
  - Always branched from `feature/[spec-name]` (not from other task branches)
  - Named: `task/[spec-name]-[number]-[description]`
  - Merged back to feature branch after completion
  - Deleted after merge to keep branch list clean

### Agent Awareness
When executing tasks, the following specialized agents are available:
- **start-git-task**: Creates task branch and GitHub sub-issues (user will create)
- **tdd-red-phase**: For writing failing tests first (can use --no-verify)
- **tdd-green-phase**: For implementing production-ready code
- **mutation-test-runner**: For verifying test quality on new/modified files
- **tdd-refactor-specialist**: For improving code while keeping tests green
- **qa-gatekeeper**: For final quality verification
- **lint-fixer**: For fixing linting issues (run in parallel when possible)
- **research-investigator**: For researching patterns and best practices
- **playwright-browser-executor**: For browser automation tasks
- **debug-log-cleaner**: For removing debug logs

### Working Directory
**CRITICAL**: Always execute from the worktree directory, NOT the main repository.

**Example Structure:**
- Main repository: `/workspace/project/`
- Feature worktree: `/workspace/project-user-auth/` (for user-auth spec)
- .kiro location: `/workspace/project/.kiro/` (in main repo)
- Execute from: `/workspace/project-user-auth/` (worktree directory)

**Note**: If the project structure is unclear, the command should:
1. Analyze the directory structure to find the actual repository
2. Identify where .kiro is located relative to the git repository
3. Determine the correct working directory before proceeding
4. Stop and ask for clarification if ambiguous

## Process

### 1. Worktree Setup Check (REQUIRED FIRST)

**Before ANY task execution**, the command MUST:
- Check if we're already in the feature worktree for this specification
- If NOT in the correct worktree:
  - Check if the feature worktree already exists (e.g., `feature/[spec-name]`)
  - If worktree doesn't exist:
    - Create it: `git worktree add ../[spec-name] -b feature/[spec-name]`
    - Navigate to the new worktree directory
  - If worktree exists:
    - Navigate to the existing worktree directory
- Confirm we're in the feature worktree before proceeding
- **Note**: The worktree is for the ENTIRE feature, not individual tasks

### 2. Documentation Review (AFTER WORKTREE)

**After ensuring correct worktree**, the command MUST:
- Review `.kiro/specs/[spec_name]/requirements.md` to understand what's being built
- Review `.kiro/specs/[spec_name]/design.md` to understand the architecture
- Review `.kiro/steering/` documents:
  - `product.md` for domain model and user roles
  - `structure.md` for architectural patterns
  - `tech.md` for technology stack and commands
- Review existing `README.md` to understand current state
- Review any `CLAUDE.md` files in relevant directories
- Build complete context before proceeding

### 3. Task Selection

After documentation review:
- Read tasks from `.kiro/specs/[spec_name]/tasks.md`
- Check if Task #0 exists (worktree setup task)
- If Task #0 doesn't exist or isn't complete, notify user to add it
- Find first task marked as `[-]` (in-progress)
- If none, find first task marked as `[ ]` (pending)
- If all complete, notify user
- Handle nested subtasks appropriately

### 4. Task Execution

For the selected task:
- **Ensures we're on the feature branch first**:
  - `git checkout feature/[spec-name]`
  - Pull latest changes if needed
- **Creates task-specific branch** from feature branch:
  - Branch name: `task/[spec-name]-[task-number]-[brief-description]`
  - Example: `task/user-auth-1-login-endpoint`
  - Create with: `git checkout -b task/[name]`
  - This ensures each task branches from the latest feature branch state
- Updates task status to `[-]` if pending
- Displays task number and description
- **Shows working directory** (worktree directory)
- **Identifies which agent to use** for each TDD phase
- Shows all implementation steps
- Highlights requirements being fulfilled
- Executes each step with verification using appropriate agents
- **Updates documentation** after each major phase
- Handles errors and rollback if needed

### 5. Completion Handling

After successful execution:
- Updates task status to `[x]`
- Runs verification steps
- **REQUIRED: Update Documentation**:
  - Update README.md with new features/setup
  - Update/create CLAUDE.md files for patterns
  - Update steering docs if architecture changed
- Commits all changes to the task branch
- **Merges task branch back to feature branch**:
  - Ensure all changes are committed on task branch
  - `git checkout feature/[spec-name]`
  - `git merge task/[task-branch-name] --no-ff` (preserve merge history)
  - Delete task branch: `git branch -d task/[task-branch-name]`
- Shows completion summary
- Returns to feature branch for next task
- Identifies next task

## Example Usage

```bash
# First time - will prompt to create worktree
/startSpecTask user-authentication
# Creates: git worktree add ../user-authentication -b feature/user-authentication
# Switches to feature/user-authentication branch
# Then creates and checks out: task/user-auth-1-setup

# Task 2 - uses existing worktree
/startSpecTask user-authentication
# Already in worktree
# Switches to feature/user-authentication branch first
# Creates new branch from feature: task/user-auth-2-login

# Task 3 - always branches from feature, not task-2
/startSpecTask user-authentication  
# Switches to feature/user-authentication (has task 1 & 2 merged)
# Creates: task/user-auth-3-validation (from feature, not task-2)

# Reset in-progress tasks and start fresh
/startSpecTask user-authentication --reset
```

## Task State Management

### Branch Flow Diagram
```
main/develop
    └── feature/user-auth (worktree - created once)
            ├── task/user-auth-1-setup (branches from feature)
            │     └── (merges back to feature)
            ├── task/user-auth-2-login (branches from feature, not task-1)
            │     └── (merges back to feature)
            └── task/user-auth-3-validation (branches from feature, not task-2)
                  └── (merges back to feature)

Each task ALWAYS branches from feature, NEVER from another task branch
```

### State Transitions
```
Pending [ ] → In Progress [-] → Complete [x]
         ↑                 ↓
         ←── (on error) ───┘
```

### In-Progress Handling
- Only one task can be in-progress at a time
- If a task is already in-progress, continues from there
- Allows resuming interrupted work
- Tracks which steps were completed

### Reset Functionality
With `--reset` flag:
- All `[-]` tasks become `[ ]`
- Useful when switching contexts
- Helps recover from failed attempts
- Preserves completed `[x]` tasks

## Task Display Format

When starting a task, displays:

```markdown
═══════════════════════════════════════════════════════════
WORKTREE SETUP PHASE
═══════════════════════════════════════════════════════════
Checking worktree status...
✓ Feature worktree: feature/[spec-name]
✓ Location: ../[spec-name]/
✓ Status: [Creating new | Using existing]
✓ Current directory: [worktree path]

═══════════════════════════════════════════════════════════
DOCUMENTATION REVIEW PHASE
═══════════════════════════════════════════════════════════
Reviewing:
✓ Requirements: .kiro/specs/[spec]/requirements.md
✓ Design: .kiro/specs/[spec]/design.md
✓ Steering: product.md, structure.md, tech.md
✓ README.md and CLAUDE.md files
✓ Current project state and patterns

Context built successfully. Proceeding to task...

═══════════════════════════════════════════════════════════
Starting Task #2: [Task Description from tasks.md]
Status: In Progress
Working Directory: [worktree directory]/
Base Branch: feature/[spec-name] (checking out first)
Task Branch: task/[spec-name]-2-[description] (creating from feature branch)
═══════════════════════════════════════════════════════════

Note: Working directory is automatically determined by:
- Finding the git repository root
- Identifying the correct subdirectory if multiple repos exist
- NOT using the .kiro parent directory

Agent Assignments for this task:
- TDD Red Phase: Use `tdd-red-phase` agent
- TDD Green Phase: Use `tdd-green-phase` agent  
- Mutation Testing: Use `mutation-test-runner` agent
- Refactor: Use `tdd-refactor-specialist` agent
- Documentation: Update README.md, CLAUDE.md, steering docs
- Quality Check: Use `qa-gatekeeper` agent
- Linting Issues: Use `lint-fixer` agent (run in parallel)

Steps to execute:
[Steps will be determined from the task definition and project context]

Requirements fulfilled: [requirement IDs from task]

Documentation will be updated after task completion.

Press Enter to continue or Ctrl+C to abort...
```

## Execution Features

### Step-by-Step Execution with Agents
- Uses specified agent for each TDD phase
- Executes from correct working directory (worktree directory)
- Shows command output from each agent
- Validates success before continuing
- Allows manual intervention if needed
- Each task gets fresh branch from feature branch

### Error Handling
- Detects command failures
- Offers retry options with appropriate agent
- Can rollback changes
- Maintains task as in-progress for retry
- Suggests `lint-fixer` agent for linting issues

### Verification Steps
- Runs tests after implementation (via agents)
- Checks file creation in correct directory
- Validates configuration
- Ensures requirements are met
- Uses `qa-gatekeeper` agent for final verification

### Quality Gates
- Linting checks (use `lint-fixer` agent if issues)
- Type checking
- Test execution (including mutation testing)
- Build verification
- All existing tests must pass (no regressions)

## Progress Tracking

### Status Summary
Shows at start:
```
Task Progress for user-authentication:
- Complete: 3/10 tasks
- In Progress: 1 task (#4)
- Pending: 6 tasks
```

### Completion Tracking
After each task:
```
✓ Task #4 completed successfully!
✓ Documentation updated:
  - README.md updated with new features
  - CLAUDE.md created/updated with patterns
  - Steering docs remain current
Next task: #5 - Implement authentication API endpoints
```

## Advanced Features

### Subtask Handling
- Tracks subtask completion
- Must complete all subtasks before parent
- Shows subtask progress
- Maintains hierarchy

### Dependency Checking
- Verifies prerequisite tasks are complete
- Warns about missing dependencies
- Suggests task order corrections
- Prevents out-of-order execution

### Commit Integration
- Creates commits at checkpoints
- Uses descriptive messages from tasks
- Maintains clean git history
- Tags tasks in commit messages

## Task File Updates

### Task #0 (Worktree Setup - Always First)
```markdown
- [ ] 0. Setup Feature Worktree
  - Create worktree: `git worktree add ../[spec-name] -b feature/[spec-name]`
  - Navigate to worktree directory
  - Verify setup with `git status`
  - This worktree will be used for ALL tasks in this specification
```

### Before Execution (Regular Tasks)
```markdown
- [ ] 2. [Feature Implementation Task]
  - Create task branch: `git checkout -b task/[spec-name]-2-[description]`
  - [Task-specific steps based on project context]...
```

### During Execution
```markdown
- [-] 2. [Feature Implementation Task]
  - Create feature branch: `git checkout -b feature/[task-name]`
  - [Task-specific steps based on project context]...
```

### After Completion
```markdown
- [x] 2. [Feature Implementation Task]
  - Create feature branch: `git checkout -b feature/[task-name]`
  - [Task-specific steps based on project context]...
```

## Related Commands

- `/createSpecTask` - Create or update task list
- `/executeSlice` - Execute a specific vertical slice
- `/createSpecDesign` - Update design that drives tasks
- `/createSpecReq` - Update requirements that tasks fulfill

## Notes

- Requires tasks.md file in spec directory
- **ALWAYS reviews documentation before starting**
- **ALWAYS updates documentation after completing**
- Preserves task history and status
- Supports interrupted workflow resumption
- Integrates with git for version control
- Maintains audit trail of changes
- Can be run multiple times safely
- Documentation is critical for project continuity