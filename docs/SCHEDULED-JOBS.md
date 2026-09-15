# Scheduled jobs — claude-agents (`~/.claude`)

Inventory phase, 2026-09-15. Nothing here has been migrated; no unit was stopped, edited or
disabled. This document records what this repo schedules today, where it actually lives, and what
the migration target is.

## The rule

Recurring work belongs in the repo that owns it, as code, scheduled by that repo's own mechanism and
shipped by its normal deploy — so the repo knows about every job it runs, the schedule is reviewed
like any other diff, and a rebuild reproduces it. A hand-written `.service`/`.timer` pair that exists
only in `~/.config/systemd/user` is the anti-pattern: it is invisible to the repo, tested by nobody,
versioned in practice by nobody, and recoverable from no git history. On **2026-09-15** twenty-five
hand-made unit files on this box were found truncated to 0 bytes; every backup, drain and watchdog
they scheduled had silently stopped, and the only reason they came back is that other repos had
tracked copies. This repo had none. The exception is genuinely external-level
monitoring/watchdog/backup infrastructure, which must keep running when the thing it watches is
down — that may stay host-scheduled, but its *files* still live in a repo.

## What this repo schedules today

Verified 2026-09-15 by reading `~/.config/systemd/user/*.{service,timer}`, `systemctl --user
list-timers` and `crontab -l`.

| Job | Schedule | What it does | Where it lives now | What depends on it not stopping |
|---|---|---|---|---|
| `vendor-outreach-watch.timer` | Mon–Fri `08..19:00,30` + `20:00` Europe/Tallinn, `Persistent=false` | Runs `automation/vendor-outreach-watch.sh`: a headless `claude -p` lane (model pinned `claude-opus-5`, `--strict-mcp-config`, loads `justin-persona`) that polls the integration-vendor mail threads via `vendor-outreach/gmail.mjs` and handles replies per `vendor-outreach/PROMPT.md`. Carries a **scoped exception to the outbound-send gate**: it may send on the tracked threads only; everything else escalates to Telegram. `DRY_RUN=1` polls and composes without sending. Single-flight via a `mkdir` lock; state and logs are `umask 077`. | **Hand-made real file** in `~/.config/systemd/user/` (not a symlink). The script, prompt and `gmail.mjs` are in `automation/` — **also untracked** (see below). | Highest-consequence orphan in this repo, because the lane can send email as Justin. Two directions: silently stopping means vendor replies go unanswered mid-negotiation with nobody noticing; an untracked unit means a schedule or environment change is reviewed by no one and recoverable from no history. |
| `vendor-outreach-digest.timer` | Mon–Fri `18:00` Europe/Tallinn | Same script with `DIGEST=1` — the end-of-day digest shot. (The script also derives `DIGEST` from the clock, so the 18:00 watch shot is a digest even if this unit is missing.) | Hand-made real file in `~/.config/systemd/user/`. | The daily summary of thread state. Lower blast radius than the watcher, same ownership gap. |
| `vendor-outreach-stale.sh` | cron hourly `5 * * * *` | Watchdog: alerts if `state/vendor-outreach/last-run` is >2h old inside the send window (Mon–Fri 10:00–20:00 Tallinn), appending to `automation/logs/alerts.log` and pushing an urgent Telegram message. This is the one line that watches the watcher. | User crontab + untracked script. | It is the only staleness detection for the watcher. If it stops, a stopped watcher becomes invisible again. |
| `os-refine-weekly.sh` | cron `30 5 * * 0` (Sun 05:30) | Headless `os-refine` pass: persona refresh, observation-log drain, OS audit. Model pinned `claude-opus-5`. | User crontab + untracked script. | Weekly drift correction of the OS/persona. Degrades slowly and silently — nothing alerts on a missed run. |
| `mac-ping.sh` | cron `*/15 * * * *` | Probes the Mac build machine over SSH, logs up→down / down→up transitions to `alerts.log`, with `DOWN_TICKS` debounce (~2h) because the clamshell naps. | User crontab + untracked script. | Notice that the Apple build box is unreachable before a build needs it. |
| `hyperglot-health.sh` | cron `0 7 * * *` | Nightly probe of `api.hyperglot.io/health` and `app.hyperglot.io`; failures to `alerts.log`. | User crontab + untracked script. | Overnight detection of a dead hyperglot endpoint. |
| `mya-timelog.py` | cron `40 * * * *` | Recomputes MyArchitectAI engaged work time from Claude Code transcripts (sessions + subagents) per day per Linear issue and syncs a Google Sheet via rclone. | User crontab + untracked script. | Billable time records for MyArchitectAI. A silent stop means hours are simply not recorded. |

**Not this repo's:** `punch-sweep.timer` and `punch-miners.timer` execute out of
`~/.claude/plugins/cache/punch/punch/0.1.0/bin/punch` — an installed plugin artifact. They are owned
by the `punch` repo and are inventoried there, not here.

