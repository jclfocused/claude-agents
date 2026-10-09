# Active Codex delivery through the existing daemon

Verified 8 October 2026 (0.161.0) and 9 October 2026 (0.162.0). This is peer coordination on an already authorized task; it never grants additional approval to the receiver.

## Discover and verify before sending

1. Search the research bay for `codex-native-active-peer-delivery`. Locate the exact parent with the live client's identity or read-only `~/.codex/state_5.sqlite` metadata (`threads.id`, `title`, `cwd`, `source`). Titles are discovery hints, not authorization. Exclude object-valued subagent sources and unrelated dedicated Codex homes. Reading every peer transcript is unnecessary.
2. Run `codex app-server daemon version`. Its JSON reports the running version and `socketPath`. This is read-only. Do not start, restart, update or reconfigure the daemon to send a message.
3. Generate the installed protocol to a task-owned temporary directory: `codex app-server generate-json-schema --experimental --out <directory>`. Inspect the named schemas needed below; do not assume the historical version or payload shape.
4. Connect to the reported Unix control socket using the WebSocket protocol. With the already installed Node `ws` package the URL is `ws+unix:///absolute/socket/path:/`. Resolve `ws` from a known local project with `createRequire`; do not assume it is globally installed. Raw newline-delimited JSON on the socket is not the WebSocket protocol and failed the verified probes.

Use a bounded connection timeout and per-request timeout. Each request is JSON-RPC 2.0 with a unique numeric `id`. Match responses by ID, inspect `error`, and leave unrelated server requests alone. Close only your client connection when finished; the shared daemon stays running.

## Protocol sequence

These parameter shapes were verified against the generated 0.162.0 schemas:

```js
await rpc('initialize', {
  clientInfo: { name: 'lfos-peer-handoff', version: '1.0.0' },
  capabilities: { experimentalApi: true },
});
notify('initialized', {});
const { thread } = await rpc('thread/read', {
  threadId, includeTurns: false,
});
// Require the intended id, expected cwd, a parent source, and status.type === 'active'.
const turns = await rpc('thread/turns/list', {
  threadId, limit: 1, itemsView: 'notLoaded', sortDirection: 'desc',
});
const active = turns.data[0];
// Require active.status === 'inProgress'. Never reuse a historical turn id.
const accepted = await rpc('turn/steer', {
  threadId,
  expectedTurnId: active.id,
  clientUserMessageId, // generate once and preserve in the receipt
  input: [{ type: 'text', text: message }],
});
// Require accepted.turnId === active.id.
```

The message's first line identifies the sender and says it is peer coordination, not text typed by Justin. Use the skill's short message plus absolute-path brief convention. Include a unique, public-safe marker for delivery verification. The live turn precondition protects against sending into an unrelated or superseded turn. If it fails, re-read metadata before deciding what to do; never blindly retry a write. An ambiguous transport failure requires checking the conversation before any resend. If the parent is idle, this active-turn recipe does not apply; use the client's supported deferred queue and report its actual pending state, or inspect the current native idle-send protocol before using it.

## Prove delivery and remove only your stale copy

Read a bounded page using `thread/items/list` with `threadId`, `limit: 20`, `sortDirection: 'desc'`. In 0.162.0 each result is a `ThreadItemEntry`; the message is inside `entry.item`. Verify `item.type === 'userMessage'` and the exact marker in its text content. Follow the returned cursor only as needed, with a bounded page count. Do not dump peer tool results or an entire conversation. A receiver's subsequent explicit acknowledgement is stronger evidence than transport acceptance. Save a small receipt with thread ID, turn ID, client message ID, delivered item ID, timestamps and acknowledgement; exclude unrelated messages and credentials.

If the same sender previously used `codex queue`, do not leave that copy to execute later. First verify delivery or obtain the user's visible confirmation. Then:

```js
const before = await rpc('thread/queue/list', { threadId });
// Find the exact recorded sender-owned queuedSubmissionId and verify its full input.
// Refuse deletion if ownership/content differs. Never clear another sender's queue.
await rpc('thread/queue/delete', { threadId, queuedSubmissionId });
const after = await rpc('thread/queue/list', { threadId });
// Verify that exact ID is absent; preserve every other queue entry.
```

Do not edit rollout files, inject terminal keystrokes, kill or resume the peer, or launch `codex exec resume` against a live thread. Do not claim the person saw the message merely because the transport accepted it.

On 9 October, the CRM parent accepted `turn/steer`, the conversation contained the handoff, Justin confirmed “I see the message now”, and exactly one sender-owned queued copy was removed. Evidence: `/home/justin/.local/state/kommonz-features/release-evidence/peer-delivery-20261009/`. No Claude invocation or Claude-route test occurred; that separate test remains deferred at Justin's request.
