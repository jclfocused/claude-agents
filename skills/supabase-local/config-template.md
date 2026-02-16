# Supabase config.toml Template

Full template with custom port configuration.

## Template

Replace `XXXX` with your port range prefix (e.g., 5436, 5437, 5438).

```toml
# A string used to distinguish different Supabase projects on the same host.
project_id = "your-project-name"

[api]
enabled = true
# Port to use for the API URL.
port = XXXX1
# Schemas to expose in your API. Tables, views and stored procedures in this schema will get API
# endpoints. public and storage are always included.
schemas = ["public", "graphql_public"]
# Extra schemas to add to the search_path of every request. public is always included.
extra_search_path = ["public", "extensions"]
# The maximum number of rows returns from a view, table, or stored procedure. Limits payload size
# for accidental or malicious requests.
max_rows = 1000

[db]
# Port to use for the local database URL.
port = XXXX2
# Port used by db diff command to initialize the shadow database.
shadow_port = XXXX0
# The database major version to use. This has to be the same as your remote database's.
major_version = 15

[db.pooler]
enabled = true
# Port to use for the local connection pooler.
port = XXXX9
# Specifies when a server connection can be reused by other clients.
pool_mode = "transaction"
# How many server connections to allow per user/database pair.
default_pool_size = 20
# Maximum number of client connections allowed.
max_client_conn = 100

[studio]
enabled = true
# Port to use for Supabase Studio.
port = XXXX3
# External URL of the API server that frontend connects to.
api_url = "http://127.0.0.1"

[inbucket]
enabled = true
# Port to use for the email testing server web interface.
port = XXXX4
# Uncomment to expose additional ports for testing user applications that send emails.
# smtp_port = 54325
# pop3_port = 54326

[storage]
enabled = true
# Port to use for Storage API.
port = XXXX5
# The maximum file size allowed (e.g. "5MB", "500KB").
file_size_limit = "50MiB"

[auth]
enabled = true
# Port to use for the Auth API.
port = XXXX6
# The base URL of your website. Used as an allow-list for redirects and for constructing URLs used
# in emails.
site_url = "http://127.0.0.1:3000"
# A list of *exact* URLs that auth providers are permitted to redirect to post authentication.
additional_redirect_urls = ["https://127.0.0.1:3000"]
# How long tokens are valid for, in seconds. Defaults to 3600 (1 hour), maximum 604,800 (1 week).
jwt_expiry = 3600
# If disabled, the refresh token will never expire.
enable_refresh_token_rotation = true
# Allows refresh tokens to be reused after expiry, up to the specified interval in seconds.
refresh_token_reuse_interval = 10
# Allow/disallow new user signups to your project.
enable_signup = true

[auth.email]
# Allow/disallow new user signups via email to your project.
enable_signup = true
# If enabled, a user will be required to confirm any email change on both the old, and new email
# addresses.
double_confirm_changes = true
# If enabled, users need to confirm their email address before signing in.
enable_confirmations = false

[auth.sms]
# Allow/disallow new user signups via SMS to your project.
enable_signup = true
# If enabled, users need to confirm their phone number before signing in.
enable_confirmations = false

# External OAuth providers
[auth.external.google]
enabled = false
client_id = "env(GOOGLE_CLIENT_ID)"
secret = "env(GOOGLE_CLIENT_SECRET)"
redirect_uri = ""

[realtime]
enabled = true
# Port to use for the Realtime API.
port = XXXX7

[edge_runtime]
enabled = true
# Port to use for the Edge Runtime.
port = XXXX8
# Configure the request body size limit.
request_body_size_limit = "2mb"

[analytics]
enabled = false
# Port to use for the Analytics API.
port = 54327
backend = "postgres"
```

## Quick Port Reference

When using prefix `5436`:

| Service | Port |
|---------|------|
| Shadow DB | 54360 |
| API | 54361 |
| Database | 54362 |
| Studio | 54363 |
| Inbucket | 54364 |
| Storage | 54365 |
| Auth | 54366 |
| Realtime | 54367 |
| Edge Runtime | 54368 |
| DB Pooler | 54369 |

## Applying the Template

1. Copy this template
2. Replace all `XXXX` with your port prefix
3. Save as `supabase/config.toml`
4. Update project_id
5. Run `npx supabase start`
