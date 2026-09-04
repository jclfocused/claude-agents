---
name: mcp-project-config
description: Configures MCP servers for projects. Use when setting up Linear, a browser driver, or other MCP servers for a project, adding a .mcp.json, or when the user asks to "set up MCP", "add an MCP server", or "configure MCP for this project". Handles token selection and configuration.
---

# MCP Project Configuration

Guide for configuring MCP (Model Context Protocol) servers in projects.

## Standard MCP Servers

**Provided by installed plugins — do NOT add per-project `.mcp.json` entries for these:**

| Server | Source | Notes |
|--------|--------|-------|
| GitHub | `github` plugin | Prefer `gh` CLI for most operations anyway |
| Slack | `slack` plugin | |
| Sentry | `sentry` plugin | |
| context7 | `context7` plugin | Library docs lookup |
| betterwright | user-scoped MCP (`betterwright mcp`) | **The browser driver on this box** — do NOT add `chrome-devtools` or `playwright` per project. See the `betterwright` / `browser` skills. |

They are available in every session already; a project entry only duplicates them. Only add one to `.mcp.json` if a project genuinely needs a different auth/host than the plugin provides.

**Configure per-project when needed:**

| Server | Type | Purpose |
|--------|------|---------|
| Linear | HTTP | Project/issue tracking (workspace-specific token — see below) |
| Project-specific servers | varies | Anything unique to the project (Postgres, custom stdio servers) |

Render is no longer a default — add it only if the project actually deploys on Render.

## Configuration Files

### .mcp.json (Project Root)

```json
{
  "mcpServers": {
    "linear": {
      "type": "http",
      "url": "https://mcp.linear.app/mcp",
      "headers": {
        "Authorization": "Bearer ${LINEAR_TOKEN_VAR}"
      }
    }
  }
}
```

### .claude/settings.json

```json
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["linear"]
}
```

## Linear Account Selection

When setting up Linear, ask which account to use:

| Account | Token Variable |
|---------|---------------|
| Laser Focused | `LASER_FOCUSED_LINEAR_TOKEN` |
| What If | `WHAT_IF_LINEAR_TOKEN` |

If neither applies (new workspace):
1. Ask the user for the token environment variable name
2. User creates the token at https://linear.app/settings/api
3. User adds it to their shell profile (~/.zshrc or ~/.bashrc)

Replace `LINEAR_TOKEN_VAR` in `.mcp.json` with the chosen variable.

## Token Environment Setup

Tokens live in the user's shell profile (`~/.zshrc` or `~/.bashrc`), NOT in project files:

```bash
# Linear API Tokens
export LASER_FOCUSED_LINEAR_TOKEN="lin_api_..."
export WHAT_IF_LINEAR_TOKEN="lin_api_..."
```

Reload after adding: `source ~/.zshrc`

## MCP Server Types

HTTP (hosted API with auth):
```json
{ "type": "http", "url": "https://api.service.com/mcp", "headers": { "Authorization": "Bearer ${TOKEN_VAR}" } }
```

stdio via npx (local tool):
```json
{ "command": "npx", "args": ["-y", "package-name@latest"] }
```

stdio via local binary:
```json
{ "command": "/path/to/binary", "args": ["--flag", "value"] }
```

## Setup Workflow

1. Check what the project actually needs — skip anything already covered globally (GitHub, Slack, Sentry, context7 plugins; betterwright for anything browser).
2. Create `.mcp.json` in the project root with only the needed servers.
3. If Linear: ask which workspace → pick the token variable.
4. Create `.claude/settings.json` with `enabledMcpjsonServers` listing each server.
5. Verify: start a new Claude Code session and confirm the MCP tools appear.

For copy-paste templates (Linear, Postgres, Render-if-needed), see [mcp-templates.md](mcp-templates.md).

## Troubleshooting

- **Server not available:** check the token is exported — presence only, never print the value: `[ -n "$TOKEN_NAME" ] && echo set` (secrets-intake iron rule) — then check `.mcp.json` is valid JSON, the server is listed in settings.json, and restart the session.
- **Auth failed:** token expired, missing permissions, or env var not set in the shell that launched Claude Code.
- **Duplicate tools:** a project `.mcp.json` entry shadows a plugin-provided server — remove the project entry.

## Observability (required)

The observability MCPs, as a standard block. Read `observability-triage` for how they are used.
**Proven working 2026-09-04** (every server handshaked + a live tool call) — copy verbatim; the only
per-project edits are the Grafana URL/port and the Sentry `--organization-slug`. Canonical copy:
`/home/justin/code/coworking-mng-not-shit/.mcp.json`.

