---
name: backend-postgres-box
description: Provision and operate Postgres for a backend app on Justin's box — role+db on the native shared PG16 cluster (127.0.0.1:5641), the ~30-line SQL migration runner, extensions, nightly restic→R2 backups, and pre-deploy dumps. Use when standing up a new app's database, adding migrations, setting up or fixing backups, rotating a DB password, or when the user says "provision a db", "new service database", "postgres on the box", "set up migrations", "db backups", "pg_dump", "move off Supabase".
---

# Postgres on the box

One NATIVE PostgreSQL 16 cluster serves every self-hosted app: cluster `16/main`, **port 5641** (non-standard on purpose — busy box), system unit `postgresql@16-main`, data in `/var/lib/postgresql/16/main`, log at `/var/log/postgresql/postgresql-16-main.log`. Verify with `pg_lsclusters`.

**Hard rules:**
- **Loopback-only, forever.** `pg_hba` = `peer` local + `scram-sha-256` on `127.0.0.1/::1` only. The cloudflared tunnel carries the app's HTTP port ONLY — never the DB. No RLS/JWT-exposure machinery needed because the DB is simply unreachable off-box.
- **Role + database per app**, password auth, app owns its db. No cross-db queries; cross-service refs are opaque strings, never FKs.
- No Docker, no Supabase for new backend apps — those Docker Supabase stacks (546XX/55XXX blocks) are per-project legacies, not the pattern.

Companion skills: `backend-box-deploy` (systemd unit + tunnel), `backend-auth-service`, `backend-file-storage`.

## 1. Provision a role + db

**Script (hyperglot pattern, preferred):** `/home/justin/code/hyperglot-workspace/hyperglot-infra/scripts/create-service-db.sh <slug>` — creates role+db `hg_<slug>` (idempotent), writes `DATABASE_URL=postgresql://hg_<slug>:<pass>@127.0.0.1:5641/hg_<slug>` to `~/.config/hyperglot/db-<slug>.env` under `umask 077`. **Re-running ROTATES the password** — that IS the rotation procedure; restart the service after. For a non-hyperglot app, copy the script and change the `hg_` prefix + env destination to `~/.config/<app>/db.env` (see `references/create-app-db.sh`).

**Manual (rkfitness pattern):**
```sh
sudo -u postgres psql -p 5641 <<SQL
CREATE ROLE myapp LOGIN PASSWORD '<openssl rand -hex 24>';
SQL
sudo -u postgres createdb -p 5641 -O myapp myapp
umask 077; echo "DATABASE_URL=postgresql://myapp:<pass>@127.0.0.1:5641/myapp" > ~/.config/myapp/api.env
```
Env file mode 0600, never committed, never in CI. Dev DBs live on the same cluster as `<prefix>_dev_<slug>`, same role (hyperglot convention).

## 2. Extensions

Verified available + **trusted** on this cluster (migrations can `CREATE EXTENSION` without superuser): `pgcrypto`, `citext`, `pg_trgm`, `btree_gist`, `uuid-ossp`.

**NOT installed:** `pg_cron`, `pg_net`, `postgis`, `vector`. Do not design around them — scheduled DB work = a **systemd --user timer** running a script/`psql`, HTTP-from-DB = app code. This is the box idiom (24 user timers live; see `backend-box-deploy`).

## 3. Migrations: the ~30-line runner, no framework

Plain numbered SQL files `migrations/0001_name.sql`, lexical sort. The canonical runner is `/home/justin/code/rkfitness-workspace/rkfitness-api/src/lib/migrate.ts` (~30 lines — copy it near-verbatim, full text in `references/migrate.md`):

- `create table if not exists schema_migrations (version text primary key, applied_at timestamptz default now())`
- skip applied versions; each pending file runs **in one transaction** together with its `insert into schema_migrations`
- resolves `migrations/` relative to `import.meta.url` with `'..', '..'` so `dist/` and `src/` both find it
- CLI wrapper `scripts/migrate.ts` (tsx) wired as `npm run migrate`; deploy script calls it between build and restart

**When to run — two proven variants:**
- **rkfitness (single app):** deploy.sh runs `npm run migrate` after build, before `systemctl --user restart`.
- **hyperglot (fleet, service-kit `migrate.ts` in `hyperglot-packages/packages/service-kit/src/`):** migrations run at service BOOT, so restart = migrate. There are **no down-migrations**: a failed migration fails the `/health`+`/ready` gate, which auto-rolls back **CODE only** — therefore every migration must be **additive / backward-compatible with the previous release** (add column nullable, backfill, tighten later; never drop-and-replace in one release).

**Before any destructive migration** (drop/rename table or column): `grep -rn <name> src/ scripts/` first — rkfitness migration 0003 dropped `protocols` while a live query still joined it and two pages 500ed. And take a pre-deploy dump (§5).

## 4. Nightly backups: restic → Cloudflare R2 (hyperglot model — copy it)

The only real backup on the box. Model files (all verified, symlinked into `~/.config/systemd/user/`):
- `/home/justin/code/hyperglot-workspace/hyperglot-infra/backup/hg-backup.sh` + `hyperglot-backup.{service,timer}` — nightly **03:20**, `Persistent=true`, `RandomizedDelaySec=10m`, `Nice=10`, `IOSchedulingClass=idle`
- `hg-backup-check.sh` + `hyperglot-backup-check.{service,timer}` — **07:10** restore-verification companion (Sunday = full restore drill)
- `install.sh` — symlinks units in; full doc `BACKUP.md` alongside

