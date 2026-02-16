---
name: create-agent
description: Create a new Claude Code custom agent (subagent). Use when the user asks to "create an agent", "make an agent", "new agent", "build an agent", "create a subagent", "/create-agent", or says something like "create an agent for that" referencing something in the conversation.
disable-model-invocation: true
argument-hint: "[optional description or context]"
---

# Create a New Claude Code Agent (Subagent)

## What You Are Doing

You are helping the user create a **Claude Code Custom Agent** - a markdown file with YAML frontmatter that defines a specialized AI assistant running in an isolated context. Agents live in `.claude/agents/<name>.md` (project) or `~/.claude/agents/<name>.md` (global) and are spawned via the Task tool when Claude detects a matching task or when explicitly requested.

## Why Agents Matter

- **Specialization** - Agents focus on one job (reviewing, testing, debugging) and do it well
- **Isolation** - They run in their own context window, keeping the main conversation clean
- **Safety** - Tool restrictions and permission modes limit what an agent can do
- **Parallelism** - Multiple agents can work simultaneously on independent tasks
- **Memory** - Agents can learn across sessions with persistent memory

## CRITICAL: Always Fetch Latest Docs

Agent structure, frontmatter fields, and capabilities can change. **Before creating any agent, you MUST use the `claude-code-guide` subagent type (via the Task tool) to look up the current documentation on Claude Code custom agents / subagents.** Specifically research:

- Current YAML frontmatter fields and their valid values
- Available tools and how to restrict them
- Permission modes and their behavior
- Memory scopes and configuration
- Hook support within agents
- Any new features or fields that may have been added

Do this EVERY time, even if you think you know the answer. Docs are the source of truth.

Example Task tool call:
```
Task(subagent_type="claude-code-guide", prompt="Look up the current Claude Code documentation for custom agents (subagents). I need: all available YAML frontmatter fields, tool restriction options, permission modes, memory configuration, hooks support, and any recent changes or new features.")
```

## Context Awareness

This skill can be invoked at any point in a conversation. **Always check the surrounding conversation context.** The user might say things like:

- "/create-agent for that" - referring to something just discussed
- "/create-agent for the review process we talked about"
- "/create-agent" with no arguments but obvious context from the conversation
- "/create-agent db-reader" with a name but you need to infer purpose from context

Look at what was just discussed, what files were read, what problems were solved, and what patterns emerged. Use that context to inform the agent you create.

If `$ARGUMENTS` is provided, use it. If not, infer from conversation context. If still unclear, ask.

## Process

### Step 1: Fetch Latest Documentation

Use the Task tool with `subagent_type: "claude-code-guide"` to fetch the latest agent/subagent documentation. Do NOT skip this step.

### Step 2: Understand What the User Wants

Before creating anything, figure out:

1. **What should this agent do?** - Check `$ARGUMENTS` and conversation context
2. **What tools does it need?** - Read-only? Write access? Bash? MCP tools?
3. **How autonomous should it be?** - Permission mode matters

### Step 3: Ask Clarifying Questions

Use `AskUserQuestion` to ask the user any questions you need answered before creating. Only ask questions where the answer isn't obvious from context. Common questions include:

- **Scope**: Should this be global (`~/.claude/agents/`) or project-level (`.claude/agents/`)?
- **Tools**: What tools should the agent have access to? (Read-only vs full access)
- **Name**: What should the agent be called? (suggest one based on context)
- **Permissions**: Should the agent auto-accept edits, require approval, or be read-only?
- **Model**: Should it use a specific model (haiku for speed, opus for power) or inherit?
- **Memory**: Should it learn across sessions?

Do NOT ask questions you can answer from context. If the user said "create an agent that reviews code" you don't need to ask "what should the agent do?"

### Step 4: Create the Agent

Based on the docs you fetched and the user's answers:

1. Write the agent file: `~/.claude/agents/<name>.md` or `.claude/agents/<name>.md`
2. Include proper YAML frontmatter with name, description, tools, and any other relevant fields
3. Write a clear, focused system prompt in the markdown body
4. The system prompt should tell the agent exactly what it does, how to approach tasks, and what to output

### Step 5: Confirm and Test

Tell the user:
- Where the agent was created
- How it will be triggered (description matching or explicit request)
- What tools it has access to
- Suggest they test it with a sample task

## Quality Standards

- Each agent should excel at ONE focused job
- Description must clearly state when Claude should delegate to this agent
- Tool access should be minimal - only grant what's needed
- System prompt should be specific and actionable, not vague
- Include a clear workflow or checklist in the system prompt
- File is a single `.md` file (not a directory with SKILL.md like skills)
- Name field should be lowercase with hyphens
