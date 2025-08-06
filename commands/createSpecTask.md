# Create Specification Tasks Command

Generate a detailed implementation task list based on design document and requirements with mandatory TDD, quality gates, and multi-commit workflow.

## Usage

```bash
/createSpecTask <spec_name>
```

## Arguments

1. **spec_name** (required) - Name of the specification that has requirements and design (e.g., "user-authentication")

## Command Overview

This command generates an implementation plan that:

1. **Enforces Test-Driven Development (TDD)** - All tasks must follow Red-Green-Refactor cycle
2. **Requires Feature Branches** - Every task starts with branch creation
3. **Mandates Multiple Commits** - Minimum 3 commits per task with specific checkpoints
4. **Enforces Quality Gates** - Never use `--no-verify`, all checks must pass
5. **Tracks Source References** - Links tasks to design docs, specs, and related files

## Important: Working Directory

**CRITICAL**: The .kiro directory is typically in a parent directory that is NOT a git repository. Tasks must be executed from the actual repository root (child of .kiro parent). For example:
- .kiro location: `/workspace/project-planning/`
- Repository root: `/workspace/project-planning/web-app/` or `/workspace/project-planning/mobile-app/`
- Tasks execute from: The repository root, NOT the .kiro parent

## Process

### 1. Design Analysis

The command will:
- Read design from `.kiro/specs/[spec_name]/design.md`
- Read requirements from `.kiro/specs/[spec_name]/requirements.md`
- Read steering documents from project root
- Analyze implementation order and dependencies
- Map design components to TDD-based tasks
- Identify correct working directory for each task

### 2. Task Generation

Creates or updates task document in `.kiro/specs/[spec_name]/tasks.md`:

#### Document Structure
```markdown
# Implementation Plan

## Task Workflow Requirements
- **TDD Mandatory**: Write tests FIRST, then implementation
- **Branch Management**: Create feature branch before any code changes
- **Commit Pattern**: Minimum 3 commits (test-red, test-green, refactor, docs)
- **Quality Gates**: All checks must pass (no --no-verify except red phase)
- **Working Directory**: Execute from repository root (child of .kiro parent)
- **Agent Usage**: Use specialized agents for each TDD phase
- **Documentation**: MUST update README.md, CLAUDE.md, and steering docs

## Tasks

Each task follows the TDD workflow with specific agent assignments:
- Red Phase → Green Phase → Mutation Testing → Refactor → Documentation → Quality Gates

See the complete example below for detailed task structure.
```

### 3. Update Strategy

If tasks.md already exists:
- Preserves existing task states
- Adds new tasks for updated requirements
- Maintains only one in-progress task

## Key Features

### Core Requirements
- **TDD Mandatory**: All tasks follow Red-Green-Refactor cycle with mutation testing
- **Feature Branches**: Every task starts on its own branch
- **Multiple Commits**: Minimum 3 commits per task (test, implement, refactor, docs)
- **Quality Gates**: All checks must pass (NO --no-verify except red phase)
- **Documentation Updates**: README.md, CLAUDE.md, and steering docs MUST be updated
- **Working Directory**: Always execute from repository root, NOT .kiro parent

## Task Structure Example (Framework/Language Agnostic)

