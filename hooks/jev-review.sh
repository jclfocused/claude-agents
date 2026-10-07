#!/usr/bin/env bash
# PreToolUse: advisory Jev review of git commits and durable-prose writes.
# Silent unless something is worth flagging; exit 2 = advisory deny (repeat the
# identical command to proceed). Fail-open on a missing node, engine or key.
NODE=/home/justin/.nvm/versions/node/v22.22.2/bin/node
ENGINE=/home/justin/ops/infra/jev-review/review.mjs
input=$(cat 2>/dev/null || true)
[ -x "$NODE" ] && [ -f "$ENGINE" ] || exit 0
# ponytail: one jq call (~7 ms) skips the node start (~34 ms) only when runHook() in
# review.mjs provably returns 0 with no output: a tool call that is not
# UserPromptSubmit/Stop, whose Bash command names no `git commit`, gh pr create/edit or
# mem learn, and whose Write/Edit path does not end in "md" (every DURABLE_PROSE branch
# does). Substring tests are a superset of the engine's regexes; anything else runs node.
# Keep in step with runHook() when the engine gains a branch.
skip=$(printf '%s' "$input" | jq -r '
  if type == "object" and (.tool_name | type) == "string" and .tool_name != ""
     and .hook_event_name != "UserPromptSubmit" and .hook_event_name != "Stop"
     and ((.tool_input // {}) | type) == "object"
  then (.tool_input // {}) as $ti
    | if .tool_name == "Bash" then
        ($ti.command | type) == "string"
        and ($ti.command | (contains("git commit")
              or (contains("gh") and contains("pr") and (contains("create") or contains("edit")))
              or (contains("mem") and contains("learn"))) | not)
      elif .tool_name == "Write" or .tool_name == "Edit" then
        ($ti.file_path | type) != "string" or ($ti.file_path | endswith("md") | not)
      else true end
  else false end' 2>/dev/null)
[ "$skip" = true ] && exit 0
printf '%s' "$input" | timeout 9s "$NODE" "$ENGINE" --hook
rc=$?
[ "$rc" = 2 ] && exit 2
exit 0
