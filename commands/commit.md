# Commit Command

Create a git commit with intelligent pre-commit hook resolution. This command ensures all quality checks pass before committing.

## Usage

```bash
/commit <message>
```

## Arguments

1. **message** (required) - The commit message following conventional commit format

## Command Overview

This command:
1. Stages changes and attempts to commit
2. **NEVER uses --no-verify** - hooks are mandatory
3. Analyzes and fixes any hook failures
4. Groups related issues for efficient resolution
5. Uses parallel agents for complex fixes
6. Retries until all hooks pass

## Pre-Commit Hook Resolution Process

### 1. Initial Commit Attempt

```bash
# Stage changes
git add -A

# Attempt commit (WITHOUT --no-verify)
git commit -m "<message>"
```

### 2. Hook Failure Analysis

When hooks fail, the system will:

1. **Capture all error output**
   - Linting errors
   - Type checking failures
   - Test failures
   - Formatting issues
   - Build errors

2. **Categorize issues** into groups:
   - **Formatting**: Prettier, ESLint formatting, etc.
   - **Linting**: ESLint rules, TSLint, Pylint, etc.
   - **Type Errors**: TypeScript, Flow, mypy, etc.
   - **Test Failures**: Unit tests, integration tests
   - **Import Issues**: Missing imports, circular dependencies
   - **Build Errors**: Compilation failures

3. **Create fix strategy** based on issue types

### 3. Intelligent Fix Execution

#### For Simple Issues (auto-fixable)
```bash
# Run auto-fix commands
npm run lint:fix      # or equivalent
npm run format        # or equivalent

# Re-attempt commit
git add -A
git commit -m "<message>"
```

#### For Complex Issues (require code changes)
```
1. Group related issues logically
2. Create internal fix plan
3. Launch parallel agents for each group:
   - Agent 1: Fix type errors in components/
   - Agent 2: Fix failing tests in services/
   - Agent 3: Resolve import issues
4. Verify fixes don't break functionality
5. Re-run checks after each fix group
```

### 4. Parallel Agent Strategy

When multiple issue groups exist:

```
CRITICAL: Each agent must:
1. Focus only on their assigned issue group
2. Not break existing functionality
3. Run relevant checks after fixes
4. Report completion status

Example parallel execution:
- Agent A: "Fix all TypeScript errors in src/components"
- Agent B: "Fix ESLint errors in src/utils" 
- Agent C: "Update failing tests in src/services"
```

### 5. Verification Loop

After fixes are applied:

```bash
# Re-run all checks locally
npm run lint
npm run typecheck  
npm run test
npm run build

# If all pass, attempt commit again
git add -A
git commit -m "<message>"

# If still failing, analyze new errors and repeat
```

## Fix Strategies by Issue Type

### Formatting Issues
- Auto-fixable with formatters
- Run appropriate formatter (Prettier, Black, etc.)
- Usually resolved in first pass

### Linting Errors
- Many are auto-fixable
- For non-fixable: analyze pattern and fix systematically
- Common fixes: unused variables, missing returns, etc.

### Type Errors
- Cannot be auto-fixed
- Require understanding the code context
- Fix by adding proper types or correcting logic
- Never use `any` or `@ts-ignore`

### Test Failures
- Analyze if tests or code is wrong
- Usually code changes broke tests
- Fix code to match test expectations
- Update tests only if requirements changed

### Import Issues
- Check for typos in import paths
- Verify files exist at specified paths
- Resolve circular dependencies
- Add missing dependencies

### Build Errors
- Usually severe issues
- Fix immediately before other issues
- Check syntax, missing files, config problems

## Quality Standards

**NEVER compromise on these:**

1. **No --no-verify flag** - Ever. Period.
2. **No suppression comments** - Fix the actual issues
3. **No lowering standards** - Don't disable rules
4. **All tests must pass** - Fix code, not tests
5. **Zero warnings** - Warnings are future errors

## Example Workflow

```bash
# User runs command
/commit "feat: add user authentication"

# System attempts commit
> Running pre-commit hooks...
> ❌ ESLint: 5 errors
> ❌ TypeScript: 3 errors  
> ❌ Tests: 2 failing

# System analyzes issues
> Grouping issues:
> - Group 1: ESLint errors (formatting + rules)
> - Group 2: TypeScript errors (missing types)
> - Group 3: Test failures (API changes)

# System creates fix plan
> Fix Plan:
> 1. Run ESLint auto-fix for formatting
> 2. Agent A: Fix TypeScript errors
> 3. Agent B: Update tests for API changes
> 4. Verify all fixes work together

# System executes fixes
> Running auto-fixes...
> Launching parallel agents...
> Agent A: Fixed 3 type errors
> Agent B: Updated 2 test cases
> Re-running checks...

# System retries commit
> ✅ All checks passed
> ✅ Commit successful: feat: add user authentication
```

## Error Recovery

If fixes create new issues:

1. **Stop and analyze** - Don't create fix loops
2. **Check for conflicts** - Ensure fixes don't conflict
3. **Rollback if needed** - Undo problematic fixes
4. **Try sequential fixes** - If parallel creates issues

## Integration with CI/CD

This command ensures:
- Local commits match CI standards
- No "fix lint" commits needed
- Consistent code quality
- Faster CI runs (pre-validated)

## Advanced Options

### Grouping Strategies

For large changesets, intelligent grouping:

```
By directory:
- Group 1: All issues in src/components/
- Group 2: All issues in src/services/
- Group 3: All issues in tests/

By issue type:
- Group 1: All formatting issues
- Group 2: All type errors
- Group 3: All test failures

By severity:
- Group 1: Build-breaking errors
- Group 2: Type/lint errors
- Group 3: Warnings/minor issues
```

### Parallel Agent Instructions

Each parallel agent receives:

```
Task: Fix [specific issue type] in [specific location]
Constraints:
- Do not modify files outside your scope
- Run [specific check] after fixes
- Ensure no regression in functionality
- Report issues you cannot fix
Success Criteria:
- All [issue type] resolved in [location]
- No new issues introduced
- Existing tests still pass
```

## Key Principles

1. **Quality First** - Never bypass quality checks
2. **Fix Root Causes** - Not symptoms
3. **Preserve Functionality** - Fixes shouldn't break features
4. **Efficient Resolution** - Use parallelism wisely
5. **Learn From Patterns** - Recognize common issues

## Common Patterns and Solutions

### Pattern: Unused Variables
```
Fix: Remove variable or use it properly
Never: Suppress with ignore comments
```

### Pattern: Missing Types
```
Fix: Add proper TypeScript types
Never: Use 'any' type
```

### Pattern: Formatting Issues
```
Fix: Run formatter
Never: Manually format (inconsistent)
```

### Pattern: Import Errors
```
Fix: Correct the path or add dependency
Never: Comment out the import
```

## Troubleshooting

If commit keeps failing:

1. **Check hook configuration** - Ensure hooks are properly set up
2. **Verify dependencies** - All linters/tools installed
3. **Review fix attempts** - Look for fix conflicts
4. **Run checks manually** - Identify specific failures
5. **Ask for help** - Some issues may need human input

## Notes

- This command enforces team standards
- Fixes are done intelligently, not blindly
- Parallel execution speeds up resolution
- Learning from patterns improves over time
- Quality is non-negotiable

Remember: **Good commits pass all checks. Great commits pass on the first try.**