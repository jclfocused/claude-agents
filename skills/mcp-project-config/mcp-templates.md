# MCP Configuration Templates

Copy-paste templates for MCP server configuration.

## Complete .mcp.json Template

```json
{
  "mcpServers": {
    "linear": {
      "type": "http",
      "url": "https://mcp.linear.app/mcp",
      "headers": {
        "Authorization": "Bearer ${LASER_FOCUSED_LINEAR_TOKEN}"
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

---

## Complete .claude/settings.json Template

```json
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["linear", "github", "chrome-devtools", "render"]
}
```

---

## Individual Server Templates

### Linear (HTTP)

```json
"linear": {
  "type": "http",
  "url": "https://mcp.linear.app/mcp",
  "headers": {
    "Authorization": "Bearer ${LINEAR_TOKEN_VAR}"
  }
}
```

**Token Variables:**
- `LASER_FOCUSED_LINEAR_TOKEN` - Laser Focused workspace
- `WHAT_IF_LINEAR_TOKEN` - What If workspace

**Get Token:** https://linear.app/settings/api

---

### GitHub (HTTP)

```json
"github": {
  "type": "http",
  "url": "https://api.githubcopilot.com/mcp",
  "headers": {
    "Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"
  }
}
```

**Token Variable:** `GITHUB_PERSONAL_ACCESS_TOKEN`

**Get Token:** https://github.com/settings/tokens

**Required Scopes:**
- `repo` - Full repository access
- `read:org` - Read organization membership

---

### Chrome DevTools (stdio)

```json
"chrome-devtools": {
  "command": "npx",
  "args": ["-y", "chrome-devtools-mcp@latest"]
}
```

**No token required** - runs locally.

---

### Render (HTTP)

```json
"render": {
  "type": "http",
  "url": "https://mcp.render.com/mcp",
  "headers": {
    "Authorization": "Bearer ${RENDER_TOKEN}"
  }
}
```

**Token Variable:** `RENDER_TOKEN`

**Get Token:** https://dashboard.render.com/account/api-keys

---

## Shell Profile Template

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# ===========================================
# MCP Server API Tokens
# ===========================================

# Linear API Tokens
# Get from: https://linear.app/settings/api
export LASER_FOCUSED_LINEAR_TOKEN="lin_api_XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export WHAT_IF_LINEAR_TOKEN="lin_api_XXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# GitHub Personal Access Token
# Get from: https://github.com/settings/tokens
# Scopes: repo, read:org
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Render API Token
# Get from: https://dashboard.render.com/account/api-keys
export RENDER_TOKEN="rnd_XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
```

After adding, reload:
```bash
source ~/.zshrc
```

---

## Verification Commands

Check tokens are set:

```bash
echo "Linear: ${LASER_FOCUSED_LINEAR_TOKEN:0:10}..."
echo "GitHub: ${GITHUB_PERSONAL_ACCESS_TOKEN:0:10}..."
echo "Render: ${RENDER_TOKEN:0:10}..."
```

---

## Alternative Linear Configurations

### What If Workspace

```json
"linear": {
  "type": "http",
  "url": "https://mcp.linear.app/mcp",
  "headers": {
    "Authorization": "Bearer ${WHAT_IF_LINEAR_TOKEN}"
  }
}
```

### Custom Workspace

```json
"linear": {
  "type": "http",
  "url": "https://mcp.linear.app/mcp",
  "headers": {
    "Authorization": "Bearer ${YOUR_WORKSPACE_LINEAR_TOKEN}"
  }
}
```

---

## Adding Additional Servers

### Playwright (Browser Automation)

```json
"playwright": {
  "command": "npx",
  "args": ["-y", "@anthropic-ai/mcp-server-playwright"]
}
```

### Postgres (Direct DB Access)

```json
"postgres": {
  "command": "npx",
  "args": ["-y", "@anthropic-ai/mcp-server-postgres", "${DATABASE_URL}"]
}
```

### Sentry (Error Tracking)

```json
"sentry": {
  "command": "npx",
  "args": ["-y", "@sentry/mcp-server"],
  "env": {
    "SENTRY_AUTH_TOKEN": "${SENTRY_AUTH_TOKEN}"
  }
}
```
