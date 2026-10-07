#!/usr/bin/env bash
# Warn-only routing guard: fires on Write/Edit of code files, reminds the model of the
# Fable-orchestrates/opus-implements rule at the moment drift happens (2026-08-23).
# The rule is a Claude-seat routing rule, so the guard stays silent in a Codex
# session — that seat has its own model contract in ~/.codex/AGENTS.md.
[ -n "${CODEX_HOME:-}" ] || [ -n "${CODEX_SANDBOX:-}" ] || [ -n "${CODEX_API_KEY:-}" ] && exit 0
input=$(cat)
fp=$(printf '%s' "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)
case "$fp" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.py|*.swift|*.kt|*.go|*.rs|*.sql)
    case "$fp" in
      */docs/*|*/skills/*|*.test.*|*/migrations/*|*README*) exit 0;;
    esac
    echo "ROUTING CHECK (warn-only): code write detected. If this session runs on Fable and this is implementation beyond trivial one-file glue — stop, write/extend the spec, and route it through a Workflow with opus workers (global CLAUDE.md model routing, hardened 2026-08-23)."
    ;;
esac
exit 0
