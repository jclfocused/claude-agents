---
description: Create a new slash command in .claude/commands/
argument-hint: <command-name> [description]
---

You are about to create a new slash command.

## Command Details
$ARGUMENTS

## Slash Command Guidelines

### File Location
**Absolute path**: `/Users/justinclapperton/.claude/commands/`
**Project-relative**: `.claude/commands/`

### File Format
Slash commands are Markdown files with optional YAML frontmatter.

**Filename**: `command-name.md` (the filename becomes the command, e.g., `/command-name`)

### Structure Template

```markdown
---
description: Brief description of what this command does
argument-hint: <expected arguments> [optional args]
allowed-tools: Tool1, Tool2 (optional - restricts tools available)
model: haiku|sonnet|opus (optional - specific model)
disable-model-invocation: false (optional - prevent SlashCommand tool)
---

Your command prompt goes here.

Use $ARGUMENTS to capture all arguments passed to the command.
Use $1, $2, $3, etc. for individual positional arguments.

## Example Usage
Describe how users should invoke this command.

## Instructions
Provide clear instructions for what the command should do.
```

### Frontmatter Fields
- **description**: Shows in autocomplete and help
- **argument-hint**: Shows expected arguments in autocomplete
- **allowed-tools**: Comma-separated list of allowed tools (optional)
- **model**: Specific model to use (haiku/sonnet/opus) (optional)
- **disable-model-invocation**: Prevents SlashCommand tool from invoking this (optional)

### Argument Placeholders
- `$ARGUMENTS` - All arguments as a single string
- `$1`, `$2`, etc. - Individual positional arguments

## Your Task

Based on the command name and description provided:

1. Ask clarifying questions if needed:
   - What should the command do?
   - What arguments should it accept?
   - Should it invoke a specific agent?
   - Does it need tool restrictions?

2. Create the command file at `/Users/justinclapperton/.claude/commands/<command-name>.md`

3. Write clear, actionable prompt content

4. Include frontmatter with appropriate metadata

5. Show the user how to use the new command

Ready to create the command!
