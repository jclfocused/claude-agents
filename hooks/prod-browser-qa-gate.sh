#!/usr/bin/env bash
# PreToolUse gate (Bash): no merge into a production branch without a real-browser QA verdict.
# Justin, 2026-10-11: "before anything goes prod it should get full real browser testing with codex sol 6.1
# or even astra". A `gh pr merge` whose PR targets main/master/production must carry, in the command text,
#   BROWSER_QA=<path to the Sol/Astra verdict file or directory>   (must exist)
# The file (or one file in the directory) must carry both a `UI VERDICT: APPROVE` line and an overall
# `VERDICT: APPROVE` line (Justin, 2026-10-15: browser QA always includes a UX/UI review; rubric
# ~/.claude/skills/sandbox-verify/references/ux-ui-review.md). Test: prod-browser-qa-gate.test.sh.
#   BROWSER_QA=none:<reason>                                        (docs-only, infra-only, non-UI service)
# The PR's base is read live with `gh pr view`; if that lookup fails the merge is allowed and the lookup
# failure is logged, so a GitHub hiccup never wedges unrelated work. Cron/systemd jobs are not tool calls
# and are unaffected (the lfos-build maintenance job merges its own PRs).
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
printf '%s' "$cmd" | grep -Eq '\bgh[[:space:]]+pr[[:space:]]+merge\b' || exit 0
deny() { jq -n --arg r "Production gate: $1 — nothing merges to production without a real-browser QA pass by Codex Sol 6.1 (or Astra when Justin names it): add BROWSER_QA=<verify-shots/<lane>/BROWSER-QA.md> (existing file, or a directory holding one, with a UX/UI review and both UI VERDICT: APPROVE and VERDICT: APPROVE lines) or BROWSER_QA=none:<reason> (docs-only, infra-only, non-UI) to the merge command. Rubric: ~/.claude/skills/sandbox-verify/references/ux-ui-review.md; see ~/.claude/skills/lean-lanes/SKILL.md § Production gate." '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0; }
log() { printf '%s\t%s\tprod-browser-qa-gate: %s\n' "$(date +%s)" "$(date -Is)" "$1" >> "${PROD_BROWSER_QA_GATE_LOG:-/home/justin/.claude/automation/logs/alerts.log}"; }

ref=$(printf '%s' "$cmd" | grep -oE 'gh[[:space:]]+pr[[:space:]]+merge[[:space:]]+([^[:space:]-][^[:space:]]*)' | head -n 1 | awk '{print $4}')
repo=$(printf '%s' "$cmd" | grep -oE '(--repo|-R)[[:space:]]+[^[:space:]]+' | head -n 1 | awk '{print $2}')
dir=$(printf '%s' "$cmd" | grep -oE '(^|[;&|][[:space:]]*)cd[[:space:]]+[^[:space:];&|]+' | head -n 1 | sed -E 's/.*cd[[:space:]]+//'); dir="${dir/#\~/$HOME}"
args=(pr view); [ -n "$ref" ] && args+=("$ref"); [ -n "$repo" ] && args+=(--repo "$repo"); args+=(--json baseRefName --jq .baseRefName)
base=$(cd "${dir:-.}" 2>/dev/null && env -u GITHUB_TOKEN -u GH_TOKEN timeout 20 gh "${args[@]}" 2>/dev/null)
if [ -z "$base" ]; then log "ALLOW (base lookup failed) ref=${ref:-cwd} repo=${repo:-cwd}"; exit 0; fi
case "$base" in main|master|production|prod) ;; *) exit 0 ;; esac

qa=$(printf '%s' "$cmd" | grep -oE 'BROWSER_QA=[^[:space:]]+' | head -n 1 | cut -d= -f2-)
[ -z "$qa" ] && deny "PR ${ref:-?} targets $base and the command carries no BROWSER_QA"
case "$qa" in
  none:*) [ ${#qa} -gt 6 ] || deny "BROWSER_QA=none: needs a reason"; log "ALLOW none ref=${ref:-cwd} base=$base reason=${qa#none:}"; exit 0 ;;
esac
p="${qa/#\~/$HOME}"; [ "${p:0:1}" = "/" ] || p="${dir:-$PWD}/$p"
[ -e "$p" ] || deny "BROWSER_QA path $qa does not exist"
# A line whose first word is VERDICT (markdown bullets/bold allowed) is the overall verdict; UI VERDICT is the UX/UI one.
approved() { grep -Eq '^[^[:alnum:]]*VERDICT:[^[:alnum:]]*APPROVE' "$1" && grep -Eq '^[^[:alnum:]]*UI VERDICT:[^[:alnum:]]*APPROVE' "$1"; }
if [ -d "$p" ]; then
  ok=; while IFS= read -r -d '' f; do approved "$f" && { ok=1; break; }; done < <(find "$p" -maxdepth 2 -type f -name '*.md' -print0)
  [ -n "$ok" ] || deny "BROWSER_QA directory $qa holds no .md verdict file with both UI VERDICT: APPROVE and VERDICT: APPROVE"
elif ! approved "$p"; then deny "BROWSER_QA file $qa lacks a UI VERDICT: APPROVE line and/or a VERDICT: APPROVE line (UX/UI review required)"; fi
log "ALLOW ref=${ref:-cwd} base=$base qa=$qa"
exit 0
