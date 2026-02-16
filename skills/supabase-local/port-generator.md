# Supabase Port Generator

How to generate unique port ranges for new projects.

## Port Allocation Pattern

Each Supabase project needs 10 ports. Use a 5-digit pattern: `5XX6Y` where:
- `XX` = project identifier (43, 44, 45, etc.)
- `Y` = service index (0-9)

## Service Port Mapping

| Service | Offset | Example (5436X) |
|---------|--------|-----------------|
| Shadow DB | 0 | 54360 |
| API/Kong | 1 | 54361 |
| Database | 2 | 54362 |
| Studio | 3 | 54363 |
| Inbucket | 4 | 54364 |
| Storage | 5 | 54365 |
| Auth | 6 | 54366 |
| Realtime | 7 | 54367 |
| Edge Runtime | 8 | 54368 |
| DB Pooler | 9 | 54369 |

## Finding an Available Range

### Step 1: List Running Supabase Instances

```bash
# Check what's listening on 543XX ports
lsof -i :5436 -i :5437 -i :5438 | grep LISTEN
```

### Step 2: Check Existing Projects

Look at existing project config.toml files:

```bash
# Find all Supabase config files
find ~/code -name "config.toml" -path "*/supabase/*" 2>/dev/null
```

### Step 3: Pick Next Available Range

If 5436X and 5437X are used, use 5438X.

## Quick Reference

| Range | Status |
|-------|--------|
| 5436X | [Check if used] |
| 5437X | [Check if used] |
| 5438X | [Check if used] |
| 5439X | [Check if used] |
| 5440X | [Check if used] |

## Example: New Project Setup

```bash
# 1. Check used ports
lsof -i :5436 -i :5437 -i :5438 | head

# 2. If 5436X used, pick 5437X

# 3. Update config.toml with 5437X range
```

## Avoiding Conflicts

**Rule:** Each project gets ONE range. Never share ports between projects.

**Why:** Running multiple Supabase instances simultaneously requires unique ports for all services.
