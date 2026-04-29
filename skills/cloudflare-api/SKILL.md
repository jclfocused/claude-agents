---
name: cloudflare-api
description: Manage Cloudflare via API — DNS records, tunnels, Pages, zones. This skill should be used when creating or updating DNS records, managing Cloudflare tunnels, deploying to Cloudflare Pages, listing zones, or any Cloudflare API interaction. Triggers on "cloudflare", "DNS record", "tunnel", "cloudflare pages", "CNAME", "zone".
---

# Cloudflare API Management

Manage Cloudflare resources via the REST API. Covers DNS records, tunnels, Pages, and zones.

## Authentication

**Account API Token** (for account-level resources like tunnels):
```bash
# Stored in ~/.zshrc
export LASERFOCUSED_CLOUDFLARE_TOKEN="cfat_..."
```

Token verification uses the **account endpoint** (not user endpoint):
```bash
curl -s "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/tokens/verify" \
  -H "Authorization: Bearer ${LASERFOCUSED_CLOUDFLARE_TOKEN}"
```

**Token prefixes:**
- `cfat_` — Account API token (tunnels, pages, account-level)
- `cfut_` — User API token (cross-account, user-level)

## Account & Zone IDs

```
Account ID: e9adf716c7d13735e158a045298fe26f
Account Name: Justin@laserfocused.ee's Account

Zones:
  hyperglot.io  → c7ef50fc3fe392cd08cc61ba3a2c7bf9
  franklin.ee   → a8e4bf6b02771e2eca0135b1e4ef0540
  frnkln.ai     → c430681e325613d3b66a5c980edb39ef
```

## API Base URL

All endpoints: `https://api.cloudflare.com/client/v4/`

Always include: `-H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json"`

## DNS Records

### List records
```bash
curl -s "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}"
```

Filter: `?type=CNAME&name=api.example.com`

### Create record
```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CNAME",
    "name": "api",
    "content": "target.example.com",
    "proxied": true
  }'
```

### Update record
```bash
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"content": "new-target.example.com"}'
```

### Delete record
```bash
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}"
```

## Cloudflare Tunnels

### Create tunnel
```bash
TUNNEL_SECRET=$(openssl rand -base64 32)
curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{\"name\":\"my-tunnel\",\"tunnel_secret\":\"${TUNNEL_SECRET}\"}"
```

Response includes `result.id` (tunnel ID) and `result.token` (tunnel token for k8s).

### Configure tunnel ingress
```bash
curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "config": {
      "ingress": [
        {"hostname": "api.example.com", "service": "http://my-service:3001"},
        {"service": "http_status:404"}
      ]
    }
  }'
```

The last ingress rule must be a catch-all (no hostname).

### After creating tunnel
1. Add CNAME: `api.example.com` → `${TUNNEL_ID}.cfargotunnel.com` (proxied)
2. Create k8s secret with tunnel token
3. Deploy cloudflared pod with `TUNNEL_TOKEN` env var

### List tunnels
```bash
curl -s "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel?is_deleted=false" \
  -H "Authorization: Bearer ${TOKEN}"
```

### Delete tunnel
```bash
curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}" \
  -H "Authorization: Bearer ${TOKEN}"
```

## Cloudflare Pages

### Create Pages project
```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/pages/projects" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "my-project",
    "production_branch": "main",
    "build_config": {
      "build_command": "npm run build",
      "destination_dir": "dist",
      "root_dir": "frontend"
    }
  }'
```

### List Pages projects
```bash
curl -s "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/pages/projects" \
  -H "Authorization: Bearer ${TOKEN}"
```

### Add custom domain to Pages
```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/pages/projects/${PROJECT_NAME}/domains" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"name": "app.example.com"}'
```

## Zones

### List zones
```bash
curl -s "https://api.cloudflare.com/client/v4/zones?per_page=50" \
  -H "Authorization: Bearer ${TOKEN}"
```

Filter: `?name=hyperglot.io`

## Error Handling

All responses follow the same structure:
```json
{"success": true/false, "errors": [...], "result": {...}}
```

Always check `success` field before using `result`. Common errors:
- `81053` — DNS record already exists (use PATCH to update)
- `1000` — Invalid API token (wrong token type or expired)
- `7003` — Could not route to zone (token lacks zone permission)

## Existing Tunnels

| Tunnel | ID | Routes To |
|--------|-----|-----------|
| hyperglot-hetzner | f2aed06f-bcfa-4523-a719-d2a174cf8248 | api.hyperglot.io → hyperglot-backend:3001 |

## Additional Resources

For tunnel setup with k8s, see the `k3s-deploy` skill.
