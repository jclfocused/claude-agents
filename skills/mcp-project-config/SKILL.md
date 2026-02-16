---
name: mcp-project-config
description: Configures MCP servers for projects. Use when setting up Linear, GitHub, Chrome DevTools, Render, or other MCP servers for a project. Handles token selection and configuration.
---

# MCP Project Configuration

Guide for configuring MCP (Model Context Protocol) servers in projects.

## Standard MCP Servers

Every project should include these MCP servers:

| Server | Type | Purpose |
|--------|------|---------|
| Linear | HTTP | Project/issue tracking |
| GitHub | HTTP | Code management |
| Chrome DevTools | stdio | Browser debugging |
| Render | HTTP | Deployment management |

## Configuration Files

### .mcp.json (Project Root)

MCP server definitions with environment variable substitution:

```json
{
  "mcpServers": {
    "linear": {
      "type": "http",
      "url": "https://mcp.linear.app/mcp",
      "headers": {
        "Authorization": "Bearer ${LINEAR_TOKEN_VAR}"
      }
    },
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp",
      "headers": {
        "Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"
      }
    },
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"]
    },
    "render": {
      "type": "http",
      "url": "https://mcp.render.com/mcp",
      "headers": {
        "Authorization": "Bearer ${RENDER_TOKEN}"
      }
    }
  }
}
```

### .claude/settings.json

Enable MCP servers for Claude Code:

```json
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["linear", "github", "chrome-devtools", "render"]
}
```

## Linear Account Selection

When setting up Linear, ask which account to use:

### Known Accounts

| Account | Token Variable |
|---------|---------------|
| Laser Focused | `LASER_FOCUSED_LINEAR_TOKEN` |
| What If | `WHAT_IF_LINEAR_TOKEN` |

### New Workspace

If neither account applies:
1. Ask user for the token environment variable name
2. User creates the token at https://linear.app/settings/api
3. User adds to their shell profile (~/.zshrc or ~/.bashrc)

### Configuration

Replace `LINEAR_TOKEN_VAR` in .mcp.json with the chosen variable:

```json
"linear": {
  "type": "http",
  "url": "https://mcp.linear.app/mcp",
  "headers": {
    "Authorization": "Bearer ${LASER_FOCUSED_LINEAR_TOKEN}"
  }
}
```

## Token Environment Setup

Tokens should be stored in the user's shell profile, NOT in project files.

### Where to Store Tokens

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# Linear API Tokens
export LASER_FOCUSED_LINEAR_TOKEN="lin_api_..."
export WHAT_IF_LINEAR_TOKEN="lin_api_..."

# GitHub Personal Access Token
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."

# Render API Token
export RENDER_TOKEN="rnd_..."
```

### Reload After Adding

```bash
source ~/.zshrc  # or ~/.bashrc
```

## MCP Server Types

### HTTP Servers

Use for hosted APIs with authentication:

```json
{
  "type": "http",
  "url": "https://api.service.com/mcp",
  "headers": {
    "Authorization": "Bearer ${TOKEN_VAR}"
  }
}
```

### stdio Servers (npx)

Use for local tools that run as processes:

```json
{
  "command": "npx",
  "args": ["-y", "package-name@latest"]
}
```

### stdio Servers (Local Binary)

Use for installed binaries:

```json
{
  "command": "/path/to/binary",
  "args": ["--flag", "value"]
}
```

## Setup Workflow

### Step 1: Create .mcp.json

```bash
# In project root
touch .mcp.json
```

### Step 2: Ask About Linear Account

"Which Linear workspace is this project for?"
- Laser Focused (LASER_FOCUSED_LINEAR_TOKEN)
- What If (WHAT_IF_LINEAR_TOKEN)
- New workspace (provide token name)

### Step 3: Configure All Servers

See [mcp-templates.md](mcp-templates.md) for full templates.

### Step 4: Create .claude/settings.json

```bash
mkdir -p .claude
```

Add settings to enable MCP servers.

### Step 5: Verify

Start a new Claude Code session and verify MCP tools are available.

## Adding Custom MCP Servers

To add a new MCP server:

1. Determine the server type (HTTP or stdio)
2. Get the URL or command
3. Identify required authentication
4. Add to .mcp.json
5. Add server name to enabledMcpjsonServers in settings.json

## Troubleshooting

### MCP Server Not Available

1. Check token is exported: `echo $TOKEN_NAME`
2. Verify .mcp.json syntax (valid JSON)
3. Check server is listed in settings.json
4. Restart Claude Code session

### Authentication Failed

1. Verify token is valid (not expired)
2. Check token has required permissions
3. Ensure environment variable is set

### HTTP Server Connection Failed

1. Check URL is correct
2. Verify network connectivity
3. Check if service is operational

For templates, see [mcp-templates.md](mcp-templates.md).
