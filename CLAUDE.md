# Global Development Standards

## Node.js Development

### Version Requirements

- Always use Node.js 22 by default (Check project for overrides)
- Check current Node version with `node --version` before starting work

### Package Management

- Install packages without specifying versions in package.json
- Use command line installation: `npm install package1 package2 ...`
- For dev dependencies: `npm install --save-dev package1 package2 ...`
- Always check for latest versions - LLMs often have outdated version information
- Verify actual latest versions with `npm view [package] version` or npm registry

## AI Knowledge Base (MCP Servers)

### Notion Documentation (For General Knowledge Only)

- **Notion is for GENERAL knowledge**: Only use for language best practices, patterns, frameworks - NOT project-specific content
- **Search at project start**: Use `mcp__ai-knowledge-hub__list-database-pages` to find relevant general documentation
- **Default search is TAG search**: Pass individual tags as array, not sentences (e.g., ["vue", "testing", "best-practices"] NOT "vue testing best practices")
- **Document REUSABLE patterns**: Only create/update Notion for knowledge applicable across multiple projects
- **Examples of Notion content**: "Vue Best Practices", "Clean Architecture Patterns", "TDD Guidelines"
- **DO NOT use legacy commands**: Ignore `mcp__ai-knowledge-hub__legacy-*` commands for now
- **Guru commands**: Only use `mcp__ai-knowledge-hub__guru-*` commands when explicitly asked

### Documentation Workflow

1. **Start of project/slice**: Search Notion for existing general patterns and best practices
2. **During development**: 
   - Project-specific docs → Create CLAUDE.md files in the repo near relevant code
   - General patterns → Note for potential Notion documentation
3. **End of task**:
   - Project context → Commit CLAUDE.md files with the code
   - Reusable patterns → Create/update Notion pages ONLY if generally applicable
4. **Location Guidelines**:
   - `/src/stores/CLAUDE.md` → Store patterns for this project
   - `/src/components/CLAUDE.md` → Component patterns for this project
   - Notion → "Vue Component Best Practices" (general, reusable)

## Background Task Management

### IMPORTANT: Always Use Your Own Background Sessions

**CRITICAL**: Always check and manage background processes in your own shell sessions.

1. **Check Existing Background Tasks First**
   - Always check if processes are already running in your background sessions
   - Use `BashOutput` to check status of any background processes (bash_1, bash_2, etc.)
   - If a process should be running but isn't in your sessions, kill external instances and restart in your shell

2. **Start All Long-Running Processes in Background**
   - Development servers: `npm run start:dev` with `run_in_background: true`
   - Database containers: `docker-compose up -d` 
   - Build watchers: `npm run watch` with `run_in_background: true`
   - Any process that needs to stay running throughout the session

3. **Monitor Background Processes**
   - Regularly check background process output with `BashOutput`
   - Watch for errors, crashes, or important logs
   - Keep track of all background process IDs (bash_1, bash_2, etc.)

4. **Process Ownership Rule**
   - ALWAYS assume processes should run through your shell going forward
   - If user mentions a service should be running, ensure it's in YOUR background sessions
   - Kill and restart any externally started processes to maintain control
   - This ensures you can monitor logs, catch errors, and manage lifecycle

5. **Common Background Tasks**
   - API servers (port 3000, 3001, etc.)
   - Frontend dev servers (port 5173, 3000, etc.)
   - Database containers (PostgreSQL, Redis, MongoDB)
   - Test watchers and build processes
   - Queue workers and schedulers

## Development Workflow

### Branch Management and Work Planning

When creating a plan for any development work, ALWAYS include these steps:

1. **Ensure Clean Working Directory**
   - Check git status to verify no uncommitted changes
   - Commit or stash any existing work before proceeding
   - Only start new work from a clean state

2. **Create Feature Branch**
   - Create a new branch from current branch (usually develop/main)
   - Use descriptive branch names (e.g., feature/user-authentication)
   - Never work directly on main/develop branches

### Git Commit Standards

**CRITICAL: NEVER use `--no-verify` flag**
- Git hooks are mandatory quality gates
- Always fix issues found by pre-commit hooks
- Never bypass validation with `--no-verify`
- If hooks fail, fix the underlying issues before committing

3. **Development Work**
   - Implement the planned features/fixes
   - Follow all coding standards and conventions
   - Write/update tests as you go

