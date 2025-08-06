# Describe Specification Commands

Display a comprehensive guide for the specification workflow and all related commands.

## Usage

```bash
/describeSpec
```

## Command Overview

This command displays:

1. The complete specification workflow
2. Description of each spec-related command
3. How commands work together
4. Example workflows for common scenarios
5. Directory structure created by these commands

## What This Command Shows

### 1. Specification Workflow Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Steering Docs  │────▶│  Requirements    │────▶│     Design      │
│  (Foundation)   │     │  (What to Build) │     │  (How to Build) │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │                         │
         ▼                       ▼                         ▼
   /createSteering         /createSpecReq           /createSpecDesign
                                                          │
                                                          ▼
                                                  ┌─────────────────┐
                                                  │      Tasks      │
                                                  │  (Step by Step) │
                                                  └─────────────────┘
                                                          │
                                                          ▼
                                                    /createSpecTask
                                                          │
                                                          ▼
                                                    /startSpecTask
```

### 2. Command Descriptions

#### Foundation Commands

**`/createSteering [project_path]`**
- Creates or updates three steering documents
- `product.md` - Domain model, user roles, workflows
- `structure.md` - Architecture, file organization, patterns
- `tech.md` - Technology stack, commands, guidelines
- Analyzes project to generate relevant content

#### Specification Commands

**`/createSpecReq <spec_name> <description>`**
- Creates requirements document for a feature
- Generates user stories with acceptance criteria
- Uses WHEN/THEN format for testability
- References steering documents for context

**`/createSpecDesign <spec_name>`**
- Creates design document from requirements
- Includes architecture diagrams, data models
- Defines components and interfaces
- Maps requirements to technical solutions

**`/createSpecTask <spec_name>`**
- Creates detailed implementation tasks
- Breaks design into executable steps
- Includes commands, file paths, verification
- Tracks completion with [ ], [~], [x] states

**`/startSpecTask <spec_name> [--reset]`**
- Executes the next pending or in-progress task
- Updates task status automatically
- Shows progress and next steps
- Supports resuming interrupted work

### 3. Directory Structure Created

```
.kiro/
├── steering/                 # Project-wide guidance
│   ├── product.md           # Business domain & users
│   ├── structure.md         # Architecture & patterns
│   └── tech.md              # Technology & commands
│
└── specs/                   # Feature specifications
    └── [spec-name]/         # e.g., user-authentication
        ├── requirements.md  # What to build
        ├── design.md        # How to build it
        └── tasks.md         # Steps to implement
```

### 4. Common Workflows

#### Starting a New Project
```bash
1. /createSteering                    # Analyze project, create guidance
2. Review and customize steering docs # Add project-specific rules
```

#### Implementing a New Feature
```bash
1. /createSpecReq user-auth "User login system"  # Define requirements
2. /createSpecDesign user-auth                   # Create architecture
3. /createSpecTask user-auth                     # Generate tasks
4. /startSpecTask user-auth                      # Begin implementation
5. /startSpecTask user-auth                      # Continue next task
   ... repeat until all tasks complete
```

#### Updating an Existing Feature
```bash
1. /createSpecReq feature-name "Add new capability"  # Updates requirements
2. /createSpecDesign feature-name                    # Updates design
3. /createSpecTask feature-name                      # Adds new tasks
4. /startSpecTask feature-name                       # Starts new work
```

#### Resuming Interrupted Work
```bash
1. /startSpecTask feature-name        # Continues from [~] task
   OR
2. /startSpecTask feature-name --reset # Reset [~] to [ ] and start fresh
```

### 5. Key Concepts

#### Task States
- `[ ]` **Pending**: Not started yet
- `[~]` **In Progress**: Currently working on (only one at a time)
- `[x]` **Complete**: Finished successfully

#### Document Relationships
- **Steering → Requirements**: Provides context and constraints
- **Requirements → Design**: Each requirement addressed in design
- **Design → Tasks**: Each component becomes executable tasks
- **Tasks → Implementation**: Step-by-step execution

#### Update Behavior
- Commands intelligently update existing documents
- Preserve custom content and completed work
- Add new content based on changes
- Maintain document structure and formatting

### 6. Best Practices

1. **Start with Steering**: Always create steering docs first
2. **Complete Requirements**: Fully define before designing
3. **Review Design**: Ensure it addresses all requirements
4. **Execute Sequentially**: Complete tasks in order
5. **Commit Frequently**: Follow commit checkpoints in tasks

### 7. Tips and Tricks

- Run commands from project root (parent of .kiro)
- Use descriptive spec names (kebab-case recommended)
- Review generated content before proceeding
- Customize steering docs for project needs
- Keep tasks small and independently testable

## Example Output

When you run `/describeSpec`, it displays this guide showing:
- How all commands work together
- The complete workflow from idea to implementation
- Directory structure and file organization
- Common usage patterns and best practices

## Related Commands

- `/createSteering` - Create project steering documents
- `/createSpecReq` - Create feature requirements
- `/createSpecDesign` - Create technical design
- `/createSpecTask` - Create implementation tasks
- `/startSpecTask` - Execute next task

## Notes

This command provides a quick reference without modifying any files. It's useful for:
- Understanding the specification workflow
- Training new team members
- Refreshing memory on command usage
- Planning feature implementation strategy