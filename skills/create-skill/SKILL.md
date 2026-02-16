---
name: create-skill
description: Create a new Claude Code skill from scratch. Use when the user asks to "create a skill", "make a skill", "new skill", "build a skill", "/create-skill", or says something like "create a skill for that" referencing something in the conversation.
disable-model-invocation: true
argument-hint: "[optional description or context]"
---

# Create a New Claude Code Skill

## What You Are Doing

You are helping the user create a **Claude Code Skill** - a reusable markdown file (`SKILL.md`) that teaches Claude how to do something specific. Skills live in `.claude/skills/<name>/` (project) or `~/.claude/skills/<name>/` (global) and are invoked either manually via `/slash-command` or automatically when Claude detects a matching task from the skill's description.

## Why Skills Matter

- **Consistency** - Encode team conventions, workflows, and patterns so Claude follows them every time
- **Reusability** - Write instructions once, use across sessions and projects
- **Composability** - Skills can reference supporting files, preload into agents, and chain with other tools
- **Discoverability** - Good descriptions let Claude auto-invoke skills when relevant, no slash command needed

## CRITICAL: Always Fetch Latest Docs

Skill structure, frontmatter fields, and best practices can change. **Before creating any skill, you MUST use the `claude-code-guide` subagent type (via the Task tool) to look up the current documentation on Claude Code skills.** Specifically research:

- Current YAML frontmatter fields and their valid values
- File structure requirements (SKILL.md, supporting files)
- Description best practices for triggering
- Any new features or fields that may have been added

Do this EVERY time, even if you think you know the answer. Docs are the source of truth.

Example Task tool call:
```
Task(subagent_type="claude-code-guide", prompt="Look up the current Claude Code documentation for skills. I need: all available YAML frontmatter fields, file structure requirements, description best practices, and any recent changes or new features.")
```

## Context Awareness

This skill can be invoked at any point in a conversation. **Always check the surrounding conversation context.** The user might say things like:

- "/create-skill for that" - referring to something just discussed
- "/create-skill for the workflow we just talked about"
- "/create-skill" with no arguments but obvious context from the conversation
- "/create-skill auth-validator" with a name but you need to infer purpose from context

Look at what was just discussed, what files were read, what problems were solved, and what patterns emerged. Use that context to inform the skill you create.

If `$ARGUMENTS` is provided, use it. If not, infer from conversation context. If still unclear, ask.

## Process

### Step 1: Fetch Latest Documentation

Use the Task tool with `subagent_type: "claude-code-guide"` to fetch the latest skill documentation. Do NOT skip this step.

### Step 2: Understand What the User Wants

Before creating anything, figure out:

1. **What should this skill do?** - Check `$ARGUMENTS` and conversation context
2. **Who is it for?** - Personal use or shared with a team?
3. **How should it trigger?** - Manual only (`/command`), auto-invoked by Claude, or both?

### Step 3: Ask Clarifying Questions

Use `AskUserQuestion` to ask the user any questions you need answered before creating. Only ask questions where the answer isn't obvious from context. Common questions include:

- **Scope**: Should this be global (`~/.claude/skills/`) or project-level (`.claude/skills/`)?
- **Invocation**: Should Claude auto-invoke this, or manual `/command` only?
- **Name**: What should the skill be called? (suggest one based on context)
- **Behavior**: Any specific behavior, tools, or constraints?

Do NOT ask questions you can answer from context. If the user said "create a skill for reviewing PRs" you don't need to ask "what should the skill do?"

### Step 4: Create the Skill

Based on the docs you fetched and the user's answers:

1. Create the directory: `~/.claude/skills/<name>/` or `.claude/skills/<name>/`
2. Write `SKILL.md` with proper YAML frontmatter and clear instructions
3. Add supporting files if the skill is complex (reference.md, examples.md, etc.)
4. Validate the structure matches current doc requirements

### Step 5: Confirm and Test

Tell the user:
- Where the skill was created
- How to invoke it (slash command name and/or auto-trigger description)
- Suggest they test it with a sample prompt

## Quality Standards

- Keep `SKILL.md` under 500 lines - use supporting files for detailed content
- Description must include specific trigger keywords users would naturally say
- Include at least one concrete example in the skill content
- Directory name must match the `name` field in frontmatter
- File must be exactly `SKILL.md` (case-sensitive)