4. **Acceptance Criteria Checklist** (MUST complete ALL before considering work done)
   - [ ] All tests pass (`npm test`, `flutter test`, etc.)
   - [ ] Project builds successfully (`npm run build`, etc.)
   - [ ] No linting errors or warnings
   - [ ] Code reviewed and refactored if needed
   - [ ] Documentation updated if applicable
   - [ ] Commit with clear, descriptive message
   - [ ] Any related markdown docs are updated

5. **Commit Standards**
   - Write clear, descriptive commit messages
   - Follow conventional commit format if project uses it
   - Include ticket/issue numbers if applicable
   - **NEVER PUSH CODE** - Do not push to remote repositories until pipelines are properly configured

### Planning Requirements

Every development plan MUST explicitly include:

- Git status check and clean working directory step
- Branch creation step
- Testing verification step
- Build verification step
- Documentation update check
- Final commit with proper message
- **NO PUSH STEP** - Commits stay local only

## Code Change Protocol

### Direct Code Writing

**CRITICAL**: Write code directly using Edit/Write tools. Do not use cursor-agent or other external tools for code modifications.

- Use Edit/Write tools to make code changes directly
- Read/Glob/Grep tools are for exploration and understanding code
- Write clean, maintainable code following project patterns
- Make focused, atomic changes that are easy to review

**Workflow for Code Changes**:
1. Understand what needs to change (from requirements, issues, etc.)
2. Explore codebase using Read/Glob/Grep to understand context and existing patterns
3. Identify the files that need to be modified
4. Use Edit/Write tools to make the necessary changes
5. Verify changes meet requirements
6. Test changes if applicable
7. Commit changes

## Code Quality Standards

### Linting Configuration

- Never skip or ignore linting issues
- Use recommended configurations for each project type:
  - Node.js/TypeScript: ESLint with recommended rules
  - Flutter/Dart: Follow Dart analysis options with recommended rules
- Fix all linting issues before considering code complete
- Run linting as part of development workflow

### Testing Practices

- Write tests for all new features
- Ensure all tests pass before submitting code
- Follow TDD when appropriate
- Mock external dependencies appropriately
- Aim for meaningful test coverage, not just high percentages
- **Regression Test Mandate**: If you change something and ANY test is failing, you have created a regression. ALWAYS fix it, regardless of whether the test is related to your specific changes.

## General Best Practices

### Version Management

- Always verify you're using current versions of libraries/frameworks
- Don't rely on LLM training data for version information
- Check official documentation or package registries for latest versions
- Update dependencies regularly but thoughtfully

### Code Standards

- Write clean, readable, maintainable code
- Follow project-specific conventions
- Document complex logic
- Prefer clarity over cleverness
- Keep functions focused and single-purpose

### Daily Workflow

- Check documentation before starting new work
- Commit frequently with clear messages
- Test as you develop
- Document learnings for future reference
- Keep dependencies up to date

## Available Agents

### TDD Agents
- **tdd-red-phase** - Writes comprehensive failing tests before implementation (RED phase of TDD)
- **tdd-green-phase** - Implements production code to make failing tests pass (GREEN phase of TDD)  
- **tdd-refactor-specialist** - Improves code quality while maintaining passing tests (REFACTOR phase of TDD)
- **mutation-test-runner** - Evaluates test suite quality through mutation testing on changed files

### Code Quality Agents
- **lint-fixer** - Fixes all linting issues (ESLint, TypeScript, etc.) without disabling rules or using shortcuts
- **debug-log-cleaner** - Removes debug logging while preserving error logs and production-relevant logging
- **qa-gatekeeper** - Performs final quality assurance checks before marking work complete

### Development Support Agents
- **research-investigator** - Researches technical topics, investigates codebases, and finds best practices
- **playwright-browser-executor** - Handles browser automation, web scraping, and UI testing with Playwright

## Available Commands

### Specification Workflow Commands
- **/createSteering** - Generate project steering documents (product, structure, tech guidelines)
- **/createSpecReq** - Create requirements document for a feature specification
- **/createSpecDesign** - Generate design document from requirements
- **/createSpecTask** - Create implementation task list with TDD and quality gates
- **/startSpecTask** - Execute the next pending task from a specification
- **/describeSpec** - Display comprehensive guide for specification workflow
- **/reviewProject** - Gather project context and execute custom prompts

### Development Commands
- **/commit** - Create git commit with intelligent pre-commit hook resolution (never uses --no-verify)
- **/runApp** - Build and run mobile app on simulator/emulator with auto-detection
- NEVER ADD TIME ESTIMATES TO ANY PLAN EVER - IMPORTANT