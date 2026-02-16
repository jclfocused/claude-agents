---
name: map-code
description: Generate a codebase structure map for the current project. Use during planning phases or when an agent needs to understand the overall project layout. Outputs function/class/constant signatures organized by file.
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash
argument-hint: [--include pattern] [--exclude pattern]
---

# Map Codebase Structure

Run `codebase-map format` to generate a structural overview of the current project. This outputs function, class, and constant signatures organized by file — useful for understanding project layout during planning.

## Usage

Run the map for the current working directory:

```bash
codebase-map format
```

### Filtering (optional)

Pass arguments to scope the map to specific directories or exclude patterns:

- `--include src/services/** src/routes/**` — Only map specific directories
- `--exclude **/*.test.ts docs/**` — Exclude test files or docs

Examples with arguments:

```bash
codebase-map format $ARGUMENTS
```

## When to Use

- **Planning phase** — Run once at the start of research to understand project structure
- **Implementation agents** — Run scoped to the directories you're working in (use `--include`)
- **On demand** — When you need to understand unfamiliar parts of the codebase

## Context Note

The output can be large for big projects. Prefer using `--include` to scope it to relevant directories rather than mapping the entire codebase.