What hg-backup.sh does (replicate each piece for a new app):
1. **Discovers** DBs by name pattern (`LIKE 'hg\_%'`) — a newly provisioned service is covered the same night. Refuses an empty list.
2. `pg_dump --format=custom --compress=zstd` per DB, using a dedicated **read-only role** (`hg_backup`, `pg_read_all_data`, creds in `~/.config/hyperglot/db-backup.env`) — never the app role, never postgres.
3. Git-bundles every workspace repo (`--all`) + captures `status --porcelain` and `diff HEAD` patches — bundles carry committed history only.
4. Snapshots `~/.config/<dir>/*.env` (restore credentials; restic encrypts at rest).
5. **SQLite via the online `.backup` API** — `python3 sqlite3.Connection.backup`, NEVER a plain `cp` of a WAL db (torn copy), and NOT the sqlite3 CLI (the only one on this box is in `~/android-sdk`, off unit PATH).
6. `restic backup --tag <name> --exclude-caches` to R2, then `restic forget --group-by tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`. Staging dir is FIXED (`~/.cache/<name>-backup/staging`), not mktemp — stable restic paths.
7. **Every failure appends a line to `~/.claude/automation/logs/alerts.log`** via an EXIT trap.

Secrets: `~/.config/hyperglot/backup.env` holds `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, R2 keys (names only — never print values). ⚠️ `RESTIC_PASSWORD` exists only there + on the MacBook — single point of total backup loss.

**For a new app:** either add its DB to the existing discovery pattern (if it adopts the `hg_` prefix) or clone the four files with the app's own prefix, backup.env, and tag. A cloned app skill/ARCHITECTURE.md that *promises* a nightly timer does not count — **install and `systemctl --user list-timers | grep backup` to prove it** (rkfitness shipped without one; only the model existed).

## 5. Pre-deploy manual dumps

Before any risky deploy/migration:
```sh
mkdir -p ~/backups/<app>
pg_dump "$(grep -o 'postgresql://.*' ~/.config/<app>/db.env)" | gzip > ~/backups/<app>/pre-deploy-$(date +%Y%m%d-%H%M%S).sql.gz
# (use the app's DATABASE_URL — no `justin` role exists, so bare `pg_dump -d <app>` peer-auth fails)
```
Live example: `~/backups/rkfitness/pre-deploy-*.sql.gz`. This is a habit, not a substitute for §4.

## Worked example: new app "ledger"

```sh
# 1. provision (copy create-service-db.sh, prefix-less variant)
~/.claude/skills/backend-postgres-box/references/create-app-db.sh ledger
# → role+db "ledger", DATABASE_URL in ~/.config/ledger/db.env (0600)

# 2. first migration
mkdir -p migrations && cat > migrations/0001_init.sql <<'SQL'
create extension if not exists pgcrypto;
create extension if not exists citext;
create table users (id uuid primary key default gen_random_uuid(), email citext unique not null);
SQL
# copy rkfitness src/lib/migrate.ts + scripts/migrate.ts; npm run migrate

# 3. prove isolation
psql "$(grep -o 'postgresql://.*' ~/.config/ledger/db.env)" -c 'select 1'   # works on-box
# off-box: port 5641 unreachable — nothing to do, never tunnel it

# 4. backups: clone hyperglot-infra/backup/ four-file set with prefix "ledger",
#    create read-only role, install units, verify: systemctl --user list-timers | grep ledger
```

## Gotchas

- **Password rotation = re-running the provision script**; the service must be restarted after, and a dev DB sharing the role rotates too.
- **`schema_migrations` versions are filenames sans `.sql`** — never rename an applied migration file; the runner would re-apply it.
- Boot-migration fleets: schema changes must survive the PREVIOUS release's code (auto-rollback replays old code against new schema).
- `pg_hba` additions: keep to `scram-sha-256` on `127.0.0.1/::1`; never add a non-loopback host line.
- SQLite backup: online API only; python3 stdlib, not the CLI (PATH trap under systemd).
- The shared-cluster port is **5641 everywhere** — `psql`/`pg_dump` default to 5432 and will hit nothing; always pass `-p 5641` or a full URL.
- `hg_*` (no `dev_`) databases are PRODUCTION — never migrate/truncate one from a dev context.
- Supabase Docker stacks on 546XX ports are separate animals; don't confuse their `db` ports (e.g. cowork 54612) with the native cluster.
- Backup discovery-by-pattern means a wrong-prefix db is silently NOT backed up — check the nightly's printed manifest after adding an app.

## Observability (required)

Read `observability`; the DB's share of it is small and specific.

- **One SECURITY DEFINER scalars function per app**, `obs.<app>_scalars()` returning a flat `jsonb`
  of NUMBERS (booleans as `0|1`, enums as small ints — the dashboard `unwrap`s them, and a string
  can never be unwrapped). Granted to the read-only `obs_ro` role and to nothing else; the ops
  collector makes ONE round trip per tick and reads only this. No PII in it — counts only, no
  emails, no org names, no ids. It goes in the app's `manifest.yaml` as
  `db: { scalars_fn: "obs.<app>_scalars()" }`.
- **A source the collector cannot reach must emit `null` + `<source>_stale: 1`**, never `0`. A
  missing number that renders green is worse than no panel.
- **The backup timer has to emit its own truth** — `backup_age_h`, `backup_restore_drill_ok`,
  `backup_snapshot_mb`. A backup that is merely punctual is not a backup; the restore drill is the
  scalar that makes it real, and it needs an alert on staleness.
- **Migrations log**: the runner writes one wide line per applied file (`msg: 'migration.applied'`,
  `file`, `duration_ms`) — a migration that half-applied at 03:00 is otherwise invisible.
- Never log a connection string, a row payload, or a `WHERE` clause containing an email.
