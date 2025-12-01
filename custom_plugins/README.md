# Custom Plugins Local Marketplace

This directory serves as a local plugin marketplace for custom Claude Code plugins.

## Directory Structure

```
custom_plugins/
├── marketplace.json          # Marketplace manifest (lists all plugins)
├── README.md                 # This file
└── plugins/                  # Individual plugins live here
    └── my-plugin/
        ├── .claude-plugin/
        │   └── plugin.json   # Plugin metadata (required)
        ├── commands/         # Slash commands (*.md files)
        ├── agents/           # Agent definitions (*.md files)
        ├── skills/           # Skills (*/SKILL.md)
        └── hooks/            # Event handlers (hooks.json)
```

## Adding This Marketplace to Claude Code

**Important**: These are slash commands run inside Claude Code, not CLI commands.

Register this local marketplace (run inside Claude Code from your home directory):

```
/plugin marketplace add ./custom_plugins
```

List registered marketplaces:
```
/plugin marketplace list
```

## Creating a New Plugin

### 1. Create Plugin Directory Structure

```bash
mkdir -p plugins/my-plugin/.claude-plugin
mkdir -p plugins/my-plugin/{commands,agents,skills,hooks}
```

### 2. Create plugin.json (Required)

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Description of what the plugin does"
}
```

### 3. Register in marketplace.json

Add entry to the `plugins` array:

```json
{
  "name": "my-plugin",
  "description": "Description of what the plugin does",
  "version": "1.0.0",
  "source": "./plugins/my-plugin"
}
```

### 4. Install the Plugin

Inside Claude Code:
```
/plugin install my-plugin
```

Or use the interactive menu:
```
/plugin
```
Then select "Browse Plugins".

## Plugin Components

### Commands (Slash Commands)

Create `commands/my-command.md`:

```markdown
---
description: Brief description of the command
allowed-tools: Tool1, Tool2
---

# My Command

Instructions for Claude when this command is invoked.

$ARGUMENTS contains any arguments passed to the command.
```

### Agents

Create `agents/my-agent.md`:

```markdown
---
name: my-agent
description: When/why to use this agent (shown in Task tool)
tools: Glob, Grep, Read, Write
model: sonnet
---

You are a specialized agent that...

## Instructions

1. Step one
2. Step two
```

### Skills

Create `skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
description: What this skill does and when Claude should use it
---

# My Skill

This skill guides Claude to...

## Guidelines

Detailed instructions for using this skill.
```

### Hooks

Create `hooks/hooks.json`:

```json
{
  "description": "What these hooks do",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/my_hook.py"
          }
        ]
      }
    ]
  }
}
```

## Testing Changes

After modifying a plugin, run inside Claude Code:

```
/plugin uninstall my-plugin
/plugin install my-plugin
```

## Available Hook Events

- `PreToolUse` - Before a tool executes
- `PostToolUse` - After a tool completes
- `Stop` - When Claude wants to stop
- `UserPromptSubmit` - When user submits a prompt
- `SubagentStop` - When a subagent wants to stop
- `SessionStart` - When session begins
- `SessionEnd` - When session ends