```markdown
- [ ] 1. Implement [Feature Name] with TDD
  **Branch**: `feature/[task-number]-[descriptive-name]`
  **Working Directory**: `[repository-root]/` (determined by project structure)
  **Source**: design.md:[line-numbers], requirements.md:[line-numbers]
  
  ### TDD Phase 1: Write Failing Tests (Red)
  **Agent**: Use `tdd-red-phase` agent
  - Create test file(s) for [feature/component]
  - Write comprehensive test cases covering:
    - Happy path scenarios
    - Edge cases and boundaries
    - Error handling
    - Integration points
  - Verify tests fail with meaningful errors
  - **Commit**: "test: add failing tests for [feature]" (--no-verify allowed)
  
  ### TDD Phase 2: Make Tests Pass (Green)
  **Agent**: Use `tdd-green-phase` agent
  - Implement production-ready functionality
  - Follow clean code and DDD principles
  - Ensure proper error handling
  - Run tests to verify all pass
  - **Commit**: "feat: implement [feature] (tests passing)"
  
  ### TDD Phase 3: Mutation Testing
  **Agent**: Use `mutation-test-runner` agent
  - Run mutation tests on new/modified files only
  - Strengthen tests to achieve 70-80% mutation score
  - Add missing test cases for survived mutants
  - **Commit**: "test: improve [feature] test quality via mutation testing"
  
  ### TDD Phase 4: Refactor
  **Agent**: Use `tdd-refactor-specialist` agent
  - Extract reusable components/utilities
  - Improve code organization and naming
  - Reduce complexity and duplication
  - Ensure all tests remain green
  - **Commit**: "refactor: improve [feature] structure and maintainability"
  
  ### Additional Phases (if needed)
  - UI/Frontend integration
  - API endpoint connections
  - Database migrations
  - Configuration updates
  - **Commit**: "[type]: [specific change description]"
  
  ### Documentation Update Phase (REQUIRED)
  **Critical**: Update all relevant documentation
  - Update README.md with:
    - New features/functionality added
    - Any new setup or configuration steps
    - Updated usage instructions
    - New dependencies or requirements
  - Update/Create CLAUDE.md files:
    - Document patterns and decisions made
    - Record any gotchas or important context
    - Update component/module documentation
  - Update .kiro/steering docs if needed:
    - Update tech.md with new commands/tools
    - Update structure.md if architecture changed
    - Update product.md if domain model evolved
  - **Commit**: "docs: update documentation for [feature]"
  
  ### Quality Gates Checklist
  **Agent**: Use `qa-gatekeeper` agent for verification
  - [ ] All tests pass (unit, integration, e2e as applicable)
  - [ ] Linting passes (use `lint-fixer` agent if issues)
  - [ ] Type checking passes (if applicable)
  - [ ] Build succeeds
  - [ ] Mutation score meets threshold (70%+ for new code)
  - [ ] Code coverage acceptable
  - [ ] README.md updated with new functionality
  - [ ] CLAUDE.md files updated/created where needed
  - [ ] Steering docs updated if architecture/tools changed
  
  _Requirements: [list of requirement IDs fulfilled]_
```

### Notes on Framework Detection
- The agents will automatically detect the project's language and framework
- Test commands, file paths, and structure will be determined from project context
- If project structure is unclear, agents will analyze and learn before proceeding
- Each agent knows how to work with various frameworks and will adapt accordingly

## Task Categories

All task types follow the same TDD workflow:
1. **Setup Tasks** - Configuration and environment
2. **Feature Tasks** - New functionality 
3. **Integration Tasks** - Connecting components
4. **Infrastructure Tasks** - System-level changes

## Progress Tracking

- `[ ]` Pending - Not started
- `[~]` In-progress - Currently working (only one at a time)
- `[x]` Complete - All phases done, quality gates passed, docs updated

## Agent Integration

### TDD Phase Agents (Required)
- **tdd-red-phase**: Writes comprehensive failing tests first
- **tdd-green-phase**: Implements production-ready code to pass tests
- **mutation-test-runner**: Verifies test quality on new/modified files only
- **tdd-refactor-specialist**: Improves code while keeping tests green
- **qa-gatekeeper**: Final quality verification before task completion

### Support Agents (As Needed)
- **research-investigator**: Research patterns, best practices, or understand codebase
- **lint-fixer**: Fix linting issues (run in parallel when possible)
- **playwright-browser-executor**: Browser automation and UI testing
- **debug-log-cleaner**: Remove debug logs before commits

**Critical**: Only `tdd-red-phase` agent can use --no-verify (for failing tests)

## Validation Checks

The command validates:
- TDD phases with correct agent assignments
- Working directory is repository root (not .kiro parent)
- Minimum 3 commits per task
- Documentation update requirements
- Source references to design/requirements

## Output Location

Document is created in:
```
.kiro/specs/[spec_name]/
├── requirements.md (existing)
├── design.md (existing)
└── tasks.md (generated with TDD structure)
```

## Enforcement Rules

1. **TDD REQUIRED**: Every task must start with failing tests
2. **MULTI-COMMIT**: Single commit tasks are invalid  
3. **BRANCH REQUIRED**: Direct main/develop commits forbidden
4. **QUALITY MANDATORY**: All checks must pass (no --no-verify except red phase)
5. **DOCUMENTATION MANDATORY**: README and CLAUDE.md must be updated

## Related Commands

- `/createSteering` - Create or update steering documents
- `/createSpecReq` - Create requirements document
- `/createSpecDesign` - Create design document from requirements
- `/startSpecTask` - Start the next pending or in-progress task
- `/executeSlice` - Execute tasks with quality gates

## Notes

- Tasks enforce TDD with quality gates from the start
- Multiple commits provide clear development history
- Documentation updates ensure project knowledge stays current
- Agents automatically adapt to project framework/language