Every server is **stdio**, and every one sources its own `0600` file under `~/.config` inside
`bash -lc`. That is deliberate: no secret reaches the repo, and no `export` has to exist in the
shell that launched Claude Code (a `${VAR}` in `.mcp.json` silently resolves to empty otherwise).

```jsonc
// .mcp.json — no secrets; each entry sources ~/.config/*.env itself
{
  "mcpServers": {
    "sentry": { "command": "bash", "args": ["-lc",
      "set -a; . ~/.config/sentry.env; set +a; export SENTRY_ACCESS_TOKEN=\"$SENTRY_AUTH_TOKEN\"; exec npx -y @sentry/mcp-server@latest --host=de.sentry.io --organization-slug=laserfocused --disable-skills=project-management"] },
    "posthog": { "command": "bash", "args": ["-lc",
      "set -a; . ~/.config/posthog.env; set +a; exec npx -y mcp-remote@latest 'https://mcp.posthog.com/mcp?mode=cli' --transport http-only --header \"Authorization:Bearer ${POSTHOG_PERSONAL_API_KEY}\""] },
    "grafana-platform": { "command": "bash", "args": ["-lc",
      "set -a; . ~/.config/observability/grafana-mcp.env; set +a; exec ~/.local/bin/mcp-grafana -t stdio --disable-write --enabled-tools loki,dashboard,alerting,datasource --max-loki-log-limit 50 --loki-guardrail-mode enforce"] }
  }
}
```

`.claude/settings.json` needs `"enableAllProjectMcpServers": false` plus an explicit
`"enabledMcpjsonServers": [...]` — opt in by name, never blanket-enable.

Facts that cost a lane to find, so don't re-derive them:
- **`https://mcp.sentry.dev/mcp` does NOT accept our `sntryu_` auth token** — it is OAuth-only
  (`401 invalid_token`, `WWW-Authenticate: Bearer realm="OAuth"`), which no headless session can
  complete. The stdio `@sentry/mcp-server` with `SENTRY_ACCESS_TOKEN` is the working path.
  `~/.config/sentry.env` names the var `SENTRY_AUTH_TOKEN`, hence the re-export.
- **The org is EU** → `--host=de.sentry.io`. `us.sentry.io` 404s.
- **`--organization-slug` really scopes it**: with the flag the server exposes 8 tools, without it 9
  (`find_organizations` disappears). `--disable-skills=project-management` drops project/team/DSN
  creation; `inspect,seer,docs,triage` remain.
- **PostHog `?mode=cli` collapses the whole server to ONE tool, `exec`** — a natural-language/
  resource-verb dispatcher. That is the context-cheap mode and the one to use. `mcp-remote` is only
  a stdio↔HTTP bridge; `--transport http-only` skips its SSE probe.
- **`uvx mcp-grafana` does not exist** — it is a Go binary. Install the release tarball:
  `curl -sSL .../grafana/mcp-grafana/releases/download/v1.3.0/mcp-grafana_Linux_x86_64.tar.gz | tar xz -C ~/.local/bin mcp-grafana`.
  The tool group is `datasource`, singular.

Guardrails, not optional:
- **Grafana: `--disable-write` AND a Viewer service account.** Two layers — the flag hides write
  tools, the token makes a write 403 at the API even if a tool slips through (verified: `POST
  /api/folders` → 403, `GET /api/datasources` → 200). Mint it with
  `POST /api/serviceaccounts {"name":"mcp-readonly","role":"Viewer"}` as admin, store it in
  `~/.config/observability/grafana-mcp.env` — **never reuse `grafana.env`'s Editor push token**,
  which belongs to `push.sh`. `--max-loki-log-limit 50 --loki-guardrail-mode enforce` is the
  context defence: it caps a log pull at 50 lines and rejects an unbounded query outright.
- **PostHog: a personal API key.** Never let an agent create or rename events — event names are
  irreversible. Prefer a project-scoped key when the API grows one.
- **Sentry: read-mostly.** `update_issue` exists and resolve-in-next-release is inside the autonomy
  boundary; anything that deploys or changes sampling is not.
- Keys live in `~/.config/sentry.env`, `~/.config/posthog.env`,
  `~/.config/observability/grafana-mcp.env` and are referenced by NAME (`secrets-intake`) — never
  echoed, never committed.
- **Every one of these runs in a subagent lane and returns a compact brief** (`context-hygiene`).
