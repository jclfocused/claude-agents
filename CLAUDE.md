# Global Development Standards

## Node.js Development

### Version Requirements

- Always use Node.js 22
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