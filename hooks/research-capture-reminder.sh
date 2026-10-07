#!/usr/bin/env bash
# Fires after every Workflow tool call (global). Injects the research-capture rule
# so it is in context when the workflow's results land. See global CLAUDE.md
# "Research & learning capture" — this hook exists because prose alone was missed
# (2026-07-29): the trigger moment is results landing, and the harness now binds it.
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"RESEARCH-CAPTURE RULE (harness-enforced, global CLAUDE.md): when this workflow's results land, any research-type lane (external knowledge — web/market research, design-pattern sweeps, API/tool/library learnings) MUST be saved to the research bay in that SAME turn, before synthesis: extract the lane text from the task output file and pipe it into `mem learn <slug> --title \"…\" --summary \"…\" --question \"…\"`. Repo-internal lanes (own architecture/code/billing inventories) go to repo docs or auto-memory instead, never the bay. Do not wait to be asked."},"suppressOutput":true}
JSON
