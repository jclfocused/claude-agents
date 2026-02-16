---
name: supabase-local
description: Manages local Supabase setup with custom ports. Use when setting up Supabase locally, creating migrations, managing local database, or configuring Supabase for a project. Ensures proper commands and port configuration.
---

# Local Supabase Management

Critical rules and patterns for working with Supabase locally.

## Critical Rules

### ALWAYS Use npx

```bash
# CORRECT - Always use npx
npx supabase start
npx supabase stop
npx supabase status
npx supabase migration new
npx supabase db push --local

# WRONG - Never use brew-installed supabase
supabase start  # NO!
```

### ALWAYS Create Migrations Properly

```bash
# CORRECT - Use the CLI to generate migration files
npx supabase migration new add_user_profiles

# This creates: supabase/migrations/TIMESTAMP_add_user_profiles.sql
# Then edit that file with your SQL
```

### ALWAYS Push Locally

```bash
# CORRECT - Apply migrations to local database
npx supabase db push --local

# WRONG - This resets your data!
npx supabase db reset  # NEVER unless explicitly asked
```

### NEVER Use db reset

`npx supabase db reset` destroys all local data. Only use when:
- User explicitly requests it
- You warn them data will be lost
- They confirm

## Custom Port Configuration

Every project needs unique ports to avoid conflicts when running multiple Supabase instances.

### Port Range Pattern

Use a unique 5-digit prefix for each project:

| Project | API | DB | Studio | Inbucket | Storage |
|---------|-----|-----|--------|----------|---------|
| Project A | 54361 | 54362 | 54363 | 54364 | 54365 |
| Project B | 54371 | 54372 | 54373 | 54374 | 54375 |
| Project C | 54381 | 54382 | 54383 | 54384 | 54385 |

### Generating Unique Ports

When setting up a new project:

1. Check existing projects for used port ranges
2. Pick a new prefix (e.g., 5438X if 5436X and 5437X are used)
3. Configure all services with that prefix

See [port-generator.md](port-generator.md) for a helper.

## Setup Workflow

### Step 1: Initialize Supabase

```bash
cd backend  # Supabase lives in backend/
npx supabase init
```

### Step 2: Configure Ports

Edit `supabase/config.toml`:

```toml
[api]
port = 54361

[db]
port = 54362

[studio]
port = 54363

[inbucket]
port = 54364

[storage]
port = 54365

[auth]
port = 54366

[realtime]
port = 54367
```

See [config-template.md](config-template.md) for full template.

### Step 3: Start Supabase

```bash
npx supabase start
```

### Step 4: Get Credentials

```bash
npx supabase status
```

Copy the keys to your `.env` file.

## Migration Workflow

### Create Migration

```bash
npx supabase migration new descriptive_name
```

### Edit Migration File

Edit `supabase/migrations/TIMESTAMP_descriptive_name.sql`:

```sql
-- Create table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create policy
CREATE POLICY "Users can view own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = user_id);
```

### Apply Migration

```bash
npx supabase db push --local
```

### Verify

```bash
# Check in Studio
open http://127.0.0.1:PORT  # Your Studio port

# Or use psql
PGPASSWORD=postgres psql -h localhost -p PORT -U postgres -d postgres
```

## Type Generation

After schema changes, regenerate TypeScript types:

```bash
npx supabase gen types typescript --local > src/database/types.generated.ts
```

## Database Connection Strings

### Local Development (direct)

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:PORT/postgres
```

### Docker Development

```bash
DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:PORT/postgres
```

### Production (pooler)

```bash
DATABASE_URL=postgresql://postgres.PROJECT:PASSWORD@aws-1-region.pooler.supabase.com:5432/postgres
```

## Direct Database Access

For ad-hoc queries, use psql:

```bash
# Single command
PGPASSWORD=postgres psql -h localhost -p PORT -U postgres -d postgres -c "SELECT * FROM profiles;"

# Interactive session
PGPASSWORD=postgres psql -h localhost -p PORT -U postgres -d postgres
```

## Common Commands Reference

| Command | Purpose |
|---------|---------|
| `npx supabase start` | Start local Supabase |
| `npx supabase stop` | Stop local Supabase |
| `npx supabase status` | Show credentials and URLs |
| `npx supabase migration new NAME` | Create new migration |
| `npx supabase db push --local` | Apply migrations |
| `npx supabase gen types typescript --local` | Generate types |
| `npx supabase db diff` | Show schema diff |

## Troubleshooting

### Port Already in Use

Another Supabase instance is running. Either:
- Stop it: `npx supabase stop`
- Use different ports in config.toml

### Migration Failed

Check the SQL syntax, then:
```bash
npx supabase db push --local
```

If data issues, ask user if they want to reset.

### Can't Connect from Docker

Use `host.docker.internal` instead of `localhost`:
```bash
DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:PORT/postgres
```

For templates, see [config-template.md](config-template.md).
