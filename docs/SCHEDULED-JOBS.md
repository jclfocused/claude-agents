# Scheduled jobs owned by this repo

Status: inventory + migration plan. Nothing here has been migrated yet; no unit was changed to write it.

## The rule

Recurring work that belongs to this repo is **code in this repo, scheduled by this repo, and installed
by the same action that ships the code**. A hand-written `.service`/`.timer` pair that only ever
existed in `~/.config/systemd/user/` is the anti-pattern: the repo does not know it exists, nothing
tests it, nothing re-creates it, and its schedule can drift from the script it runs without a single
diff being visible. On **2026-09-15** twenty-five such hand-made unit files on this box were found
truncated to 0 bytes; every backup, drain and watchdog they scheduled had stopped silently and only
came back because other units happened to be symlinks into a git checkout. The units in the table
below are in exactly that unprotected category — real files, hand-written, no repo copy. The fix is
not "back up the unit files", it is that the repo owns the unit definition and an installer re-renders
it, so a lost or corrupted unit is restored by re-running a deploy rather than by archaeology.

For this repo, "deploy" is `git pull` in place: the working tree **is** `~/.claude`. That does not
weaken the rule, it just names the mechanism — an idempotent installer committed alongside the script,
run after a pull, is this repo's equivalent of a framework's scheduler registration.

### Two problems, not one

