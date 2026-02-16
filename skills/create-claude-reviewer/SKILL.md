---
name: create-claude-reviewer
description: Create a Claude Code Review GitHub Action workflow for PRs. Use when the user asks to "set up claude review", "add PR review", "create code review action", "claude reviewer", "set up automated review", or wants automated PR reviews with Linear or GitHub comments.
disable-model-invocation: true
argument-hint: "[optional repo path or context]"
---

# Create Claude Code Review GitHub Action

You are creating a `claude-code-review.yml` GitHub Action workflow that automatically reviews PRs using Claude. This workflow uses `anthropics/claude-code-action@v1`.

There are two modes:
- **Linear mode** — Creates structured issues in Linear under the parent ticket (no PR comments)
- **GitHub mode** — Writes inline review comments directly on the PR using `gh`

## Context Awareness

This skill can be invoked at any point. Check conversation context — the user might reference repos already discussed, a workspace they just set up, or specific sub-repos. Use `$ARGUMENTS` if provided, otherwise infer from context.

**Important**: This workflow gets created in each working repo individually (each sub-repo in a meta-repo setup, NOT the meta-repo root). Each repo needs its own workflow because review rules and repo-specific violations differ per project.

---

## Step 1: Ask Clarifying Questions

Use `AskUserQuestion` to gather what you need. Skip anything obvious from context.

**Always ask:**
- **Linear or GitHub?** — "Should review findings be posted as Linear issues or as inline GitHub PR comments?"

**Ask if not obvious from context:**
- **Which repos?** — If in a meta-repo, which sub-repos should get the workflow? (default: all)
- **Target branch** — What branch do PRs target? (e.g., `develop`, `main`)
- **Model** — Which Claude model? (default: `claude-opus-4-6`)

**Ask only for Linear mode:**
- **Branch naming convention** — How are branches named? Need the pattern to extract ticket IDs (e.g., `wha-XXXX-description` extracts `WHA-XXXX`)
- **Linear team UUID** — What Linear team should issues be created in?
- **Linear label UUIDs** — Do they have label UUIDs for critical/warning severity? (optional, can skip)
- **Linear state preferences** — What state should review issues be created in? (default: "Todo")

---

## Step 2: Research Each Repo

For each repo that will get the workflow, read:
- `CLAUDE.md` — for repo-specific rules and violations to watch for
- `package.json` / `pyproject.toml` / `requirements.txt` — to understand the tech stack
- Existing `.github/workflows/` — check if a claude review workflow already exists

Extract from each repo:
1. **Tech stack** — language, framework (affects what review rules make sense)
2. **Repo-specific rules** — from CLAUDE.md, things the reviewer should flag as violations
3. **Existing workflow** — if one exists, ask the user if they want to replace or skip

---

## Step 3: Generate the Workflow

Create `.github/workflows/claude-code-review.yml` in each target repo.

### GitHub Mode Template

GitHub mode is simpler — no MCP config needed. Claude reviews the PR and posts inline comments using the built-in PR comment functionality.

```yaml
name: Claude Code Review

on:
  pull_request:
    types: [opened, synchronize]
    branches:
      - [TARGET_BRANCH]

jobs:
  claude-review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: read
      id-token: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - name: Run Claude Code Review
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          use_sticky_comment: true
          prompt: |
            ## PR Code Review

            You are reviewing PR #${{ github.event.pull_request.number }} on branch `${{ github.head_ref }}`.

            ### Review Focus - REAL ISSUES ONLY
            Review the PR diff for CONCRETE, SIGNIFICANT issues only:
            - **Security vulnerabilities** (injection, auth bypass, data exposure, XSS, CSRF)
            - **Performance problems** (N+1 queries, memory leaks, unbounded loops)
            - **Actual bugs** that will cause runtime errors or incorrect behavior
            [REPO_SPECIFIC_RULES]

            **DO NOT REPORT:**
            - Edge cases or rare scenarios unlikely to occur
            - Style preferences or minor code organization suggestions
            - Theoretical issues that "could" happen but probably won't
            - Nitpicks or "nice to have" improvements
            - Issues without clear, concrete impact

            ### Output Format
            For each finding, use `gh` to post an inline review comment on the specific file and line:

            ```bash
            gh api repos/${{ github.repository }}/pulls/${{ github.event.pull_request.number }}/comments \
              --method POST \
              -f body="**[Critical]** or **[Warning]**: Description of the issue and its concrete impact" \
              -f commit_id="$COMMIT_SHA" \
              -f path="path/to/file" \
              -F line=LINE_NUMBER
            ```

            Use `gh pr diff ${{ github.event.pull_request.number }}` to get the diff and identify exact file paths and line numbers.

            If no significant issues are found, that's a GOOD outcome. Post a single summary comment saying the review is clean.

            **ONLY report genuine, concrete concerns with clear impact.**
          claude_args: |
            --model [MODEL]
            --allowedTools Bash(gh pr diff:*),Bash(gh pr view:*),Bash(gh api:*)
```

### Linear Mode Template

Linear mode creates structured issues in Linear, organized under the parent ticket. Requires Linear MCP config.

