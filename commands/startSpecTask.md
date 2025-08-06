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

## Important: Agents and Working Directory

### Agent Awareness
When executing tasks, the following specialized agents are available:
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
**CRITICAL**: Always execute from the repository root directory, NOT the .kiro parent.

**Example Structure:**
- .kiro location: `/workspace/planning/` (parent, not a git repo)
- Repository: `/workspace/planning/web-app/` (actual git repository)
- Execute from: `/workspace/planning/web-app/` (repository root)

**Note**: If the project structure is unclear, the command should:
1. Analyze the directory structure to find the actual repository
2. Identify where .kiro is located relative to the git repository
3. Determine the correct working directory before proceeding
4. Stop and ask for clarification if ambiguous

## Process

### 1. Documentation Review (REQUIRED FIRST STEP)

**Before ANY task execution**, the command MUST:
- Review `.kiro/specs/[spec_name]/requirements.md` to understand what's being built
- Review `.kiro/specs/[spec_name]/design.md` to understand the architecture
- Review `.kiro/steering/` documents:
  - `product.md` for domain model and user roles
  - `structure.md` for architectural patterns
  - `tech.md` for technology stack and commands
- Review existing `README.md` to understand current state
- Review any `CLAUDE.md` files in relevant directories
- Build complete context before proceeding

### 2. Task Selection

After documentation review:
- Read tasks from `.kiro/specs/[spec_name]/tasks.md`
- Find first task marked as `[-]` (in-progress)
- If none, find first task marked as `[ ]` (pending)
- If all complete, notify user
- Handle nested subtasks appropriately

### 3. Task Execution

For the selected task:
- Updates status to `[-]` if pending
- Displays task number and description
- **Shows working directory** (repository root, not .kiro parent)
- **Identifies which agent to use** for each TDD phase
- Shows all implementation steps
- Highlights requirements being fulfilled
- Executes each step with verification using appropriate agents
- **Updates documentation** after each major phase
- Handles errors and rollback if needed

### 4. Completion Handling

After successful execution:
- Updates task status to `[x]`
- Runs verification steps
- **REQUIRED: Update Documentation**:
  - Update README.md with new features/setup
  - Update/create CLAUDE.md files for patterns
  - Update steering docs if architecture changed
- Commits all changes including documentation
- Shows completion summary
- Identifies next task

## Example Usage

```bash
# Start next task for user-authentication
/startSpecTask user-authentication

# Reset in-progress tasks and start fresh
/startSpecTask user-authentication --reset

# Continue working on hello-world-setup
/startSpecTask hello-world-setup
```

## Task State Management

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
Working Directory: [auto-detected repository root]/
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
- Executes from correct working directory (repository root)
- Shows command output from each agent
- Validates success before continuing
- Allows manual intervention if needed

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

### Before Execution
```markdown
- [ ] 2. [Feature Implementation Task]
  - Create feature branch: `git checkout -b feature/[task-name]`
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