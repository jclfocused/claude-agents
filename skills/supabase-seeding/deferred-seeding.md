# Deferred Seeding Pattern

Complete pattern for seeding data that depends on user signup.

## The Problem

Supabase auth.users is managed by Supabase Auth, not migrations. You can't directly seed users - they're created when people sign up through your app.

But often you need seed data that references users:
- Admin accounts
- Organization owners
- Test users with specific roles

## The Solution: Deferred Seeding

Store the **configuration** in your database, then **apply** it when users sign up.

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   seed.sql      │────▶│  Config Tables   │────▶│ handle_new_user │
│  (runs once)    │     │  (stores intent) │     │    (trigger)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                         │
                                                         ▼
                                                 ┌─────────────────┐
                                                 │  User Signup    │
                                                 │  (applies seed) │
                                                 └─────────────────┘
```

## Complete Example: Organization Seeding

### Migration 1: Create Config Tables

```sql
-- migrations/20240101_seed_infrastructure.sql

-- Stores organization owners who should have orgs created on signup
CREATE TABLE IF NOT EXISTS public.org_seed_config (
  email TEXT PRIMARY KEY,
  org_name TEXT NOT NULL,
  org_slug TEXT UNIQUE NOT NULL,
  plan TEXT NOT NULL DEFAULT 'free',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Stores domains that auto-join organizations
CREATE TABLE IF NOT EXISTS public.org_seed_domains (
  domain TEXT NOT NULL,
  org_slug TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  PRIMARY KEY (domain, org_slug)
);
```

### Migration 2: Create Application Functions

```sql
-- migrations/20240102_org_seeding_functions.sql

-- Creates org when owner signs up
CREATE OR REPLACE FUNCTION public.create_seeded_organization(
  p_user_id UUID,
  p_email TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_config RECORD;
  v_org_id UUID;
BEGIN
  -- Check for owner config
  SELECT * INTO v_config FROM public.org_seed_config WHERE email = p_email;
  IF v_config IS NULL THEN RETURN NULL; END IF;

  -- Skip if org already exists
  SELECT id INTO v_org_id FROM public.organizations WHERE slug = v_config.org_slug;
  IF v_org_id IS NOT NULL THEN RETURN v_org_id; END IF;

  -- Create organization
  INSERT INTO public.organizations (name, slug, owner_id)
  VALUES (v_config.org_name, v_config.org_slug, p_user_id)
  RETURNING id INTO v_org_id;

  -- Link profile to org
  UPDATE public.profiles SET organization_id = v_org_id WHERE id = p_user_id;

  RETURN v_org_id;
END;
$$;

-- Joins org by domain when user signs up
CREATE OR REPLACE FUNCTION public.join_org_by_domain(
  p_user_id UUID,
  p_email TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_domain TEXT := split_part(p_email, '@', 2);
  v_config RECORD;
  v_org RECORD;
BEGIN
  -- Check for domain config
  SELECT * INTO v_config FROM public.org_seed_domains WHERE domain = v_domain;
  IF v_config IS NULL THEN RETURN NULL; END IF;

  -- Get organization
  SELECT * INTO v_org FROM public.organizations WHERE slug = v_config.org_slug;
  IF v_org IS NULL THEN RETURN NULL; END IF;

  -- Add as member
  INSERT INTO public.organization_members (organization_id, user_id, email, role)
  VALUES (v_org.id, p_user_id, p_email, v_config.role)
  ON CONFLICT DO NOTHING;

  -- Link profile
  UPDATE public.profiles SET organization_id = v_org.id WHERE id = p_user_id;

  RETURN v_org.id;
END;
$$;
```

### Migration 3: Hook into Auth

```sql
-- migrations/20240103_auth_hooks.sql

-- Update the profile creation trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  -- Create profile
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email);

  -- Try to create org (if owner)
  PERFORM public.create_seeded_organization(NEW.id, NEW.email);

  -- Try to join org by domain
  PERFORM public.join_org_by_domain(NEW.id, NEW.email);

  RETURN NEW;
END;
$$;
```

### seed.sql: The Data

```sql
-- seed.sql

-- Define organization owners
INSERT INTO public.org_seed_config (email, org_name, org_slug, plan)
VALUES
  ('ceo@acme.com', 'Acme Corp', 'acme', 'enterprise'),
  ('admin@startup.io', 'Startup Inc', 'startup', 'pro')
ON CONFLICT (email) DO UPDATE SET
  org_name = EXCLUDED.org_name,
  plan = EXCLUDED.plan;

-- Define auto-join domains
INSERT INTO public.org_seed_domains (domain, org_slug, role)
VALUES
  ('acme.com', 'acme', 'member'),
  ('startup.io', 'startup', 'member'),
  ('contractors.acme.com', 'acme', 'guest')
ON CONFLICT (domain, org_slug) DO UPDATE SET
  role = EXCLUDED.role;

-- Backfill existing users
DO $$
DECLARE v_user RECORD;
BEGIN
  -- Create orgs for existing owners
  FOR v_user IN
    SELECT u.id, u.email FROM auth.users u
    JOIN public.org_seed_config c ON u.email = c.email
  LOOP
    PERFORM public.create_seeded_organization(v_user.id, v_user.email);
    RAISE NOTICE 'Created org for owner: %', v_user.email;
  END LOOP;

  -- Join existing users by domain
  FOR v_user IN
    SELECT DISTINCT u.id, u.email FROM auth.users u
    JOIN public.org_seed_domains d ON split_part(u.email, '@', 2) = d.domain
    WHERE NOT EXISTS (
      SELECT 1 FROM public.organization_members m WHERE m.user_id = u.id
    )
  LOOP
    PERFORM public.join_org_by_domain(v_user.id, v_user.email);
    RAISE NOTICE 'Added user by domain: %', v_user.email;
  END LOOP;
END $$;
```

## Testing the Pattern

1. Apply migrations:
   ```bash
   npx supabase db push --local
   ```

2. Apply seed:
   ```bash
   npx supabase db push --local --include-seed
   ```

3. Sign up a user matching your seed config

4. Verify in Supabase Studio:
   - Organization was created
   - User is linked to organization
   - Proper role assigned

## Extending the Pattern

### Add More Seed Types

Create config tables for anything:

```sql
-- Feature flags per user
CREATE TABLE user_seed_features (
  email TEXT PRIMARY KEY,
  features TEXT[] NOT NULL DEFAULT '{}'
);

-- Apply in handle_new_user
UPDATE profiles SET features = f.features
FROM user_seed_features f
WHERE profiles.email = f.email;
```

### Multiple Environments

Use environment-specific seed files:

```toml
# Development
[db.seed]
sql_paths = ["./seed.sql", "./seed.dev.sql"]

# Production (via separate config or manual)
# npx supabase db push --include-seed
```

## Troubleshooting

### Seed Not Running

Check config.toml has `enabled = true` under `[db.seed]`.

### Backfill Not Finding Users

auth.users might be empty. The backfill runs once - new signups use the trigger.

### Org Created But User Not Linked

Check the order of operations in handle_new_user. Profile must exist first.
