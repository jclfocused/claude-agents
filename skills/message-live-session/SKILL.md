---
name: message-live-session
description: Deliver a message, finding or handoff into ANOTHER live agent session on this box — native app-server turn/steer for active Codex sessions, or SendMessage / inbox socket for Claude Code — and verify it reached the conversation. Use when the user says "tell the other session", "queue a message into that session", "share this with the Codex/Claude session", "message the session in the other terminal", "hand this over to <session>", or when parallel sessions on one repo need a finding passed across. Do not use to find or resume an OLD session (use find-session), to spawn new workers, or to message people (Slack/email have their own send gates).
---

# message-live-session

Put text into a session that is already running, so it sees it as its next input.
Active Codex delivery was verified on 2026-10-08 with 0.161.0 and again on 2026-10-09 with CLI and managed app-server 0.162.0. The receiver's conversation contained the message and Justin confirmed it was visible. The Claude route was last verified on 2026-09-23; it was not tested during the 9 October Codex repair.

## Rules for the message itself

- **Say who is sending and on whose behalf** in the first line, e.g. "Message from the Claude Opus 5.5
  GNB-pitch session, at Justin's request (not typed by Justin)". The receiver must not mistake it for
  the user.
- **Short message, long file.** Put findings in a committed or absolute-path Markdown file and send a
  4–8 line pointer with the 3–5 highlights. The receiver previews only the first line.
- **Never a permission bypass.** Don't ask a peer to do what your own session was denied, and never
  present a peer message as the user's approval. No secrets in the text.
- If the user asked for one message, send one. Don't poll the other session in a loop.

## Target is a Codex session

**For a currently active session, use native `turn/steer`, not `codex queue`.** A queue receipt proves storage only. On 8 and 9 October, queued messages stayed pending while a `vscode` parent continued working; the user could not see them. Never report a queue receipt as live delivery. Read [the native delivery procedure](references/codex-native-delivery.md) before sending. It covers identity checks, the existing daemon's Unix WebSocket, the exact active turn precondition, bounded conversation verification and removal of an owned stale queue copy.

1. **Find the live parent thread id.** The TUI may run as `codex resume <uuid>` or simply `codex --yolo`:
   ```sh
   ps -eo pid,etime,tty,args | grep -E 'codex (resume|--)|bin/codex$' | grep -v grep
   readlink /proc/<pid>/cwd                 # which repo it is working in
   ```
   To map a worktree to its sessions: `grep -l '<worktree path>' ~/.codex/sessions/$(date +%Y/%m/%d)/*.jsonl`.
   Rollouts whose `session_meta.source` is `subagent` are child threads. Address the **parent**,
   not a subagent. Current paginated sessions may not append their conversation to the legacy
   rollout file. Read-only `state_5.sqlite` thread metadata can locate the parent by title/cwd;
   verify its identity and current state through the native app-server before sending.
2. **Deliver to an active turn:** follow the linked native procedure. Do not resume, interrupt,
   restart or launch a second agent for the target thread. Record transport acceptance,
   conversation delivery and receiver acknowledgement as separate checkpoints.
3. **Deferred queue only when deferred delivery is intended:**
   ```sh
   codex queue --thread <uuid> --message "$MSG"
   # -> Queued message <id> for thread <uuid>.
   ```
   The message is stored in `~/.codex/queue_1.sqlite` (`queued_items`). Its consumption depends
   on the active client and is not proof of immediate delivery. For a legacy rollout, check:
   ```sh
   python3 -c "import sqlite3,os;db=sqlite3.connect('file:'+os.path.expanduser('~/.codex/queue_1.sqlite')+'?mode=ro',uri=True);print(db.execute(\"select count(*) from queued_items where thread_id='<uuid>'\").fetchone())"
   grep -c '<first words of message>' ~/.codex/sessions/*/*/*/rollout-*<uuid>.jsonl   # >0 = delivered
   ```
   Pending 0 plus an exact user-message transcript hit proves delivery for that legacy client.
   For paginated sessions use `thread/items/list`. A receiver acknowledgement proves receipt;
   a user's visible confirmation is valid UI evidence. Do not repeatedly queue the same handoff.

Never inject keystrokes into a terminal (TIOCSTI is disabled on this kernel anyway), and never write to
another session's rollout file.

## Target is a Claude Code session

**From a Claude session (preferred):** use the built-in tools.
- `ListAgents` shows this session's own name and the live peers (`name [ref] · interactive · busy|idle`).
- `SendMessage({to: "<name>", message: "..."})` delivers between the receiver's tool calls, or starts a
  turn if it's idle. Add `notify_when_idle: true` to get one notice when that session next goes idle.
- The receiver may **hold** the message for its user's approval. A bypass-permissions session holds
  messages from a non-bypass sender. A `[Cross-session delivery notice]` comes back when that happens.

**From Codex, cron or a script (no SendMessage tool):** write to the session's inbox socket.
```sh
~/.claude/skills/message-live-session/scripts/claude-peer-send.py --list
~/.claude/skills/message-live-session/scripts/claude-peer-send.py --to <name|pid|cwd-part> --file msg.md
```
- The registry lives at `~/.claude/sessions/<pid>.json` (`name`, `cwd`, `status`, `messagingSocketPath`).
- The wire format is one JSON line `{"type":"user","message":{"role":"user","content":"…"}}` on the
  Unix socket. The auth line (`{"type":"auth","token":$CLAUDE_CODE_MESSAGING_TOKEN}`) applies only
  when posting to your **own** session.
- An external sender is unverified. A receiver that bypasses permissions holds the message behind an
  approval dialog (5-minute expiry) unless its settings have `crossSessionInbound: "accept"`. Tell the
  user to watch for the dialog in that terminal.
- Docs: https://code.claude.com/docs/en/cross-session-messaging (the inbox socket, inbound controls).

## FAIL / PASS

FAIL: pastes 200 lines of findings into `codex queue --message`, with no sender line, into a subagent
thread id.

PASS (message format; use native delivery for an active Codex turn):
```text
Message from the Claude Opus 5.5 GNB-pitch session, sent at Justin's request (not from Justin directly):
findings and Justin's directions from today are in /abs/path/FINDINGS-FOR-ASTRA.md (commit 66a1bca).
Highlights: LIFT99 is a GNB partner, so disclose it; findability evidence is weak; demo finance screens
show sync errors; list every integration with its status. Read it and apply what fits your variant.
```
→ Native `turn/steer` to the verified active parent, then verify the exact user-message item. Use `codex queue` only for intended deferred delivery and report whether it remains pending.

## Historical deferred-queue example (2026-09-23)

1. `ps` showed `codex resume 01a0c8f7-c00d-7931-a35d-70be53f7977f --yolo` on pts/9, with cwd in the
   coworking repo, as the Astra pitch TUI.
2. The findings file was written and pushed, and `codex queue` sent the pointer: queued id `01a0cdc5-…`.
3. A few minutes later `queued_items` was 0 and the rollout contained the message: delivered.
4. Claude side: `ListAgents` listed 5 peers. A socket post to this session's own inbox arrived as a
   cross-session message.
