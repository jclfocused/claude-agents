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

## ⚠️ CRITICAL: WORKTREE CHECK FIRST ⚠️

**STOP! Before doing ANYTHING else (including reading documentation or task files):**

1. **CHECK** if you're in the correct worktree for this specification
2. **CREATE/NAVIGATE** to the feature worktree if not already there
3. **ONLY THEN** proceed with any other steps

**NO EXCEPTIONS - This MUST happen before ANY file reads or operations**

**Why?** All work MUST happen in the feature worktree, not the main repository. Reading files or checking tasks from the wrong location will cause problems.

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
  - **PARALLEL EXECUTION**: Launch multiple instances for different test files
- **tdd-green-phase**: For implementing production-ready code
  - **PARALLEL EXECUTION**: Launch multiple instances for different modules
- **mutation-test-runner**: For verifying test quality on new/modified files
- **tdd-refactor-specialist**: For improving code while keeping tests green
- **qa-gatekeeper**: For final quality verification
- **lint-fixer**: For fixing linting issues (run in parallel when possible)
- **research-investigator**: For researching patterns and best practices
- **playwright-browser-executor**: For browser automation tasks
- **debug-log-cleaner**: For removing debug logs

### Parallel Agent Execution Strategy
- **Identify test scope**: Determine which test files/modules are needed
- **Launch agents simultaneously**: Use Task tool with multiple agent calls
- **Wait for completion**: All parallel agents must complete before proceeding
- **Aggregate results**: Combine outputs from all parallel agents

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

## Parallel Execution Implementation

### How Parallel TDD Works

When a task involves multiple test files or modules, the command will:

1. **Analyze the task** to identify all test files needed
2. **Launch agents simultaneously** using the Task tool
3. **Monitor progress** of all parallel agents
4. **Aggregate results** once all complete

#### Example Parallel Execution Call

```javascript
// RED Phase - Launch 3 agents in parallel for different test files
await Promise.all([
  Task({ 
    subagent_type: "tdd-red-phase",
    prompt: "Write failing tests for UserController in src/controllers/UserController.test.ts",
    description: "TDD Red: UserController"
  }),
  Task({
    subagent_type: "tdd-red-phase", 
    prompt: "Write failing tests for AuthService in src/services/AuthService.test.ts",
    description: "TDD Red: AuthService"
  }),
  Task({
    subagent_type: "tdd-red-phase",
    prompt: "Write failing tests for ValidationHelper in src/helpers/ValidationHelper.test.ts", 
    description: "TDD Red: ValidationHelper"
  })
]);

// GREEN Phase - Launch 3 agents in parallel for implementations
await Promise.all([
  Task({
    subagent_type: "tdd-green-phase",
    prompt: "Implement UserController to make tests pass",
    description: "TDD Green: UserController"
  }),
  Task({
    subagent_type: "tdd-green-phase",
    prompt: "Implement AuthService to make tests pass",
    description: "TDD Green: AuthService"
  }),
  Task({
    subagent_type: "tdd-green-phase",
    prompt: "Implement ValidationHelper to make tests pass",
    description: "TDD Green: ValidationHelper"
  })
]);
```

### Benefits of Parallel Execution

- **Speed**: 3-5x faster for multi-file tasks
- **Efficiency**: Better CPU utilization
- **Independence**: Each agent works on separate files
- **Consistency**: All tests written with same requirements context

## Process (WORKTREE FIRST - NO EXCEPTIONS)

### 1. 🚨 MANDATORY FIRST: Worktree Setup Check 🚨

**THIS MUST HAPPEN BEFORE ANYTHING ELSE - NO DOCUMENTATION, NO FILE READS, NOTHING!**

**Before ANY other action**, the command MUST:
- **IMMEDIATELY** check if we're already in the feature worktree for this specification
- If NOT in the correct worktree:
  - Check if the feature worktree already exists (e.g., `feature/[spec-name]`)
  - If worktree doesn't exist:
    - Create it: `git worktree add ../[spec-name] -b feature/[spec-name]`
    - Navigate to the new worktree directory
  - If worktree exists:
    - Navigate to the existing worktree directory
- Confirm we're in the feature worktree before proceeding
- **Note**: The worktree is for the ENTIRE feature, not individual tasks

**DO NOT PROCEED TO STEP 2 UNTIL WORKTREE IS CONFIRMED!**

