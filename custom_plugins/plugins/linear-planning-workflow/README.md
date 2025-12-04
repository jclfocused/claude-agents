# Linear Planning Workflow Plugin

MVP-focused feature planning and execution workflow for Linear. This plugin provides a complete workflow for planning features, creating issues, updating plans, and orchestrating work through Linear sub-issues.

## Requirements

### Environment Variables

This plugin requires a Linear API key. Set the following environment variable:

```bash
export LINEAR_API_KEY="your-linear-api-key"
```

You can get a Linear API key from: https://linear.app/settings/api

### MCP Server

The plugin includes an MCP server configuration for Linear that will be automatically set up when the plugin is installed. The MCP server connects to Linear's hosted MCP endpoint at `https://mcp.linear.app/mcp`.

## Commands

| Command | Description |
|---------|-------------|
| `/planFeature <description>` | Create a Linear MVP parent issue with nested sub-issues for a new feature |
| `/work-on-feature <keywords>` | Orchestrate work on a Linear parent feature issue and its sub-issues |
| `/createIssue <description>` | Create a single Linear issue with codebase research and optional parent association |
| `/updatePlan <changes>` | Update an existing Linear parent feature issue and its sub-issues |
| `/fix-issues <bug description>` | Create Linear issues for reported bugs or problems |

## Agents

| Agent | Description |
|-------|-------------|
| `linear-mvp-project-creator` | Creates MVP-scoped parent issues with nested sub-issues |
| `linear-project-context` | Queries Linear for parent feature issues and their sub-issues |
| `linear-mvp-issue-updater` | Updates existing feature plans while preserving completed work |
| `linear-issue-creator` | Creates single well-researched issues |
| `execute-issue` | Implements specific Linear sub-issues with MVP discipline |
| `create-bug` | Creates bug issues with codebase investigation |

## Workflow Overview

### Planning a Feature

1. Run `/planFeature <your feature description>`
2. Select a project (or no project)
3. Parallel code explorers investigate your codebase
4. Answer clarifying questions about the feature
5. Linear parent issue + sub-issues are created

### Working on a Feature

1. Run `/work-on-feature <feature keywords>`
2. The orchestrator finds the parent issue
3. Creates/switches to a feature branch
4. Works through sub-issues sequentially
5. Marks issues as complete in Linear

### Creating Single Issues

1. Run `/createIssue <description>`
2. Optionally associate with a Feature Root parent
3. Codebase investigation runs
4. Well-structured issue is created

## Key Principles

- **MVP Focus**: Only implement what's needed to make features functional
- **Linear Discipline**: All work tracked through Linear issues
- **Patterns First**: Investigate codebase before implementing
- **Atomic Design**: For UI features, use/create atomic components
- **Feature Root Labels**: Parent issues are labeled "Feature Root" for filtering

## Installation

**Run these slash commands inside Claude Code:**

1. **Add the marketplace:**
   ```
   /plugin marketplace add jclfocused/claude-agents
   ```

2. **Install the plugin:**
   ```
   /plugin install linear-planning-workflow
   ```

3. **Set your environment variable:**
   ```bash
   export LINEAR_API_KEY="your-linear-api-key"
   ```
   Get your API key from: https://linear.app/settings/api

## Skills

Skills are model-invoked capabilities that Claude uses autonomously based on context. Unlike slash commands (user-invoked), skills activate automatically when relevant.

| Skill | Description |
|-------|-------------|
| `mvp-scoping` | Guides MVP thinking during feature discussions - "what's the minimum to make this work?" |
| `linear-discipline` | Reminds about Linear issue tracking discipline - having issues in progress, marking done, creating missing scope |
| `issue-writing` | Ensures consistent, high-quality issue structure with clear acceptance criteria |
| `vertical-slice-planning` | Guides decomposition into vertical slices (end-to-end functionality) vs horizontal layers |
| `atomic-design-planning` | Guides UI component architecture using atoms, molecules, organisms methodology |

### When Skills Activate

- **mvp-scoping**: When discussing features, planning work, or scoping requirements
- **linear-discipline**: When starting/completing work, or discussing implementation without mentioning a Linear issue
- **issue-writing**: When drafting issues or defining acceptance criteria
- **vertical-slice-planning**: When breaking down features or discussing PR structure
- **atomic-design-planning**: When discussing UI components or frontend implementation

## Troubleshooting

### MCP Server Not Accessible

If you see "Linear MCP server is not accessible", verify:
1. Your `LINEAR_API_KEY` is set and valid
2. You can reach `https://mcp.linear.app/mcp`
3. The plugin is properly installed

### Feature Root Label Missing

The `linear-mvp-project-creator` agent will automatically create the "Feature Root" label if it doesn't exist in your Linear workspace.

### Project Selection

When creating features, you'll be prompted to select a project. If you don't want project association, select "No Project Association".
