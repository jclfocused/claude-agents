---
name: merge-to-prod
description: Use when merging or promoting a selected change to production, or carrying an already-authorized production merge through deployment, live testing and monitoring. Follow the target repository's release runbooks. Do not use for implementation-only work or a single artifact check.
---

# Merge to production

A production merge is complete only after its deployments finish, the live revision is proven, the changed journey works in production, and the monitoring window is reviewed. Use each repository's release and monitoring setup.

## Scope and repository discovery

1. Identify the selected repository, PR or promotion, production branch, and user-authorized scope. Fetch current refs and read its `AGENTS.md`/`CLAUDE.md`, release documentation, and relevant local skills in `.agents/skills/` or `.claude/skills/`. Resolve symlinks once; both harnesses may expose the same file.
2. Prefer the repository's `merge-to-prod`, `release-to-prod`, `release-verify`, or deployment counterpart for concrete commands, merge method, sequencing, logs and tests. For a workspace with multiple repositories, map each separately. Do not copy another product's branch strategy, identifiers, credentials or monitoring stack.
3. Check the current workflow and its invoked scripts against that guidance. Include deployments outside CI, automatic migrations, background services and dependent targets. If guidance disagrees with the release path, resolve the discrepancy before the affected mutation; never guess that a migration is manual or automatic.
4. Build a small release map: revision, target, trigger/job, expected live marker, health/journey check, log/alert source and monitoring window. Reuse an existing runbook; fill missing facts from current configuration and read-only provider state. A runbook gap is not permission to redesign deployment or observability.

## Authorization and readiness

- Apply the user's existing authorization to the selected merge. Do not ask again when it was already granted. Preparation and read-only verification can continue while any genuinely missing approval is pending; ask only after the proposed action is concrete.
- Follow the current restricted-production and data-write rules. A merge approval does not authorize unrelated production migrations, customer edits, charges, paid generation, sends, key creation or another repository's release. Record the release's automatic effects and stop before an effect outside the authorized scope.
- Verify the exact PR head/base, complete diff and migration impact; confirm review findings are resolved and the repository's required checks passed for that revision. Reuse valid existing review/test evidence rather than spawning another review merely because this skill was invoked.
- For changed UI journeys, require the approved real-browser preview/dev pass for that head: actual deployment receipt, screenshots, a `## UX/UI review` of every changed screen at 1440 and 390 against [the UX/UI rubric](../sandbox-verify/references/ux-ui-review.md) ending `UI VERDICT: APPROVE`, and the overall `VERDICT: APPROVE` (journeys and UI both pass). A journeys-only APPROVE is incomplete. Use the available browser tooling to exercise the journey. A mutable preview URL alone is not revision evidence. A docs-only or non-UI exception needs its explicit reason and appropriate applicable checks, never a fabricated browser pass.
- Read new human and automated review comments, including the repository's native review workflow. If head/base or deployed preview changed since the evidence, determine what became stale and refresh affected checks before merging. Do not bypass protections or rewrite history.
- Record the pre-release live revision, baseline health/errors and owned resources. Keep customer data, sessions and credentials out of receipts and shared comments.

## Merge and watch the whole release

1. Recheck head/base and authorization immediately before the merge. Use the repository's documented merge method and an expected-head precondition when the provider supports it. Record the actual merge/promotion SHA, which may differ from the PR head.
2. If a peer already merged the selected change, verify its head and merge commit, then join that deployment. Do not duplicate the merge, rerun workflows to obtain a URL, or start a manual deployment beside CI.
3. Resolve runs by the recorded revision, trigger and target, not merely the newest run on the branch. Watch every required target/job through completion in its documented dependency order. Successful tests or migrations do not prove a later deployment succeeded.
4. Keep progress visible. Poll within the repository's deadline and provider limits; use a detached watcher with a state file when appropriate, and own its lifetime. A pending, cancelled, skipped-required, timed-out or failed target is not a successful release.
5. On failure, identify the failed step and which earlier mutations happened. Preserve receipts and backups; investigate before retrying. Prefer a scoped fix within authorization. Do not automatically roll back a user-ordered rollout, rerun obsolete revisions, restore databases or widen permissions. Use the repo's incident/rollback procedure and applicable authorization.

## Prove what users receive

