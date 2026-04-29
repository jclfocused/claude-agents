---
name: 1password
description: Use when needing to fetch, read, store, or manage secrets and credentials. Triggers on "get secret", "fetch password", "store credential", "1password", "op read", "vault", or when a task requires API keys, tokens, or passwords that might be in 1Password.
allowed-tools: Bash
---

# Secret & Credential Management

## 🚫 SCOPE — READ THIS FIRST 🚫

**1Password (`op` CLI) is STRICTLY for Claude Code's use during coding.** It is for fetching a secret value you need **right now, in this session**, to inject into a config file, paste into a dashboard, run a one-off curl, call an API during investigation, or similar **development-time** work.

**NEVER write `op read` / `op item get` into code or scripts that will be run later by:**
- A user (operator shell)
- CI/CD pipelines (GitHub Actions, etc.)
- Production services
- Other automated systems
- A cron job

**Why:** production scripts must receive secrets via environment variables injected by the caller (operator, CI, secret manager sidecar). Baking `op` calls into a script creates a brittle dependency on a specific developer's laptop + biometric auth, leaks the choice of secret store into every user of the script, and silently breaks in any environment where `op` isn't signed in.

**Correct pattern for scripts that need secrets:**
```bash
# In the script — require env vars, never fetch
if [[ -z "${API_KEY:-}" ]]; then
  echo "Error: API_KEY not set. Export it before running." >&2
  exit 1
fi
curl -H "Authorization: Bearer $API_KEY" ...

# Operator invokes manually (pulls from 1Password once, in their shell):
export API_KEY=$(op read "op://Vault/Item/field" --account my.1password.eu)
./scripts/do-thing.sh

# Or in CI/CD:
# - GitHub Actions secrets → job env
# - Set once via `gh secret set API_KEY`
```

**If you catch yourself writing `op read` inside a `.sh` file, STOP.** Change it to read from an env var and document in the script header that the caller must set the var.

---

## Lookup Priority

**Always try sources in this order — only escalate to the next if the previous doesn't have what you need:**

1. **Project `.env` files** — most project secrets live here (API keys, Supabase keys, database URLs)
2. **CLI tools** — use the service's own CLI when available (e.g., `npx supabase` for Supabase credentials)
3. **Shell environment / `.zshrc`** — tokens exported globally (e.g., `$GITHUB_PERSONAL_ACCESS_TOKEN`)
4. **1Password (`op` CLI)** — last resort, only for secrets that don't exist in `.env` or `.zshrc`

### Project .env Files

```bash
# Read directly — no biometric prompt needed
grep SUPABASE_SERVICE_ROLE_KEY backend/.env
```

### Supabase Credentials (Preferred Method)

```bash
# Local Supabase — use the CLI, never 1Password
npx supabase status         # Shows all URLs, keys, connection strings
npx supabase status -o env  # Machine-readable key=value format
```

### Shell Environment

```bash
# Tokens already exported in .zshrc
echo $GITHUB_PERSONAL_ACCESS_TOKEN
echo $RENDER_TOKEN
```

## 1Password (Last Resort)

Only use `op` for secrets that live exclusively in 1Password and aren't available via `.env`, CLI tools, or shell environment. Examples: Apple ASC credentials, tokens not exported anywhere else.

### Vaults

| Vault | Account | Contents |
|-------|---------|----------|
| **What-If** | my.1password.eu | Linear, Cloudflare, Supabase, Grafana, Render, Sentry, Codacy, Chatbot, Admin |
| **Hyperglot** | my.1password.eu | Apple/ASC, Supabase, Google |
| **Dev Tools** | my.1password.eu | GitHub, Claude Code, Gemini, Jira, Postman, Google Stitch, 21st Dev |

### Fetch a Secret

```bash
# Single field from an item
op read "op://What-If/Linear/WHATIF_LINEAR_TOKEN" --account my.1password.eu

# All fields from an item
op item get "Linear" --vault "What-If" --account my.1password.eu

# List items in a vault
op item list --vault "What-If" --account my.1password.eu
```

