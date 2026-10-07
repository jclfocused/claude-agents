#!/usr/bin/env bash
# PreToolUse guard (Bash): deny commands that can dump unbounded text into the context.
# Added 2026-09-11 after a session maxed its context on tool output. Heuristic, deliberately strict:
# a noisy command passes only when its stdout is bounded (head/tail/grep/wc/cut/jq/… or a file redirect).
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[ -z "$cmd" ] && exit 0
deny() { jq -n --arg r "Bash blocked (context guard): $1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; exit 0; }
# Bounded if any stage limits output or it goes to a file.
bounded_re='\|[[:space:]]*(head|tail|grep|wc|cut|jq|sort|uniq|awk|sed|python3?|node|tee|paste|tr|xargs|md5sum|sha256sum)([[:space:]]|$)|[^&2]>[[:space:]]*[^&[:space:]]|2>&1[[:space:]]*>|>/dev/null|--stat|--shortstat|--name-only|--name-status|-q[[:space:]]+['"'"'"]\.|--jq[[:space:]]|-o[[:space:]]+[^[:space:]-]|--output[[:space:]]'
if printf '%s' "$cmd" | grep -Eq "$bounded_re"; then
  # Still catch oversized explicit slices.
  n=$(printf '%s' "$cmd" | grep -oE '(head|tail)[[:space:]]+-n?[[:space:]]*-?[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1)
  [ -n "$n" ] && [ "$n" -gt 150 ] && deny "head/tail -n $n is too big — keep a slice under 150 lines."
  r=$(printf '%s' "$cmd" | grep -oE "sed -n '?[0-9]+,[0-9]+p" | head -1 | grep -oE '[0-9]+,[0-9]+' | head -1)
  if [ -n "$r" ]; then a=${r%,*}; b=${r#*,}; [ $((b-a)) -gt 200 ] && deny "sed -n $r spans $((b-a)) lines — keep a slice under 200 lines."; fi
  exit 0
fi
# Unbounded: deny the known noisy families.
noisy_re='(^|[;&|][[:space:]]*|\bthen[[:space:]]+|\bdo[[:space:]]+)(cat|less|more|bat)[[:space:]]|(^|[;&|][[:space:]]*)(npm|pnpm|yarn|npx|bun)[[:space:]]+(run|test|ci|install|i|build|lint|exec|vitest|jest|playwright|eslint|prettier|tsc)|(^|[;&|][[:space:]]*)(vitest|jest|playwright|eslint|tsc|cargo|pytest|mvn|gradle|make|docker|kubectl|journalctl|wrangler)[[:space:]]|git[[:space:]]+(diff|show|log[[:space:]].*-p|log[[:space:]].*--patch|commit|pull|push|merge|rebase|fetch[[:space:]]-v|blame)|gh[[:space:]]+(api|pr[[:space:]]+(diff|view|checks)|run[[:space:]]+view|issue[[:space:]]+view)|(^|[;&|][[:space:]]*)(curl|wget|http)[[:space:]]|(^|[;&|][[:space:]]*)(find|tree|ls[[:space:]]+-R|du[[:space:]]+-a|env|printenv|set)([[:space:]]|$)|(^|[;&|][[:space:]]*)(head|tail)[[:space:]]+-n?[[:space:]]*[0-9]{3,}'
if printf '%s' "$cmd" | grep -Eq "$noisy_re"; then
  deny "this command can print unbounded output. Bound it: '| head -n 40', '| tail -n 20', '| grep -c', 'git diff --stat', 'gh api … --jq', 'curl -s … | jq -c', or redirect to a file and read a slice. For tests/builds: '2>&1 | tail -n 15'."
fi
# cat/sed/awk of a big file with no pipe: check every path-like token.
for tok in $(printf '%s' "$cmd" | grep -oE '(~|/|\.{1,2}/)?[A-Za-z0-9_./~-]+\.[A-Za-z0-9]{1,8}' | head -20); do
  f="${tok/#\~/$HOME}"; [ -f "$f" ] || continue
  sz=$(stat -c %s "$f" 2>/dev/null || echo 0)
  [ "$sz" -gt 40000 ] && deny "$tok is $((sz/1024)) KB and the command has no output bound. Slice it (sed -n 'A,Bp' | cut -c1-200), grep it, or summarise via a subagent."
done
exit 0