Use the repository's verifier or available deployment tooling. Independently read the live target after CI: the public alias must point at the recorded deployment/revision; services must serve the intended image/build; function packages must match the expected hash. Verify migrations/configuration through the existing release receipt and safe read-only checks. A no-op package can be correct when its live hash matches; a new timestamp is not required proof.

If a newer release supersedes this one, record the change. Verify that the live revision contains the selected fix and repeat affected live checks against that revision. Do not label an older receipt as the current live artifact, or claim the newer release is authorized by this one.

Run the changed journey on the real production URL using the authorized own QA account and the repository's login method. Check the rendered result, relevant network failures and application errors; capture screenshots and a verdict, and apply the [UX/UI rubric](../sandbox-verify/references/ux-ui-review.md) to the changed screens. Read the screenshots yourself before reporting the UI change done. Add adjacent read-only smoke checks where the change can affect them.

Keep effects explicit: no real customer edits, billing changes, external sends or paid calls just to obtain a green result. Reversible own-account QA may follow the standing authorization, with a before/after snapshot and cleanup. If the real result requires an additional authorized effect, prepare the test and ask only for that effect. Interception or synthetic responses may supplement dangerous negative cases, but must be labeled simulated and cannot prove a real production integration worked. Report any untested behavior precisely.

## Bounded monitoring

- Use the repository's existing logs, health checks, error sink, metrics, alerts and dashboards. Read its local monitoring recipe first. Do not install or migrate observability as part of a routine merge.
- Start observing during rollout; after the last required target is live, complete the runbook's observation window. If none exists, use a ten-minute default and record the choice. Longer jobs need their documented completion/staleness evidence; a ten-minute quiet window is not proof that a daily job executed.
- Compare baseline with the new deployment/time range and changed routes. Capture probe counts, failed checks, error rate and relevant saturation/latency signals. Separate expected QA failures from unexplained errors, and check existing alerts.
- Account for ingestion delay. Record the latest available log/metric timestamp, sample count and uncovered interval. No samples means unavailable evidence, not zero errors. If a required source is inaccessible or a release regression remains unresolved, report verification incomplete; do not silently substitute a generic health page.
- On regression, preserve evidence and follow the failure path. Stop only the watcher/processes this task owns when the window ends or it is handed off explicitly.

## Receipt and closeout

Use the repo's receipt format if it has one; otherwise store a sanitized record outside tracked source:

```yaml
repository: owner/repo
pull_request: https://github.com/owner/repo/pull/123
authorized_scope: selected merge and its documented rollout
head_sha: reviewed revision
merge_sha: actual promoted revision
targets: # one entry per required target
  - name: production-web
    run: workflow URL
    deployment: provider reference
    observed_revision: live SHA or artifact hash
    result: verified | failed | pending
browser: # evidence paths, covered journeys and any simulated cases
  ui_verdict: APPROVE | CHANGES | not-applicable-with-reason
  verdict: APPROVE | CHANGES | not-applicable-with-reason
monitoring:
  started_at: UTC timestamp
  completed_at: UTC timestamp
  sources: # query window, latest sample, counts, errors and gaps
verification: verified | incomplete | failed
cleanup: owned resources removed or explicitly retained
```

Only mark the issue complete after its required release proof passes. If integration automation closed it early, reconcile that status with the real outcome and user instructions. Keep detailed test/log evidence in the receipt or PR; use the issue's writing rules.

Clean owned preview resources through the repository's teardown workflow. Remove a local worktree/branch only after fresh merge/ancestry proof (or verified squash mapping), preserving unique data and checking processes, mounts, open files and service references. Never delete shared databases, credentials or other sessions' resources. Report the PR, live URL/revision, production-test result, monitoring result, and any remaining gap.

## Example

User: “Merge the billing fix, then verify production.” The selected PR is already approved and green. Load its repository release skill, confirm the current head still matches preview evidence, and merge using the existing authorization. Watch staging and production web/function jobs; verify the public aliases and package hashes. Use the authorized QA account to open the real billing portal without changing payment details. Run the repository's health/log/metric watch, retain the evidence, then close the issue and clean its preview. A green web deployment with a failed function job remains an incomplete release.

FAIL: “Merged; CI is green.” PASS: “Merged and verified on the live revision; the billing journey passed and the ten-minute watch recorded no unexplained errors across the documented sources.”
