#!/usr/bin/env bash
# Test for prod-browser-qa-gate.sh: a fake `gh` reports base=main; logs go to a temp file.
set -u
here=$(cd "$(dirname "$0")" && pwd); t=$(mktemp -d)
# Tidy only the files this test wrote (house rule: no recursive rm).
trap 'rm -f "$t"/bin/gh "$t"/*.md "$t"/log "$t"/dir-*/*.md 2>/dev/null; rmdir "$t"/bin "$t"/dir-* "$t" 2>/dev/null' EXIT
mkdir -p "$t/bin" "$t/dir-ok" "$t/dir-bad"
printf '#!/bin/sh\necho main\n' > "$t/bin/gh"; chmod +x "$t/bin/gh"
printf '## UX/UI review\n1. NON-BLOCKING — x\nUI VERDICT: APPROVE\n\n**VERDICT: APPROVE**\n' > "$t/both.md"
printf 'Journeys pass.\nVERDICT: APPROVE\n' > "$t/no-ui.md"
printf 'UI VERDICT: APPROVE\n' > "$t/ui-only.md"
printf 'UI VERDICT: CHANGES\nVERDICT: APPROVE\n' > "$t/ui-changes.md"
cp "$t/both.md" "$t/dir-ok/BROWSER-QA.md"; cp "$t/no-ui.md" "$t/dir-bad/BROWSER-QA.md"
fail=0
run() { # $1 expect allow|deny, $2 command
  out=$(jq -n --arg c "$2" '{tool_input:{command:$c}}' | PATH="$t/bin:$PATH" PROD_BROWSER_QA_GATE_LOG="$t/log" bash "$here/prod-browser-qa-gate.sh")
  got=allow; printf '%s' "$out" | grep -q '"deny"' && got=deny
  if [ "$got" = "$1" ]; then echo "ok   $1  $2"; else echo "FAIL want $1 got $got  $2"; fail=1; fi
}
run deny  "gh pr merge 5 --squash"
run deny  "BROWSER_QA=$t/no-ui.md gh pr merge 5 --squash"
run deny  "BROWSER_QA=$t/ui-only.md gh pr merge 5 --squash"
run deny  "BROWSER_QA=$t/ui-changes.md gh pr merge 5 --squash"
run deny  "BROWSER_QA=$t/dir-bad gh pr merge 5 --squash"
run deny  "BROWSER_QA=$t/missing.md gh pr merge 5 --squash"
run deny  "BROWSER_QA=none: gh pr merge 5 --squash"
run allow "BROWSER_QA=$t/both.md gh pr merge 5 --squash"
run allow "BROWSER_QA=$t/dir-ok gh pr merge 5 --squash"
run allow "BROWSER_QA=none:docs-only gh pr merge 5 --squash"
run allow "git status"
grep -q 'prod-browser-qa-gate: ALLOW' "$t/log" || { echo "FAIL log line missing"; fail=1; }
jq -n --arg c "BROWSER_QA=$t/no-ui.md gh pr merge 5" '{tool_input:{command:$c}}' | PATH="$t/bin:$PATH" PROD_BROWSER_QA_GATE_LOG="$t/log" bash "$here/prod-browser-qa-gate.sh" | grep -q 'ux-ui-review.md' || { echo "FAIL deny message lacks rubric path"; fail=1; }
[ $fail = 0 ] && echo PASS || echo FAILED; exit $fail
