# Jira Planning Workflow Plugin

MVP-focused feature planning and execution workflow for Jira. This plugin provides a complete workflow for planning features as Stories with flat Subtasks, creating issues, and orchestrating work.

## Requirements

### Environment Variables

This plugin requires Jira credentials. Set the following environment variables:

```bash
export JIRA_URL="https://your-domain.atlassian.net"
export JIRA_USERNAME="your-email@example.com"
export JIRA_API_TOKEN="your-jira-api-token"
```

You can create a Jira API token from: https://id.atlassian.com/manage-profile/security/api-tokens

### Docker

The MCP server runs via Docker. Ensure Docker is installed and running.

### MCP Server

The plugin includes an MCP server configuration that uses the `ghcr.io/sooperset/mcp-atlassian:latest` Docker image. This will be automatically set up when the plugin is installed.

## Commands

| Command | Description |
|---------|-------------|
| `/planFeature <description>` | Create a Jira Story with flat Subtasks for a new feature |
| `/work-on-feature <keywords>` | Orchestrate work on a Jira Story and its Subtasks |

## Agents

| Agent | Description |
|-------|-------------|
| `jira-mvp-story-creator` | Creates MVP-scoped Stories with flat Subtasks |
| `jira-story-context` | Queries Jira for Stories and their Subtasks |
| `execute-issue-jira` | Implements specific Jira Subtasks with MVP discipline |
| `jira-issue-creator` | Creates single well-researched issues |

## Workflow Overview

### Planning a Feature

1. Run `/planFeature <your feature description>`
2. Select a sprint (or backlog)
3. Team is auto-detected from sprint name
4. Parallel code explorers investigate your codebase
5. Answer clarifying questions about the feature
6. Jira Story + Subtasks are created

### Working on a Feature

1. Run `/work-on-feature <feature keywords>`
2. The orchestrator finds the parent Story
3. Optionally creates a feature branch
4. Works through Subtasks sequentially
5. Transitions issues to Done in Jira

## Key Differences from Linear Plugin

| Aspect | Linear | Jira |
|--------|--------|------|
| Structure | Nested sub-issues | Flat Subtasks only |
| Naming | Any naming | SLICE/REFACTOR/TEST prefixes |
| Custom Fields | Labels | Team + Sprint fields |
| Status | State names | Transition IDs |

## Flat Subtask Naming Convention

Since Jira Subtasks cannot be nested, use naming conventions:

- `SLICE 1: Main vertical slice` - A potential PR
- `SLICE 1.1: Sub-part of slice 1` - Part of that PR
- `SLICE 2: Next vertical slice` - Another potential PR
- `REFACTOR: Code cleanup` - Refactoring work
- `TEST: Testing task` - Testing work

## Custom Fields

The plugin uses these Jira custom fields:

| Field | ID | Purpose |
|-------|-----|---------|
| Team | `customfield_10001` | Team ownership (string) |
| Sprint | `customfield_10020` | Sprint assignment (ID) |
| Story Points | `customfield_10026` | Estimation (number) |

**Note**: Custom field IDs may differ in your Jira instance. Check your Jira admin settings if issues arise.

## Installation

**Run these slash commands inside Claude Code:**

1. **Add the marketplace:**
   ```
   /plugin marketplace add jclfocused/claude-agents
   ```

2. **Install the plugin:**
   ```
   /plugin install jira-planning-workflow
   ```

3. **Set your environment variables:**
   ```bash
   export JIRA_URL="https://your-domain.atlassian.net"
   export JIRA_USERNAME="your-email@example.com"
   export JIRA_API_TOKEN="your-jira-api-token"
   ```
   Get your API token from: https://id.atlassian.com/manage-profile/security/api-tokens

4. **Ensure Docker is running** (the MCP server runs in Docker)

## Skills

Skills are model-invoked capabilities that Claude uses autonomously based on context. Unlike slash commands (user-invoked), skills activate automatically when relevant.

| Skill | Description |
|-------|-------------|
| `mvp-scoping` | Guides MVP thinking during feature discussions - "what's the minimum to make this work?" |
| `jira-discipline` | Reminds about Jira issue tracking discipline - transitioning issues, marking done, creating Subtasks for missing scope |
| `issue-writing` | Ensures consistent, high-quality issue structure with clear acceptance criteria |
| `vertical-slice-planning` | Guides decomposition into vertical slices (end-to-end functionality) vs horizontal layers |
| `atomic-design-planning` | Guides UI component architecture using atoms, molecules, organisms methodology |

### When Skills Activate

- **mvp-scoping**: When discussing features, planning work, or scoping requirements
- **jira-discipline**: When starting/completing work, or discussing implementation without mentioning a Jira issue
- **issue-writing**: When drafting issues or defining acceptance criteria
- **vertical-slice-planning**: When breaking down features or discussing PR structure
- **atomic-design-planning**: When discussing UI components or frontend implementation

## Troubleshooting

### MCP Server Not Accessible

If you see "Jira MCP server is not accessible", verify:
1. Docker is running
2. Environment variables are set correctly
3. Your Jira API token is valid
4. Your Jira URL is correct (include https://)

### Custom Field Errors

If Subtasks aren't getting Team/Sprint:
1. Verify custom field IDs match your Jira instance
2. Use `mcp__mcp-atlassian__jira_search_fields` to find correct IDs
3. Update the agent files with your custom field IDs

### Sprint/Team Not Found

The plugin parses team name from sprint name (format: "[Team] - Sprint [N]").
If your sprint naming differs, you may need to adapt the parsing logic.
