---
name: backend-box-deploy
description: Stand up or migrate an app/service as a self-hosted backend on THIS server (Justin's box) — loopback port + systemd --user unit pair + cloudflared token tunnel + deploy script, following the proven rkfitness/hyperglot patterns. Use when asked to "deploy on the box", "host it on the server", "systemd unit for the app", "set up a tunnel for X", "move it off Cloudflare Workers/Vercel onto the box", "self-host this service", or when a new backend touches local/server data (local Supabase, native Postgres, files on disk).
---

# Backend deploy on this box (systemd --user + cloudflared tunnel)

Canonical LaserFocused pattern: app binds **127.0.0.1:\<port\>** only, runs as a
`systemd --user` unit pair (`<slug>.service` + `<slug>-tunnel.service`), reaches the
internet via a Cloudflare **remotely-managed token tunnel**
(`<host>.laserfocused.ee`). DB stays loopback-only, never tunneled. First question
before any deploy-target choice: does the app touch local/server data? Yes → this
pattern, never a Cloudflare Worker (same-account Worker→tunnel fetch loops, error 1003).

Verbatim unit/script templates: `references/templates.md` (beside this file).

## Steps

### 1. Pick a free loopback port

```sh
ss -ltn        # check collisions first — no central registry
```
Ad-hoc unique high port for app HTTP (existing picks: ops 7300/7311, rome-trip 7460,
rkfitness-api 54385, commons-concepts 8794, headroom 8790, speech 4104). Supabase
stacks instead take an unused `546XX` 10-port block — see
`~/.claude/skills/supabase-local/SKILL.md`. Native shared Postgres = **5641**.
Record the port in the workspace CLAUDE.md port table.

### 2. Prod layout — `~/code` = dev, `~/prod` = prod

Treat `~/prod` as a separate VPS that happens to share hardware. Nothing hand-copied
between the trees. Two variants:

- **git-pull-light** (rkfitness — default for single apps): `~/prod/<slug>/<repo>` is a
  git checkout; deploy = `git reset --hard origin/main` + build + restart (step 6).
- **release-flip** (hyperglot fleets): `~/prod/<slug>/current -> releases/<run>-<sha7>`
  symlink flipped atomically by CI + `install-release.sh` with health-gate + rollback.
  Model: `/home/justin/code/hyperglot-workspace/hyperglot-infra/DEPLOY.md`. Use only
  for multi-service fleets; don't build this for one app.

First install (once, by hand): clone into `~/prod/<slug>/`, `mkdir` any storage dir,
place units, `systemctl --user daemon-reload && systemctl --user enable --now <slug>`,
and ensure `loginctl enable-linger justin` (verify: `loginctl show-user justin | grep Linger`).

### 3. Secrets → `~/.config/<slug>/*.env`, mode 0600

```sh
(umask 077 && mkdir -p ~/.config/<slug> && touch ~/.config/<slug>/{api.env,tunnel.env})
```
Key names only here: `DATABASE_URL`, `JWT_SECRET`, etc. in `api.env`; `TUNNEL_TOKEN`
in `tunnel.env`. Never in the unit file, never in the repo, never in GitHub Actions
secrets. Units load them via `EnvironmentFile=`.

DB provisioning on the native cluster (loopback 5641, scram): model script
`/home/justin/code/hyperglot-workspace/hyperglot-infra/scripts/create-service-db.sh`
(role + owned db via `sudo -u postgres psql`, writes `DATABASE_URL` to an env file
under umask 077).

### 4. systemd --user unit pair

Model files (both EXIST — read them): `~/.config/systemd/user/rkfitness-api.service`
and `~/.config/systemd/user/rkfitness-tunnel.service`. Full templates in
`references/templates.md`. The load-bearing lines:

- `ExecStart=/home/justin/.nvm/versions/node/v22.22.2/bin/node dist/index.js` —
  **absolute node path**. systemd --user has no nvm shims and `/usr/bin/node` is v18.
  (hyperglot uses the `~/prod/.node` symlink → same v22.22.2.)
- `Environment=NODE_ENV=production` + `Environment=PORT=<port>` in the unit;
  `EnvironmentFile=%h/.config/<slug>/api.env` for secrets.
- `Restart=on-failure` / `RestartSec=3`; tunnel unit `Restart=always` +
  `RestartSteps=6` / `RestartMaxDelaySec=120` backoff.
- `StandardOutput=journal`, `StandardError=journal`, `SyslogIdentifier=<slug>` —
  journald is canonical; read with `journalctl --user -u <slug> -f`.
- `[Install] WantedBy=default.target`.

Prefer keeping the unit in the repo (`<repo>/deploy/*.service`) and symlinking into
`~/.config/systemd/user/` (drawing-viewer/ops/hyperglot-backup do this); a plain file
there is fine too (rkfitness, rome-trip).

### 5. Tunnel — remotely-managed, token-based

**Ruling:** token/remote-managed tunnel for single-hostname apps; a committed
config-file tunnel ONLY for multi-hostname fleets (hyperglot-next-tunnel).
`~/.cloudflared` does not exist on this box and must stay that way — never write a
local `config.yml`; ingress lives Cloudflare-side.

Copy the canonical idempotent script
`/home/justin/code/mjcode/scripts/setup-cloudflare.sh` and edit its header vars:
`HOSTNAME=app-<slug>.laserfocused.ee`, `TUNNEL_NAME=<slug>`,
`SERVICE=http://localhost:<port>` (also fix the hardcoded `"name":"mj"` in
`DNS_BODY` to your host label). Zone `laserfocused.ee` id is already in the script;
run with `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` from `~/.zshrc`. It
reuses-or-creates the tunnel (`config_src=cloudflare`), PUTs ingress, upserts the
proxied CNAME, and **prints TUNNEL_TOKEN** → put that in
`~/.config/<slug>/tunnel.env` as `TUNNEL_TOKEN=…` (0600). The token goes in the
EnvironmentFile, never as a `--token` CLI arg (visible in `ps`).

Then the `<slug>-tunnel.service` unit (template in references): `After=<slug>.service`,
`ExecStart=/usr/local/bin/cloudflared --no-autoupdate tunnel run`.

One tunnel can carry multiple hostnames later by re-PUTting ingress (speech tunnel
serves two hosts). More API recipes: `~/.claude/skills/cloudflare-api/SKILL.md`.

### 6. Deploy script with health poll

Model (EXISTS): `/home/justin/code/rkfitness-workspace/rkfitness-api/deploy/deploy.sh`;
template in references. Shape: refuse if `~/prod` checkout missing → `git fetch` +
`reset --hard origin/main` → `npm ci --include=dev` → `npm run build` →
`npm run migrate` → `systemctl --user restart <slug>` → poll
`http://127.0.0.1:<port>/health` 30×1s; on failure dump the last 40 journal lines and
exit 1; on success print the deployed short SHA.

Keep `/health` (and `/v1/health` if the API is versioned) **unauthenticated** — a
health probe behind auth answers 401 and sends people hunting a phantom creds bug.

### 7. Watchdog timer (optional)

Model (EXISTS): `~/ops/infra/ops-web-watchdog.{service,timer}` — oneshot every 60s
(`OnBootSec=30`, `OnUnitActiveSec=60`, `Persistent=true`) that starts the unit **only
when `ActiveState=inactive`**. A `failed` unit is deliberately left alone so a real
crash-loop still hits start-limit + self-heal escalation instead of being hammered.

### 8. Register in Mission Control

Append to `~/ops/packages/shared/workspaces.json` (or update the existing entry's
`deployTarget`): `"kind": "systemd"`, `"units": ["<slug>", "<slug>-tunnel"]`,
`"prodUrl"`/`"healthUrl"`. Also add a `--line-<id>` accent in ops
`apps/web/app/globals.css` for new workspaces. Design doc:
`~/ops/docs/design/workspace-registry.md`.

### 9. Verify — deploy-verify skill, always

`curl` the live https URL and prove the **new** artifact is serving (not a cached
one); prove the DB port is NOT reachable off-box. Never claim "deployed" off a
successful command alone.

## Observability (required)

Read `observability` for the contract, `observability-logs` for the Alloy/Loki mechanics,
`ops-dashboard` for the manifest and the Grafana instance. Three concrete obligations here:

1. **The app owns `deploy/observability/`** — `<app>-logs.alloy` (relabel-only; it forwards to
   `loki.write.observability.receiver` **by component name**, never a URL, never `:3100`),
   `manifest.yaml`, the generated `grafana/` tree, `push.sh` (`GRAFANA_URL` + `GRAFANA_SA_TOKEN`
   from env) and `install.sh`. Never write a Loki or Grafana host into the app repo; that is
   what makes moving the app to its own server a config swap instead of an excavation.
2. **The deploy runs the installers.** `deploy.sh` calls the app's `install.sh` → the platform's
   `~/ops/infra/observability/install-alloy-app.sh <file>`, which **validates the whole
   `/etc/alloy` directory before restarting alloy**. `alloy.service` is a shared, box-wide system
   service: one malformed file takes down every tenant's log pipeline, not just yours.
3. **Every unit and timer gets a `manifest.yaml` entry** — `unit`, `expected_state`,
   `syslog_identifier`, and for a service a `probe` against `/health`. A unit with no manifest
   row is a unit nothing watches. Model: `~/code/coworking-mng-not-shit/api/deploy/observability/`,
   with `api/scripts/check-units-manifest.mjs` as the lint that keeps the two in step.

`SyslogIdentifier=<slug>` in the unit is load-bearing — it is the only thing that puts the
service's lines under the right `service_name` label in Loki.

## Worked example (rkfitness, live today)

`rkfitness-api` on `127.0.0.1:54385` ← unit `rkfitness-api.service`
(WorkingDirectory `%h/prod/rkfitness/rkfitness-api`, EnvironmentFile
`%h/.config/rkfitness/api.env`, absolute node, journald id `rkfitness-api`) +
`rkfitness-tunnel.service` (`TUNNEL_TOKEN` in `~/.config/rkfitness/tunnel.env`) →
`https://rkfitness.laserfocused.ee`. DB = native PG16 `127.0.0.1:5641/rkfitness`.
Deploy = `deploy/deploy.sh` in-repo. Backups: manual pre-deploy
`pg_dump | gzip > ~/backups/rkfitness/pre-deploy-<ts>.sql.gz`; nightly-timer model to
clone when asked = `hyperglot-backup.{service,timer}` in `~/.config/systemd/user/`.

## Gotchas

- **NODE_ENV=development is exported in `~/.zshrc` (line ~163)** — it breaks
  `next build` and makes `npm ci` silently drop devDependencies. Build with
  `env -u NODE_ENV npm run build` (or pin `NODE_ENV=production`), and always
  `npm ci --include=dev` in deploy scripts. Never let a build depend on ambient env.
- Absolute node path in `ExecStart` — `/usr/bin/node` is v18, nvm is a shell function.
- `loginctl enable-linger justin` or --user units die on logout (already enabled — verify).
- `~/.cloudflared` must not exist; tunnels are remotely managed. Token in env file, not argv.
- DB/storage never leave the box: the tunnel carries ONLY the app's HTTP port;
  PG 5641 + every Supabase db port stay 127.0.0.1. pg_hba stays peer + scram on loopback.
- Watchdogs start only `inactive` units, never `failed` ones.
- Cloudflare API token is cross-account — always pin `CLOUDFLARE_ACCOUNT_ID` (in `~/.zshrc`).
- systemd --user units don't inherit interactive PATH — set `Environment=PATH=…`
  explicitly if the app shells out (model: `~/.config/systemd/user/hyperglot@speech.service.d/`).
- SQLite backups: python3 `sqlite3.Connection.backup` online API, never `cp` a WAL db;
  the only sqlite3 CLI on this box is in `~/android-sdk`, not on unit PATH.
- Loopback-only API + mobile dev: Android emulator uses `10.0.2.2:<port>`; a physical
  device needs `adb reverse` or an ssh tunnel.