```yaml
name: Claude Code Review

on:
  pull_request:
    types: [opened, synchronize]
    branches:
      - [TARGET_BRANCH]

jobs:
  claude-review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: read
      id-token: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - name: Create MCP Config
        env:
          LINEAR_TOKEN: ${{ secrets.[LINEAR_SECRET_NAME] }}
        run: |
          cat > /tmp/mcp-config.json << EOF
          {
            "mcpServers": {
              "linear": {
                "command": "npx",
                "args": [
                  "-y",
                  "mcp-remote@latest",
                  "https://mcp.linear.app/mcp",
                  "--header",
                  "Authorization:Bearer ${LINEAR_TOKEN}"
                ]
              }
            }
          }
          EOF

      - name: Run Claude Code Review
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          use_sticky_comment: true
          prompt: |
            ## PR Review - Create Linear Issues

            You are reviewing PR #${{ github.event.pull_request.number }} on branch `${{ github.head_ref }}`.

            ### Step 1: Extract Linear Ticket ID
            Extract the ticket ID from the branch name. Branch format is `[BRANCH_PATTERN]`.
            The ticket ID is the `[PREFIX]-XXXX` part.

            ### Step 2: Review the PR - FOCUS ON REAL ISSUES ONLY
            Review the PR diff for CONCRETE, SIGNIFICANT issues only:
            - **Security vulnerabilities** (injection, auth bypass, data exposure, XSS, CSRF)
            - **Performance problems** (N+1 queries, memory leaks, unbounded loops)
            - **Actual bugs** that will cause runtime errors or incorrect behavior
            [REPO_SPECIFIC_RULES]

            **DO NOT REPORT:**
            - Edge cases or rare scenarios unlikely to occur
            - Style preferences or minor code organization suggestions
            - Theoretical issues that "could" happen but probably won't
            - Nitpicks or "nice to have" improvements
            - Issues without clear, concrete impact

            ### Step 3: Check Existing Issues Before Creating New Ones
            1. Look up the parent ticket using `mcp__linear__get_issue` with the extracted ticket ID
            2. Use `mcp__linear__list_issues` with `parentId` to find all sub-issues
            3. Look for an existing issue titled "PR Review Comments"
            4. If found, check status of each finding sub-issue:
               - **Done** = Fixed, do NOT re-report
               - **Cancelled** = Accepted, do NOT re-report
               - **Todo/In Progress** = Still needs attention
            5. **NEVER re-create an issue that already exists in Done or Cancelled status**

            ### Step 4: Create or Reuse "PR Review Comments" Issue
            - **NEVER create a new one if one already exists** — reuse it
            - Only create if none exists:
              - Title: "PR Review Comments"
              - Description: "Review comments from PR #${{ github.event.pull_request.number }}: ${{ github.event.pull_request.title }}"
              - Team: `[TEAM_UUID]`
              - Parent: The ticket UUID from step 1
              - State: "Todo" (**MUST be Todo, NEVER Triage**)

            ### Step 5: Create Sub-Issues for New Findings
            For each NEW finding, create a sub-issue under "PR Review Comments":
            - **State MUST be "Todo"** (not Triage, not Backlog)
            - Title format: `[Critical] Description` or `[Warning] Description`
            - Description: Include file path, line numbers, and clear explanation of impact
            [LABEL_CONFIG]
            - Priority: 1 (Urgent) for critical, 2 (High) for warning

            ### Step 6: When Review is Complete
            If NO new issues to report:
            1. Add a comment: "Review complete for PR #${{ github.event.pull_request.number }}. No new issues found."
            2. Update "PR Review Comments" issue state to "Done"

            ### Important Notes
            - **ONLY create issues for genuine, concrete concerns with clear impact**
            - Do NOT report issues just to have something to report
            - If no significant issues found, that's a GOOD outcome
            - Do NOT leave comments on the PR — only create Linear issues
            - **ALL issue states MUST be "Todo"**
          claude_args: |
            --model [MODEL]
            --mcp-config /tmp/mcp-config.json
            --allowedTools mcp__linear__list_issues,mcp__linear__get_issue,mcp__linear__create_issue,mcp__linear__update_issue,mcp__linear__create_comment,mcp__linear__list_issue_statuses,Bash(gh pr diff:*),Bash(gh pr view:*)
```

---

## Step 4: Customize Per Repo

For each repo, replace the placeholders:

| Placeholder | Source |
|:------------|:-------|
| `[TARGET_BRANCH]` | User answer (e.g., `develop`, `main`) |
| `[MODEL]` | User answer (default: `claude-opus-4-6`) |
| `[REPO_SPECIFIC_RULES]` | Extracted from that repo's CLAUDE.md — format as bullet points under "Repository rule violations" |
| `[BRANCH_PATTERN]` | Linear mode only — user's branch naming convention |
| `[PREFIX]` | Linear mode only — ticket prefix extracted from branch pattern |
| `[TEAM_UUID]` | Linear mode only — user's Linear team UUID |
| `[LINEAR_SECRET_NAME]` | Linear mode only — GitHub secret name for Linear token |
| `[LABEL_CONFIG]` | Linear mode only — label UUID lines if provided, otherwise omit |

**Repo-specific rules** are critical. Read each repo's CLAUDE.md and extract rules that the reviewer should enforce. Examples from real repos:
- Python repo: "Not activating venv before Python commands", "Using `supabase db push --linked`"
- React repo: "Using Supabase directly in components instead of stores", "Missing `observer()` wrapper"
- Any repo: "Using `--no-verify` on commits", "Using `supabase db reset`"

Format these as bullet points under a "Repository rule violations" section in the prompt.

---

## Step 5: Create the Files

For each target repo:
1. Create `.github/workflows/` directory if it doesn't exist
2. Write `claude-code-review.yml` with the customized template
3. If a file already exists, show the user the diff and ask before overwriting

---

## Step 6: Summary and Required Secrets

After creating all workflow files, tell the user which GitHub secrets they need to configure in each repo's Settings > Secrets:

**Both modes:**
- `CLAUDE_CODE_OAUTH_TOKEN` — Claude Code OAuth token for the action

**Linear mode additionally:**
- The Linear token secret (whatever name was chosen, e.g., `LINEAR_TOKEN`)

Remind the user:
- Each repo has its own workflow with repo-specific review rules
- The workflow triggers on PRs to the target branch
- They should test by opening a small PR