1. The units are hand-made and untracked (the table's "Unit lives" column).
2. **`automation/` is not tracked either.** `.gitignore` ignores `*` and re-admits an allowlist
   (`docs/`, `skills/`, `commands/`, `agents/`, `custom_plugins/`, …). `automation/` is not on it, so
   `git check-ignore automation/vendor-outreach-watch.sh` reports it ignored and `git ls-files
   automation/` returns zero files. **Nothing in `automation/` — no wrapper, no prompt, no
   installer — is in git today.** A migration that only tracks the units still leaves the scripts
   they run outside version control, so the allowlist change is part of the same work.

`automation/README.md` is the current lane note. It is untracked, and it lists Mac ping and Hyperglot
health as "timer" when both are in fact crontab entries. This document supersedes it as the inventory.

## What this repo schedules today

Two systemd timers and five crontab entries. All seven run scripts under `~/.claude/automation/`.

| Job | Schedule | What it does | Unit lives | What depends on it not stopping |
|---|---|---|---|---|
| `vendor-outreach-watch` | `OnCalendar=Mon..Fri *-*-* 08..19:00,30 Europe/Tallinn` + `Mon..Fri *-*-* 20:00`, `Persistent=false` | Runs `automation/vendor-outreach-watch.sh`: a headless `claude -p` lane (pinned `claude-opus-5`, `--strict-mcp-config`, `cd ~/code/coworking-mng-not-shit`) that polls the tracked integration-vendor mail threads and replies inside `automation/vendor-outreach/PROMPT.md`'s policy. | `~/.config/systemd/user/vendor-outreach-watch.{service,timer}` — hand-made real files, in no repo | The one lane holding a **scoped exception to the outbound-send gate**. If it stops, vendor replies sit unanswered and unescalated; nobody is told, because the thing that would tell you is the staleness cron below. |
| `vendor-outreach-digest` | `OnCalendar=Mon..Fri *-*-* 18:00 Europe/Tallinn`, `Persistent=false` | Same script, `Environment=DIGEST=1` — the end-of-day summary of the tracked vendor threads. | `~/.config/systemd/user/vendor-outreach-digest.{service,timer}` — hand-made real files, in no repo | Justin's only scheduled readout of a lane that is otherwise autonomous and can send mail. Losing it means the lane keeps acting and stops reporting — the worse of the two failure modes. |
| `vendor-outreach-stale` | crontab `5 * * * *` (hourly) | `automation/vendor-outreach-stale.sh` — alerts to `logs/alerts.log` if `state/vendor-outreach/last-run` is older than 2h inside the lane's own window (Mon–Fri 10:00–20:00 Tallinn). | crontab only, no unit | **This is the watchdog for the two jobs above.** It is the only thing that notices a stopped timer or a wedged lock dir. |
| `mac-ping` | crontab `*/15 * * * *` | `automation/mac-ping.sh` — SSH reachability of the Mac build box, logs up→down/down→up transitions only, with quiet hours and an N-tick debounce. | crontab only, no unit | Notice that Apple-only work (builds, TestFlight, simulators) has no machine, before a lane discovers it mid-run. |
| `hyperglot-health` | crontab `0 7 * * *` | `automation/hyperglot-health.sh` — probes `api.hyperglot.io/health`, `app.hyperglot.io`, `hyperglot.io`; failures to `alerts.log`. | crontab only, no unit | External uptime signal for a deployed product. |
| `mya-timelog` | crontab `40 * * * *` (hourly) | `automation/mya-timelog.py` — recomputes MyArchitectAI engaged work time from Claude Code transcripts per day per Linear issue and syncs a Google Sheet via rclone. Stateless full recompute. | crontab only, no unit | **Billing input.** Silent failure yields a sheet that looks current and is stale — invoiced hours drift with no error anywhere. |
| `os-refine-weekly` | crontab `30 5 * * 0` (Sun 05:30) | `automation/os-refine-weekly.sh` — headless `os-refine` pass: persona refresh, observation-log drain, OS audit. Pinned `claude-opus-5`. | crontab only, no unit | The OS's own maintenance loop; skills and persona quietly stop being refined. |

Not owned here: `punch-sweep.timer` and `punch-miners.timer` write into this tree's paths but belong
to the **punch** plugin repo, which already installs its own units from code (see below). Do not
adopt them into this repo's installer.

### Known quirks worth carrying into the migration, not re-creating

- **18:00 collision.** `vendor-outreach-watch.timer`'s `08..19:00,30` range already includes 18:00, and
  `vendor-outreach-digest.timer` also fires at 18:00. The wrapper takes a `mkdir` lock, so whichever
  loses appends a `SKIPPED — lock held` line to `alerts.log` rather than running. The pair works by
  collision, not by design.
- **`DIGEST` is derived twice.** `vendor-outreach-watch.sh:27` already sets `DIGEST=1` when the Tallinn
  hour is 18 and the minute is < 15, so `Environment=DIGEST=1` in the digest unit is belt-and-braces.
  One of the two should own the decision after migration.
- The two vendor units are **one script distinguished only by an environment variable**. They move
  together or not at all.

## Migration target, per job

The mechanism below is not a proposal in the abstract — it is the pattern already running on this box,
verified in the punch plugin: unit **templates committed in the repo** (`infra/punch-sweep.service`,
`infra/punch-sweep.timer`) carrying `__NODE__`/`__PUNCH__` placeholders, and an installer command
(`punch install-sweeper`, `bin/punch:1253`) that renders them with real absolute paths, writes them to
`~/.config/systemd/user/`, then runs `systemctl --user daemon-reload` and `enable --now`. The unit on
the box becomes a rendered artifact of repo code. That is what this repo should copy.

| Job | Target | Owning file(s) |
|---|---|---|
| `vendor-outreach-watch` + `vendor-outreach-digest` | **Migrate together.** Commit both unit pairs as templates and install them from code. Resolve the 18:00 collision and the double `DIGEST` derivation in the same change — either one timer whose 18:00 shot is the digest (the script already detects it), or two timers with non-overlapping calendars. | `automation/infra/vendor-outreach-watch.{service,timer}`, `automation/infra/vendor-outreach-digest.{service,timer}` (templates), installed by `automation/install.sh` |
| `mya-timelog` | Move from crontab to a repo-owned timer template + installer entry, same as above. Billing input should fail loudly: it needs a run log line and a staleness check on its last successful sheet sync, neither of which exists today. | `automation/infra/mya-timelog.{service,timer}`, `automation/mya-timelog.py` |
| `os-refine-weekly` | Same: crontab → repo-owned timer template + installer entry. `Persistent=true` is the right setting for a weekly job (a box asleep at 05:30 Sunday currently just skips the week). | `automation/infra/os-refine-weekly.{service,timer}` |
| `vendor-outreach-stale` | **Stays a host-level job — but tracked.** It is the watchdog for the vendor lane; it must keep running when the lane is wedged, dead, or mid-migration, so it does not get folded into the thing it watches and must not share its lock, its log, or its unit. Commit its template and install it from the same installer, but keep it a separate, independently-scheduled unit. | `automation/infra/vendor-outreach-stale.{service,timer}` |
| `mac-ping` | **Stays a host-level job.** External-level monitoring of a machine this box does not run: its entire purpose is to report when the target is down. Track the template, keep it independent. | `automation/infra/mac-ping.{service,timer}` |
| `hyperglot-health` | **Stays a host-level job** for the same reason — it probes a deployed product from outside, and an in-app scheduler cannot report that the app is unreachable. Long term this belongs with the external monitoring stack rather than here; until then, track the template and keep it independent. | `automation/infra/hyperglot-health.{service,timer}` |

Prerequisite for every row: add `!automation/` + `!automation/**` to the `.gitignore` allowlist (keeping
`automation/logs/`, `automation/state/` and `automation/.vendor-outreach.lock` excluded — they are
runtime, owner-only, and the lane writes credentials-adjacent files into `state/`). Without this, the
installer and the templates would themselves be untracked, which is the bug.

Open question, not for this phase: `vendor-outreach` is described in its own unit as the *Kommonz*
vendor-outreach watcher and runs with `cwd=~/code/coworking-mng-not-shit`. Per Justin's 2026-09-15
directive, a Kommonz business job belongs in the Kommonz repo. Its assets (prompt, `gmail.mjs`, state,
persona) all live here and it is an agent lane rather than application code, so this document assigns
it here for now. If the lane grows into Kommonz business process, re-home the whole lane rather than
splitting the schedule from the script.

## Definition of done for a migration

A job has finished migrating when all five hold:

1. **Defined in code.** The unit exists as a template committed in this repo; the copy in
   `~/.config/systemd/user/` is a rendered artifact, reproducible from the repo alone.
2. **Installed by the deploy.** One idempotent `automation/install.sh` renders every template, runs
   `systemctl --user daemon-reload`, and `enable --now`s each timer. Re-running it after a `git pull`
   is safe and is the documented step. Deleting a unit file and re-running restores it byte-identical.
3. **Has a log line.** Every run appends a structured start/exit line to `automation/logs/<lane>.log`
   and a failure line to `logs/alerts.log`. No lane's success is inferred from the absence of noise.
4. **Has an alert or a staleness check.** Either an `ExecStopPost` failure line *and* a last-run stamp
   with a watcher (the `vendor-outreach-stale.sh` shape), or an explicit statement in this file of why
   the job needs neither. A timer that stops and takes its own alerting with it is the exact
   2026-09-15 failure.
5. **The old scheduler is retired in the same change.** The crontab line is removed, or the hand-made
   unit is replaced by the rendered one, in the same commit that adds the code — never left running in
   parallel. Two schedulers for one job is how a lane ends up firing twice or not at all.

Migration is done per job, verified by: stop the timer, delete the unit file, re-run the installer,
confirm `systemctl --user list-timers` shows it back with the same next-elapse, and confirm one real
log line from a manual `systemctl --user start <unit>`.
