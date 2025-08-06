# Create Steering Documents Command

Generate comprehensive steering documents for project guidance based on project analysis.

## Usage

```bash
/createSteering [project_path]
```

## Arguments

1. **project_path** (optional) - Path to the project directory. Defaults to current working directory.

## Command Overview

This command generates three essential steering documents:

1. **product.md** - Product guidelines and user role specifications
2. **structure.md** - Project structure and architecture rules  
3. **tech.md** - Technology stack and development guidelines

## Process

### 1. Project Analysis

The command will:
- Analyze project structure and subdirectories
- Read README.md and CLAUDE.md files
- Identify technology stack from configuration files
- Understand existing patterns and conventions
- Detect database schemas and migrations

### 2. Document Generation

Creates three steering documents in `.kiro/steering/`:

#### product.md
- Core domain model
- Entity relationships
- User role specifications with detailed actions
- UI patterns per role
- Feature implementation rules
- Workflow definitions
- Data validation requirements
- Notification patterns
- Development priorities

#### structure.md  
- Git repository structure rules
- Directory organization
- Architecture patterns
- Database schema management rules
- Type safety requirements
- Code organization patterns
- File naming standards
- Core data entities
- Development workflow rules
- Import path conventions

#### tech.md
- Core technology stack with versions
- Development rules and patterns
- Framework-specific guidelines
- Database operation procedures
- Type safety implementation
- Essential commands
- Environment setup
- Code organization standards

### 3. Update Strategy

If steering documents already exist:
- Analyzes current documents
- Preserves custom additions
- Updates technology versions
- Adds newly discovered patterns
- Maintains document structure
- Backs up existing files

## Document Structure

Each steering document includes:

```markdown
---
inclusion: always
---

# [Document Title]

## [Sections based on document type]
```

## Example Usage

```bash
# Create steering docs for current directory
/createSteering

# Create steering docs for specific project
/createSteering /Users/username/projects/my-app
```

## What This Command Does

1. **Comprehensive Analysis**
   - Scans all subdirectories
   - Reads configuration files (package.json, build.gradle, etc.)
   - Analyzes existing documentation
   - Identifies patterns in code structure
   - Detects database schemas

2. **Smart Generation**
   - Uses discovered information to create relevant content
   - Adapts to project type (web, mobile, backend)
   - Includes project-specific commands
   - References actual file paths and patterns

3. **Maintains Consistency**
   - Follows existing document patterns
   - Preserves custom content on updates
   - Uses consistent formatting
   - Includes frontmatter for AI inclusion

## Update Behavior

When run on existing steering documents:

1. **Preserves Custom Content**
   - Maintains manually added sections
   - Keeps project-specific rules
   - Preserves custom workflows

2. **Updates Dynamic Content**
   - Refreshes technology versions
   - Updates file paths if structure changed
   - Adds newly discovered patterns
   - Updates commands based on package.json

3. **Backup Creation**
   - Creates `.backup` files before updating
   - Allows rollback if needed
   - Timestamps backup files

## Key Features

- **Auto-Detection**: Automatically identifies project type and stack
- **Multi-Repository Support**: Handles projects with multiple git repos
- **Framework Awareness**: Adapts to Vue, React, Android, Flutter, etc.
- **Database Integration**: Includes database schema documentation
- **Command Discovery**: Finds and documents npm scripts, gradle tasks
- **Pattern Recognition**: Identifies and documents coding patterns

## Output Location

Documents are created in:
```
[project_path]/.kiro/steering/
├── product.md
├── structure.md
└── tech.md
```

## Related Commands

- `/createSpecReq` - Create requirements document for specific feature
- `/createSpecDesign` - Create design document based on requirements
- `/createSpecTask` - Create task implementation plan from design

## Notes

- Creates `.kiro/steering/` directory if it doesn't exist
- Analyzes up to 3 levels deep in directory structure
- Supports multiple frameworks in monorepo setups
- Includes both development and production considerations
- References environment variables and configuration needs