### 2. Documentation Review (ONLY AFTER WORKTREE IS CONFIRMED)

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
- **Executes TDD phases with parallel agents**:
  - **RED Phase**: Launch multiple `tdd-red-phase` agents in parallel
    - One agent per test file or module
    - All agents run simultaneously for speed
  - **GREEN Phase**: Launch multiple `tdd-green-phase` agents in parallel
    - One agent per failing test file
    - Parallel implementation for all modules
  - **REFACTOR Phase**: Single `tdd-refactor-specialist` agent
  - **MUTATION Testing**: Single `mutation-test-runner` agent on changed files
- Shows all implementation steps
- Highlights requirements being fulfilled
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
# RED Phase: Launches 3 tdd-red-phase agents in parallel (for 3 test files)
# GREEN Phase: Launches 3 tdd-green-phase agents in parallel (for 3 modules)

# Task 2 - uses existing worktree
/startSpecTask user-authentication
# Already in worktree
# Switches to feature/user-authentication branch first
# Creates new branch from feature: task/user-auth-2-login
# Parallel agents for faster execution

# Task 3 - always branches from feature, not task-2
/startSpecTask user-authentication  
# Switches to feature/user-authentication (has task 1 & 2 merged)
# Creates: task/user-auth-3-validation (from feature, not task-2)
# Runs parallel TDD agents for all test/implementation files

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
🚨 MANDATORY FIRST STEP: WORKTREE SETUP PHASE 🚨
═══════════════════════════════════════════════════════════
THIS MUST HAPPEN BEFORE ANYTHING ELSE!
Checking worktree status...
✓ Feature worktree: feature/[spec-name]
✓ Location: ../[spec-name]/
✓ Status: [Creating new | Using existing]
✓ Current directory: [worktree path]

WORKTREE CONFIRMED - NOW PROCEEDING WITH OTHER STEPS

═══════════════════════════════════════════════════════════
DOCUMENTATION REVIEW PHASE (Step 2 - After Worktree)
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
- TDD Red Phase: Use `tdd-red-phase` agents IN PARALLEL
  - Launch one agent per test file/module
  - Example: UserController.test.ts, AuthService.test.ts, ValidationHelper.test.ts
  - All run simultaneously for faster test creation
- TDD Green Phase: Use `tdd-green-phase` agents IN PARALLEL
  - Launch one agent per implementation module
  - Example: UserController.ts, AuthService.ts, ValidationHelper.ts
  - Parallel implementation of all failing tests
- Mutation Testing: Use `mutation-test-runner` agent on changed files
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

### Parallel TDD Execution
- **Automatic parallelization**: Detects multiple test files and runs agents concurrently
- **RED Phase parallelization**:
  ```
  Launching parallel TDD Red Phase agents:
  - Agent 1: Creating tests for UserController
  - Agent 2: Creating tests for AuthService  
  - Agent 3: Creating tests for ValidationHelper
  [All agents run simultaneously]
  ```
- **GREEN Phase parallelization**:
  ```
  Launching parallel TDD Green Phase agents:
  - Agent 1: Implementing UserController
  - Agent 2: Implementing AuthService
  - Agent 3: Implementing ValidationHelper
  [All agents run simultaneously]
  ```
- **Time savings**: 3x-5x faster for multi-file tasks
- **Result aggregation**: Combines outputs and verifies all tests

### Step-by-Step Execution with Agents
- Uses specified agents for each TDD phase
- **Parallel execution for RED and GREEN phases**:
  - Launches multiple agents simultaneously
  - Significantly reduces overall execution time
  - Aggregates results from all parallel agents
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

## ❌ Common Mistakes to Avoid

**THESE WILL BREAK YOUR WORKFLOW:**

1. **Starting ANY work before checking worktree** - This is the #1 mistake!
2. **Reading task files before worktree setup** - You'll read from the wrong location
3. **Reviewing documentation before worktree setup** - Documentation might be different in worktree
4. **Assuming you're in the right directory** - Always verify explicitly
5. **Checking git status before worktree check** - Worktree check comes FIRST
6. **Looking at .kiro files before worktree** - These must be read from the worktree

**Remember:** WORKTREE CHECK → THEN EVERYTHING ELSE

## Related Commands

- `/createSpecTask` - Create or update task list
- `/executeSlice` - Execute a specific vertical slice
- `/createSpecDesign` - Update design that drives tasks
- `/createSpecReq` - Update requirements that tasks fulfill

## Notes

- Requires tasks.md file in spec directory
- **ALWAYS reviews documentation before starting**
- **ALWAYS updates documentation after completing**
- **Parallel agent execution for TDD phases**
- Preserves task history and status
- Supports interrupted workflow resumption
- Integrates with git for version control
- Maintains audit trail of changes
- Can be run multiple times safely
- Documentation is critical for project continuity
- Performance optimized through parallel execution