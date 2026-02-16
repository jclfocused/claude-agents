---
name: supabase-seeding
description: Guides proper Supabase database seeding patterns. Use when creating seed files, seeding data, populating databases, or setting up test data in Supabase projects. Covers local and production seeding best practices.
---

# Supabase Database Seeding

Proper patterns for seeding data in Supabase projects that work locally and in production.

## Key Principle: Separate Schema from Data

**Critical:** Keep schema (tables, functions) in migrations, data in seed files.

| File Type | Contains | When Applied |
|-----------|----------|--------------|
| `migrations/*.sql` | Tables, functions, triggers, RLS policies | `db push`, `db reset` |
| `seed.sql` | INSERT statements, backfill logic | `db reset`, `db push --include-seed` |

## Setup

### 1. Configure seed.sql in config.toml

```toml
[db.seed]
enabled = true
sql_paths = ["./seed.sql"]
```

### 2. Create seed.sql

Location: `supabase/seed.sql` (same level as `migrations/`)

## Seed File Patterns

### Pattern 1: Simple Data Seeding

For basic reference data:

```sql
-- Seed: Reference Data
-- Description: Seeds initial reference data
-- Run: npx supabase db reset (local) or npx supabase db push --include-seed (production)

-- Use ON CONFLICT for idempotency (can run multiple times safely)
INSERT INTO public.categories (name, slug)
VALUES
  ('Technology', 'technology'),
  ('Science', 'science'),
  ('Arts', 'arts')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name;
```

### Pattern 2: User-Dependent Seeding

When data depends on auth.users (which doesn't exist until signup):

**Step 1: Create config table in migration**
```sql
-- Migration: Create seed config infrastructure
CREATE TABLE IF NOT EXISTS public.seed_config (
  email TEXT PRIMARY KEY,
  config JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Step 2: Create deferred setup function in migration**
```sql
CREATE OR REPLACE FUNCTION public.apply_seed_config(p_user_id UUID, p_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_config JSONB;
BEGIN
  SELECT config INTO v_config FROM public.seed_config WHERE email = p_email;
  IF v_config IS NULL THEN RETURN FALSE; END IF;

  -- Apply configuration to user (customize per project)
  UPDATE public.profiles
  SET role = v_config->>'role'
  WHERE id = p_user_id;

  RETURN TRUE;
END;
$$;
```

**Step 3: Hook into handle_new_user trigger in migration**
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, email) VALUES (NEW.id, NEW.email);
  PERFORM public.apply_seed_config(NEW.id, NEW.email);
  RETURN NEW;
END;
$$;
```

**Step 4: Seed the configuration data**
```sql
-- seed.sql
INSERT INTO public.seed_config (email, config)
VALUES ('admin@example.com', '{"role": "admin"}'::jsonb)
ON CONFLICT (email) DO UPDATE SET config = EXCLUDED.config;

-- Backfill for existing users
DO $$
DECLARE v_user RECORD;
BEGIN
  FOR v_user IN SELECT id, email FROM auth.users LOOP
    PERFORM public.apply_seed_config(v_user.id, v_user.email);
  END LOOP;
END $$;
```

### Pattern 3: Domain-Based Seeding

Auto-add users by email domain:

```sql
-- Migration: Domain config table
CREATE TABLE public.domain_config (
  domain TEXT PRIMARY KEY,
  config JSONB NOT NULL
);

CREATE OR REPLACE FUNCTION public.apply_domain_config(p_user_id UUID, p_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_domain TEXT := split_part(p_email, '@', 2);
  v_config JSONB;
BEGIN
  SELECT config INTO v_config FROM public.domain_config WHERE domain = v_domain;
  IF v_config IS NULL THEN RETURN FALSE; END IF;
  -- Apply domain-based configuration
  RETURN TRUE;
END;
$$;
```

```sql
-- seed.sql
INSERT INTO public.domain_config (domain, config)
VALUES
  ('company.com', '{"role": "employee"}'::jsonb),
  ('partner.com', '{"role": "partner"}'::jsonb)
ON CONFLICT (domain) DO UPDATE SET config = EXCLUDED.config;
```

## Commands

### Local Development

```bash
# Apply migrations only
npx supabase db push --local

# Apply migrations + seed
npx supabase db push --local --include-seed

# Full reset (DESTROYS DATA) + apply migrations + seed
npx supabase db reset
```

### Production

```bash
# Apply migrations only (safe)
npx supabase db push --project-id YOUR_PROJECT_ID

# Apply migrations + seed (careful!)
npx supabase db push --project-id YOUR_PROJECT_ID --include-seed
```

## Best Practices

### 1. Always Use ON CONFLICT

```sql
-- CORRECT - Idempotent
INSERT INTO categories (slug, name) VALUES ('tech', 'Technology')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name;

-- WRONG - Fails on re-run
INSERT INTO categories (slug, name) VALUES ('tech', 'Technology');
```

### 2. Use DO Blocks for Complex Logic

```sql
DO $$
DECLARE
  v_record RECORD;
BEGIN
  FOR v_record IN SELECT * FROM some_table LOOP
    -- Complex logic here
  END LOOP;
END $$;
```

### 3. Comment Your Seeds

```sql
-- Seed: Admin Users Configuration
-- Description: Sets up admin users for new signups
-- Dependencies: migrations/20240101_create_profiles.sql
-- Run: npx supabase db push --include-seed
```

### 4. Keep Seeds Idempotent

Seeds may run multiple times. Design them to be re-runnable without errors.

### 5. Separate Concerns

- **Config data** → seed.sql (emails, domains, settings)
- **Schema** → migrations (tables, functions)
- **Backfill logic** → DO blocks in seed.sql

## Common Mistakes

### Mistake 1: Tables in Seed Files

```sql
-- WRONG - Tables belong in migrations
CREATE TABLE IF NOT EXISTS public.users (...);
INSERT INTO public.users ...;
```

### Mistake 2: No Conflict Handling

```sql
-- WRONG - Will fail if data exists
INSERT INTO settings (key, value) VALUES ('theme', 'dark');

-- CORRECT
INSERT INTO settings (key, value) VALUES ('theme', 'dark')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
```

### Mistake 3: Assuming Users Exist

```sql
-- WRONG - auth.users may be empty
INSERT INTO profiles SELECT id FROM auth.users;

-- CORRECT - Use deferred pattern with triggers
```

## File Structure

```
supabase/
├── config.toml          # [db.seed] configuration
├── seed.sql             # Data seeding
└── migrations/
    ├── 001_initial.sql
    └── 002_seed_config.sql  # Seed infrastructure
```

For the complete deferred seeding pattern, see [deferred-seeding.md](deferred-seeding.md).