### Store a New Secret

```bash
# Add to existing item
op item edit "Linear" --vault "What-If" --account my.1password.eu "NEW_FIELD[password]=secret_value"

# Create new item
op item create --category="API Credential" --title="Service Name" --vault="What-If" --account my.1password.eu "FIELD_NAME[password]=secret_value"
```

### Inject Into Environment

```bash
# Single export
export WHATIF_LINEAR_TOKEN=$(op read "op://What-If/Linear/WHATIF_LINEAR_TOKEN" --account my.1password.eu)

# Run command with injected secrets
op run --env-file=.env.tpl -- python script.py
```

### Multi-Account Access

The CLI can access both accounts — always pass `--account`:
- `my.1password.eu` — personal vaults (What-If, Hyperglot, Dev Tools)
- `whatifspaces.1password.eu` — team vaults (Employee, Shared)

### Caching Fetched Secrets — REQUIRED PATTERN

**Every `op read` / `op item get` triggers a biometric prompt (Touch ID).** Each Claude Code Bash tool call runs in a **brand new shell session** — shell variables DO NOT persist between Bash calls. So `MY_KEY=$(op read ...)` in one call is GONE in the next.

**You MUST use this pattern from now on for any secret you'll need more than once:**

**Step 1 (first call only) — write secret to a chmod-600 temp file:**
```bash
umask 077 && op read "op://Vault/Item/field" --account my.1password.eu > /tmp/.my_secret && chmod 600 /tmp/.my_secret
```

For multiple secrets from one item, write `export` lines:
```bash
umask 077 && op item get "Cloudflare" --vault What-If --account my.1password.eu --format json \
  | python3 -c "
import json, sys
item = json.load(sys.stdin)
fields = {f.get('label'): f.get('value') for f in item.get('fields', []) if f.get('label')}
print(f'export CF_TOKEN={fields[\"CLOUDFLARE_API_TOKEN\"]}')
print(f'export CF_ACCOUNT={fields[\"CLOUDFLARE_ACCOUNT_ID\"]}')
" > /tmp/.cf_creds && chmod 600 /tmp/.cf_creds
```

**Step 2 (every subsequent call) — source the file, NEVER re-call op:**
```bash
source /tmp/.cf_creds && curl -H "Authorization: Bearer $CF_TOKEN" "https://api.cloudflare.com/..."
```

**Step 3 (end of work) — clean up:**
```bash
rm -f /tmp/.cf_creds /tmp/.my_secret
```

**ANTI-PATTERNS — never do these:**
```bash
# ❌ BAD — biometric prompt in every call
curl -H "Bearer $(op read '...' --account my.1password.eu)" ...
curl -H "Bearer $(op read '...' --account my.1password.eu)" ...

# ❌ BAD — variables don't survive across Bash tool calls
# Call 1:
TOKEN=$(op read "..." --account my.1password.eu) && curl -H "Bearer $TOKEN" ...
# Call 2:
curl -H "Bearer $TOKEN" ...   # $TOKEN is undefined here, will fail or send empty
```

**Acceptable shortcut — single Bash call with everything:**
If ALL your work fits in one bash invocation, you can fetch and reuse without temp files:
```bash
KEY=$(op read "..." --account my.1password.eu) && \
  curl ... -H "Authorization: Bearer $KEY" && \
  curl ... -H "Authorization: Bearer $KEY"
```
But the moment you need a follow-up Bash call, switch to the temp-file pattern.

## Important Notes

- **Prefer `.env` and CLI tools over 1Password** — faster, no biometric prompt
- **Always use `--account` flag** with `op` — multiple accounts require explicit selection
- **Always cache fetched secrets** — `op` requires biometric auth on every call; fetch once and store in a shell variable
- **Never print secrets to stdout** unless the user explicitly asks