**The gap is wider than the units.** `git ls-files '*.timer' '*.service'` returns zero, as expected —
but `.gitignore` in this repo ignores `*` and allowlists only `CLAUDE.md`, `docs/`, `commands/`,
`agents/`, `skills/`, `agent_descriptions/`, `.claude-plugin/`, `custom_plugins/`, `README.md`.
`automation/` is therefore **entirely untracked**: the wrapper scripts, `vendor-outreach/PROMPT.md`
(which is the send policy for a lane that emails on Justin's behalf), `gmail.mjs`, and the lane table
in `automation/README.md`. `git check-ignore -v automation/vendor-outreach-watch.sh` confirms it,
matching line 2 (`*`). `automation/README.md` already drifted from reality as a result — it lists
Mac-ping and hyperglot-health as "timer" when both are cron.

### Quirks to carry into the migration, not re-create

- **18:00 collision.** `vendor-outreach-watch.timer`'s `08..19:00,30` range already covers 18:00 and
  18:30, and `vendor-outreach-digest.timer` also fires at 18:00. The wrapper takes a `mkdir` lock, so
  whichever loses appends a `SKIPPED — lock held` line to `alerts.log` instead of running. The pair
  works by collision, not by design.
- **`DIGEST` is decided twice.** `vendor-outreach-watch.sh:27` already sets `DIGEST=1` when the
  Tallinn hour is 18 and the minute is < 15, so `Environment=DIGEST=1` in the digest unit is
  belt-and-braces. One of the two should own the decision after the migration.
- The two vendor units are **one script distinguished only by an environment variable**. They move
  together or not at all.

## Migration target

There is **no application framework in this repo and none should be invented.** `claude-agents` is a
configuration/skill repo consumed by the Claude Code harness; it runs no server, so there is no
process to host an in-process scheduler. Standing up a Node daemon purely to own a cron expression
would be strictly worse than what exists. systemd stays the scheduler. What changes is that the
**repo owns the unit files and the scripts**, and installs them by symlink — exactly the pattern
`ops` already uses for its 16 tracked timers (`ops/infra/install.sh`: `ln -sfn "$ROOT/infra/<unit>"
"$UNIT_DIR/<unit>"`, then `daemon-reload` + `enable`), and the pattern every `~/prod/<app>/deploy/`
unit on this box already follows.

Mechanism, once:

- `.gitignore` gains `!automation/` + `!automation/**`, minus the runtime dirs
  (`automation/logs/`, `automation/state/`, `automation/.*.lock`) which must stay ignored — they are
  `umask 077` and contain thread state.
- `automation/units/` holds the tracked `.service` / `.timer` files.
- `automation/install.sh` symlinks them into `~/.config/systemd/user/`, runs `daemon-reload`, and
  enables each — idempotent, re-runnable, and the single documented way to reinstall the box's
  agent lanes.
- Cron entries become timers under the same installer, so one mechanism covers everything and
  `crontab -l` stops being an undocumented second scheduler. A tracked `automation/crontab` is the
  weaker fallback if any job turns out to need cron semantics.

Per job:

| Job | Target file in this repo | Notes |
|---|---|---|
| `vendor-outreach-watch` | `automation/units/vendor-outreach-watch.{service,timer}` + the already-present `automation/vendor-outreach-watch.sh` and `vendor-outreach/PROMPT.md`, all tracked | Do this one first. The send policy and the schedule of an email-sending lane both belong under review. |
| `vendor-outreach-digest` | `automation/units/vendor-outreach-digest.{service,timer}` | Same change, same commit. |
| `vendor-outreach-stale` | `automation/units/vendor-outreach-stale.{service,timer}` | **Stays host-scheduled** — watchdog class. It must fire when the watcher is dead, so it may not share the watcher's process, lock or lifetime. Its file still lives here. |
| `os-refine-weekly` | `automation/units/os-refine-weekly.{service,timer}` | Genuinely this repo's work — an OS/persona maintenance lane. |
| `mac-ping` | `automation/units/mac-ping.{service,timer}` | **Stays host-scheduled** — external-level probe of a machine that is by definition sometimes down. Candidate to move to `ops/infra/watchdogs/` where `lfos-mem-watch` and friends already live and where the collector already tails `alerts.log`; Justin's call, not made here. |
| `hyperglot-health` | `automation/units/hyperglot-health.{service,timer}` | **Stays host-scheduled** — same reasoning; it probes hyperglot from outside. Same open question about `ops/infra/watchdogs/` or the hyperglot repo owning it. |
| `mya-timelog` | Owning repo is arguably **myarchitectai**, not this one — it produces billable time records for that product. It is box-coupled (it reads Claude Code transcripts from `~/.claude/projects`), so it stays host-scheduled wherever it lands. Open call. | Until that is decided, tracking it here beats the status quo of tracking it nowhere. |

Alerting already partly exists and should be preserved rather than rebuilt: every wrapper appends a
failure line to `automation/logs/alerts.log`, and `ops/packages/collector/src/adapters/alerts-tails.ts`
tails that exact path, so failures surface on the ops dashboard. The vendor-outreach lane is the only
one with a positive staleness check (`state/vendor-outreach/last-run` + the hourly stale script); the
others alert on failure but not on silence. No `manifest.yaml` row in `ops` mentions vendor-outreach —
a unit nothing watches is the failure mode this whole exercise exists to close.

## Definition of done (per job)

1. The unit and the script it runs are **tracked in this repo**, and `automation/install.sh` installs
   them by symlink — so `~/.config/systemd/user/<unit>` is a link into the checkout, never a real file.
2. A fresh install reproduces the job from the repo alone: clone, run the installer, and the timer is
   scheduled with the same calendar, the same environment and the same lock.
3. The job emits **one structured log line per run** (start, outcome, duration) to
   `automation/logs/<lane>.log` and a failure line to `alerts.log`.
4. It has a **staleness check, not only a failure check** — a `last-run` stamp plus something that
   alerts when the stamp goes cold inside the job's own window, the way `vendor-outreach-stale.sh`
   already does. A job that stops being scheduled produces no failure line at all; that is exactly
   how 2026-09-15 stayed silent.
5. The hand-made host file is **retired in the same change** that lands the tracked one — removed
   from `~/.config/systemd/user/` and replaced by the symlink, with `daemon-reload` run and
   `systemctl --user list-timers` showing the job still on its schedule. Two copies of a unit is
   worse than one untracked copy.
6. For anything marked **stays host-scheduled**: say so in this table with the reason, and confirm it
   does not depend on the app it watches being up.
