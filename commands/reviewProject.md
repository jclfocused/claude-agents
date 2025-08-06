# Review Project Command

Gather comprehensive project context from steering documents and specifications, then execute a custom prompt with that context.

## Usage

```bash
/reviewProject <prompt>
```

## Arguments

1. **prompt** (required) - The question or task to execute after gathering context

## Command Overview

This command:

1. Collects all steering documents (product, structure, tech)
2. Lists all specifications with their current status
3. Provides file paths for easy navigation
4. Loads compact summaries into context
5. Executes your prompt with full project awareness

## Process

### 1. Context Gathering

The command collects:

#### Steering Documents
- `@.kiro/steering/product.md` - Domain model and user roles
- `@.kiro/steering/structure.md` - Architecture patterns
- `@.kiro/steering/tech.md` - Technology stack

#### Specifications
For each spec in `@.kiro/specs/`:
- Requirements summary with completion indicators
- Design overview with key decisions
- Task progress (pending/in-progress/complete counts)
- File paths for all documents

#### Project Structure
- Main directories and their purposes
- Key configuration files
- README content summary

### 2. Context Format

Provides information in this structure:

```markdown
## Project Context Summary

### Steering Documents
- **Product** (@.kiro/steering/product.md): [Key points about domain/users]
- **Structure** (@.kiro/steering/structure.md): [Architecture highlights]
- **Tech** (@.kiro/steering/tech.md): [Stack and key commands]

### Specifications
#### spec-name-1
- **Status**: 3/10 tasks complete, 1 in progress
- **Requirements** (@.kiro/specs/spec-name-1/requirements.md): [Summary]
- **Design** (@.kiro/specs/spec-name-1/design.md): [Key components]
- **Current Task**: Task #4 - [Task description]

#### spec-name-2
- **Status**: Not started (0/5 tasks)
- **Requirements**: [Summary]
- **Design**: [Key components]

### Project Structure
- `/app` - Vue web application
- `/android` - Native Android app
- `/backend` - Supabase configuration
[Additional relevant directories]

### Your Query
[Executes the provided prompt with all context loaded]
```

### 3. Smart Summarization

The command:
- Extracts key sections from long documents
- Identifies current work in progress
- Highlights important patterns and decisions
- Maintains file path references for navigation
- Focuses on actionable information

## Example Usage

```bash
# Review overall project status
/reviewProject "What features are currently implemented and what's next?"

# Analyze architecture decisions
/reviewProject "Are there any inconsistencies between the specs and steering docs?"

# Get implementation guidance
/reviewProject "How should I implement user notifications based on the current architecture?"

# Check specification completeness
/reviewProject "Which specifications are missing design documents?"

# Understand testing strategy
/reviewProject "What testing approaches are defined across all specs?"
```

## Use Cases

### Project Status Review
```bash
/reviewProject "Summarize project progress and identify blockers"
```
Gets overview of all specs, task progress, and potential issues.

### Architecture Analysis
```bash
/reviewProject "Analyze if all specs follow the patterns in structure.md"
```
Compares specifications against steering guidelines.

### Implementation Planning
```bash
/reviewProject "What's the best order to implement remaining features?"
```
Considers dependencies and current progress.

### Quality Assurance
```bash
/reviewProject "Are there any requirements without corresponding design elements?"
```
Identifies gaps in specification documents.

### New Developer Onboarding
```bash
/reviewProject "Explain the project architecture and current state"
```
Provides comprehensive overview for newcomers.

## Context Optimization

The command intelligently:
- **Summarizes Large Documents**: Extracts key points instead of full content
- **Highlights Active Work**: Shows in-progress tasks prominently
- **Groups Related Info**: Organizes by specification
- **Maintains References**: Includes file paths for deep dives
- **Filters Noise**: Excludes redundant or outdated information

## File Path References

All summaries include clickable paths:
```
@.kiro/steering/product.md:15-45        # User role definitions
@.kiro/specs/user-auth/tasks.md:23      # Current in-progress task
@.kiro/specs/payments/design.md:89-120  # API endpoint definitions
```

## Advanced Features

### Selective Context
Future enhancement could support:
```bash
/reviewProject --specs user-auth,payments "Compare authentication approaches"
/reviewProject --steering-only "Analyze if steering docs are consistent"
```

### Context Export
Could support saving context:
```bash
/reviewProject --export context.md "Generate project documentation"
```

## Output Behavior

1. **First**: Displays gathered context summary
2. **Then**: Executes your prompt with full awareness
3. **Finally**: Provides actionable response based on project state

## Related Commands

- `/createSteering` - Create or update steering documents
- `/describeSpec` - Show specification workflow guide
- `/createSpecReq` - Create feature requirements
- `/startSpecTask` - Execute implementation tasks

## Notes

- Works best when steering documents exist
- More useful with multiple specifications
- Context size managed to stay within limits
- Provides navigation aids with file paths
- Focuses on current state over history