#!/usr/bin/env bash
# PreToolUse(Bash): deny any command that would spend the Anthropic API key from a job on this box.
# Justin, 2026-09-20: "set a hard rule to never use the API key for jobs here" — the account had its
# access turned off for lack of credit while a bench lane was calling claude-opus-5. Jobs, benches,
# judges, labelling passes and escalation paths use Codex gpt-6.1-sol xhigh (or better) or the OpenAI
# models the services already run. Claude models stay the agents; this hook is about API calls the
# code makes. Read-only inspection (grep/rg/ls/find/stat of env files by NAME) is allowed.

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // .tool_input.cmd // empty' 2>/dev/null)
conserve_flag="$LFOS_CONSERVE_FLAG"
[ -n "$conserve_flag" ] || conserve_flag="$HOME/.claude/automation/state/conserve-mode.json"
# Per-session override (Justin, 2026-09-30: "ignore conservation mode in this session completely"). A file named
# after the session id in conserve-override/ turns the flag off for that session only; other sessions still see it.
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
if [ -n "$session_id" ] && [ -f "$HOME/.claude/automation/state/conserve-override/$session_id" ]; then
  conserve_flag=/nonexistent
fi
# Headless seats launched by an overridden session's work carry the override in their environment.
[ "${LFOS_CONSERVE_OVERRIDE:-}" = 1 ] && conserve_flag=/nonexistent
design_notice='LOW CLAUDE CREDIT: skip Fable while conservation mode is active. Codex using Sol 6.1 gpt-6.1-sol at xhigh or higher may approve design without Fable automatically (Justin, updated 2026-09-30); no additional permission is needed. Astra requires Justin to request it explicitly for this task. Record Codex-only approval honestly and retain normal research, screenshot, fresh Codex review and verification gates. Codex does not enter credit-saver mode.'

# Both harnesses receive the narrow design exception before planning a counterpart run.
case "$event" in
  SessionStart|UserPromptSubmit)
    [ ! -f "$conserve_flag" ] || printf '%s\n' "$design_notice"
    exit 0
    ;;
esac
[ -n "$cmd" ] || exit 0

# Subscription CLI model names alone are not evidence of paid API usage.
deny_re='api\.anthropic\.com|ANTHROPIC_API_KEY|@anthropic-ai/|anthropic\.messages|Anthropic\('
# Pure read-only name lookups pass; later commands do not inherit that exemption.
read_only=false
if printf '%s' "$cmd" | grep -Eq '^[[:space:]]*(grep|rg|ugrep|ls|find|stat|wc)[[:space:]]' &&
   ! printf '%s' "$cmd" | grep -Eq '[;&|`$()]' &&
   [ "$(printf '%s' "$cmd" | wc -l)" -eq 0 ]; then
  read_only=true
fi
if [ "$read_only" = false ] && printf '%s' "$cmd" | grep -Eq "$deny_re"; then
  echo "BLOCKED: the Anthropic API is not to be used by jobs on this box (Justin, 2026-09-20 — no credits; access was cut off mid-bench). Use Codex gpt-6.1-sol at xhigh or better (codex exec … -c model_reasoning_effort=xhigh) or the OpenAI models the services run (gpt-5.6-luna). Read-only checks of the env var NAME with grep/rg are fine." >&2
  exit 2
fi
# Conserve the Claude subscription when the collector's existing flag is present.
# ponytail: python3 starts only when the command could launch claude. Without "$" the parser
# below expands nothing, so a launch needs "claude" in the command once quotes and backslashes
# are dropped, and its depth>8 rule needs at least 9 nested sh/eval launchers (checked at 8).
# Any other command returns "no launch" from the parser, so skipping it changes no verdict.
unquoted=${cmd//[\'\"\\]/}
no_sh=${unquoted//sh/}
no_eval=${unquoted//eval/}
may_launch=false
case "$unquoted" in *claude*|*'$'*) may_launch=true ;; esac
[ $(( (${#unquoted} - ${#no_sh}) / 2 + (${#unquoted} - ${#no_eval}) / 4 )) -ge 8 ] && may_launch=true
# Tokenize quoted model arguments and env-wrapped CLI launches without executing them.
if [ -f "$conserve_flag" ] && [ "$may_launch" = true ] && python3 - "$cmd" <<'PY'
import os
import re
import shlex
import sys

def launches_fable(command, variables, depth=0):
    if depth > 8:
        return True
    # Resolve the ordinary CLI lookup form statically; never run a substitution.
    command = re.sub(
        r"\$\(\s*(?:command\s+-v|which|type\s+-p)\s+(?:--\s+)?(['\"]?)([\w./-]*claude)\1\s*\)",
        lambda match: match[2], command,
    )
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()\n")
        lexer.whitespace = " \t\r"
        tokens = list(lexer)
    except ValueError:
        return False

    def expand(value):
        return re.sub(r"\$(?:\{(\w+)\}|(\w+))",
                      lambda match: variables.get(match[1] or match[2], match[0]), value)

    skip_until = 0
    for index, raw in enumerate(tokens):
        if index < skip_until:
            continue
        token = expand(raw)
        assignment = re.fullmatch(r"([A-Za-z_]\w*)=(.*)", token, flags=re.S)
        if assignment:
            variables[assignment[1]] = assignment[2]
            continue
        executable = os.path.basename(token)
        if executable not in {"claude", "bash", "sh", "zsh", "dash", "eval"}:
            continue
        args = []
        for arg in tokens[index + 1:]:
            if arg and all(char in ";&|()\n" for char in arg):
                break
            args.append(expand(arg))
        # Arguments to a recognized launcher are not independent shell commands.
        skip_until = index + len(args) + 1
        if executable == "eval":
            if launches_fable(" ".join(args), variables.copy(), depth + 1):
                return True
            continue
        if executable != "claude":
            for at, arg in enumerate(args[:-1]):
                if re.fullmatch(r"-[A-Za-z]*c[A-Za-z]*", arg):
                    child_variables = variables.copy()
                    child_variables.update({str(n): value for n, value in enumerate(args[at + 2:])})
                    if launches_fable(args[at + 1], child_variables, depth + 1):
                        return True
                    break
            continue
        # Local account/help/settings commands do not launch a model.
        if args and args[0] in {"auth", "--help", "-h", "--version", "-v", "config", "doctor", "mcp", "plugin", "update", "install"}:
            continue
        model = None
        for at, arg in enumerate(args):
            if arg == "--model" and at + 1 < len(args):
                model = args[at + 1]
            elif arg.startswith("--model="):
                model = arg.split("=", 1)[1]
        # Unspecified models include defaults and resumed Fable sessions.
        if model is None or "$" in model or "fable" in model.lower():
            return True
    return False


sys.exit(0 if launches_fable(sys.argv[1], dict(os.environ)) else 1)
PY
then
  printf 'BLOCKED Fable launch. %s\n' "$design_notice" >&2
  exit 2
fi
exit 0
