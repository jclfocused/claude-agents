#!/usr/bin/env bash
# PreToolUse(Bash) guard.
# Blocks:
#   1. `--no-verify` used with git (global CLAUDE.md: never bypass hooks).
#   2. `rm -rf`/`rm -fr` (any recursive+force combo) targeting anything outside
#      ~/.claude/backups or /tmp (global CLAUDE.md: move, don't delete).
# NEVER blocks `git push` — that is governed by CLAUDE.md judgment, and i2a
# workers legitimately push.
# Deny = exit 2 with reason on stderr (per hooks docs).
set -uo pipefail

# ---- LFOS emitter (fire-and-forget; must NEVER affect this hook) ----------
# Posts this hook's stdin JSON to the local LFOS collector (127.0.0.1:7311),
# adding lfos_event + source/kind (the collector's /event requires them) and
# raw (original payload). Fail-open: jq/curl missing or collector down is a
# silent no-op. Writes NOTHING to this hook's stdout/stderr and never changes
# its exit code or latency budget.
lfos_emit() {
  _lfos_payload=${2-}
  [ -n "$_lfos_payload" ] || return 0
  command -v curl >/dev/null 2>&1 || return 0
  if command -v jq >/dev/null 2>&1; then
    _lfos_decorated=$(printf '%s' "$_lfos_payload" | jq -c --arg e "$1" \
      '. + {lfos_event: $e, source: "claude-hook", kind: ("hook." + $e), raw: (. | tostring)}' 2>/dev/null) \
      && [ -n "$_lfos_decorated" ] && _lfos_payload=$_lfos_decorated
  fi
  ( { printf '%s' "$_lfos_payload" | curl -s -m 0.2 -X POST http://127.0.0.1:7311/event \
        -H 'content-type: application/json' --data-binary @- ; } </dev/null >/dev/null 2>&1 & )
  return 0
}

input=$(cat)
lfos_emit bash-guard "$input"
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0

deny() { printf '%s\n' "$1" >&2; exit 2; }

# ---- Rule 1: git + --no-verify -------------------------------------------
if printf '%s' "$cmd" | grep -qE '(^|[^[:alnum:]_.-])git([^[:alnum:]_.-]|$)' &&
   printf '%s' "$cmd" | grep -qE -- '(^|[[:space:]])--no-verify([[:space:]]|$|=)'; then
  deny "BLOCKED by bash-guard: --no-verify with git is forbidden (global CLAUDE.md). Fix the failing hook instead of bypassing it."
fi

# ---- Rule 2: recursive+force rm outside ~/.claude/backups and /tmp --------
# Split into simple segments on shell separators, then inspect rm invocations.
norm=$(printf '%s' "$cmd" | tr '\n' ';' | sed 's/&&/;/g; s/||/;/g; s/|/;/g')
IFS=';' read -ra segs <<< "$norm"
for seg in "${segs[@]}"; do
  read -ra toks <<< "$seg" || continue
  [ "${#toks[@]}" -eq 0 ] && continue
  idx=-1
  for i in "${!toks[@]}"; do
    t=${toks[$i]}
    if [ "$t" = "rm" ] || [[ "$t" == */rm ]]; then idx=$i; break; fi
  done
  [ "$idx" -lt 0 ] && continue
  r=0; f=0; endflags=0
  targets=()
  for ((i=idx+1; i<${#toks[@]}; i++)); do
    t=${toks[$i]}
    if [ "$endflags" -eq 0 ] && [ "$t" = "--" ]; then endflags=1; continue; fi
    if [ "$endflags" -eq 0 ] && [[ "$t" == -* ]]; then
      case "$t" in
        --recursive) r=1 ;;
        --force)     f=1 ;;
        --*)         : ;;
        -*) [[ "$t" == *r* || "$t" == *R* ]] && r=1
            [[ "$t" == *f* ]] && f=1 ;;
      esac
      continue
    fi
    targets+=("$t")
  done
  { [ "$r" -eq 1 ] && [ "$f" -eq 1 ]; } || continue
  if [ "${#targets[@]}" -eq 0 ]; then
    deny "BLOCKED by bash-guard: recursive+force rm with no identifiable literal target. Global CLAUDE.md forbids rm -rf outside ~/.claude/backups and /tmp — move files to ~/.claude/backups/<reason>-<timestamp>/ instead."
  fi
  for t in "${targets[@]}"; do
    p=${t//\"/}; p=${p//\'/}
    case "$p" in
      "~/"*) p="$HOME/${p#\~/}" ;;
      "~")   p="$HOME" ;;
    esac
    case "$p" in
      /tmp|/tmp/*) : ;;
      "$HOME/.claude/backups"|"$HOME/.claude/backups/"*) : ;;
      *) deny "BLOCKED by bash-guard: 'rm -rf' targets '$t', which is outside ~/.claude/backups and /tmp. Global CLAUDE.md forbids this — move it to ~/.claude/backups/<reason>-<timestamp>/ (or a project-local .backups/) instead." ;;
    esac
  done
done

exit 0
