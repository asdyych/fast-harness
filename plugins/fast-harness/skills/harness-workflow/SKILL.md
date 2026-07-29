---
name: harness-workflow
description: |
  Orchestrate Matt Pocock's engineering skills into a recoverable implementation
  flow with one mandatory cross-model review, verification, and automatic
  checkpoint commit/push. Use for "按照 harness 的流程去实现", "按照harness的流程去实现",
  "按 harness 流程实现", "harness full", "/fast-harness-full", "快速实现",
  "quick implement", "/fast-harness-quick", or equivalent requests. Full mode
  runs to-spec and to-tickets before implement; quick mode skips them.
---

# Harness workflow

Route an implementation request through the installed Matt Pocock skills, then
add fast-harness persistence and cross-model review. Do not copy or improvise
Matt's phase instructions: resolve and read the installed `SKILL.md` before each
phase so upstream updates remain authoritative.

## Route selection

- **Full mode**: "按照 harness 的流程去实现", "按照harness的流程去实现",
  "按 harness 流程实现", `harness full`, or `/fast-harness-full`. Run `to-spec`
  -> `to-tickets` -> per-ticket `implement`.
- **Quick mode**: "快速实现", `quick implement`, `harness quick`, or
  `/fast-harness-quick`. Run `implement` without spec or tickets.
- `/fast-harness-full` and `/fast-harness-quick` are fixed-mode direct aliases;
  all following text is the goal. Explicit quick wording otherwise wins, and
  full mode is the default.

Both routes finish with directly relevant verification and a single mandatory `cross-review`.
A route trigger confirms the mode and authorizes ordinary checkpoint pushes.
Restate the mode and start. Pause only for a material product decision,
inseparable user changes, a destructive action, or undiscoverable
repository/tracker information.

## Upstream skills

Resolve the plugin root from `CODEX_PLUGIN_ROOT` or `CLAUDE_PLUGIN_ROOT`; when
neither exists, derive it from this file, two directories above the skill
directory. Before each Matt phase, resolve its installed source:

```bash
"${HARNESS_PLUGIN_ROOT}/scripts/resolve-matt-skill.sh" <skill-name>
```

Read the returned file in full before that phase. If it is unavailable, stop
before editing. Apply its protocol inside the scope below; this wrapper owns
only routing, scope, checkpoint persistence, and the final review gate. Skip the
`code-review` phase offered by `implement`.

## Core-loop scope discipline

Prove the smallest useful end-to-end behavior first.

- Do not add implementation or tests for speculative edge cases. Promote one
  only when explicitly required, reproduced, reachable through normal input,
  blocking the core flow, or a credible security/data-loss risk.
- Prefer one representative success test per behavior slice. Add failure tests
  only for required behavior, real branches, or regressions. Skip theoretical
  combinations and impossible states already excluded by a trusted boundary.
- Run narrow checks during implementation and directly affected suites at the
  final gate. Stop expanding tests when the acceptance checks and affected
  existing tests pass. Do not add coverage targets, exhaustive matrices,
  fuzzing, load tests, unrelated cleanup, or hypothetical backlogs unless
  explicitly required.

## Preflight

1. Treat the active Goal, if the host has one, plus the grilled conversation as
   the durable objective. Do not create a second harness ledger.
2. Record `workflow_base=$(git rev-parse HEAD)`, the current branch, its upstream,
   and the initial `git status`. Detached HEAD is a blocker because there is no
   current branch to persist.
3. Require either a configured upstream or an `origin` remote before editing.
   Without a push target, stop and ask the user to configure one; local commits
   alone do not satisfy this workflow's remote recovery contract.
4. Treat every initial dirty path as user-owned. Do not stage it. If the task
   must edit the same inseparable hunk, ask before proceeding.
5. Discover the project's own checks relevant to the expected changed surface.
   Do not invent generic commands when the repository documents its own, and do
   not add E2E or broad suites unless the acceptance checks need them.
6. In full mode, ensure Matt's issue-tracker/domain setup exists. If missing,
   follow `setup-matt-pocock-skills`; use discoverable defaults, but do not
   fabricate a tracker choice.

## Full mode

1. Follow `to-spec`; define the smallest end-to-end acceptance path and reuse
   testing seams already settled by the conversation.
2. Follow `to-tickets`; create tracer-bullet tickets with blocking edges, but no
   ticket for an unpromoted edge case.
3. If planning artifacts changed tracked repository files, verify their format,
   checkpoint them, and ordinary-push.
4. Work blockers-first. Treat each ticket as one `implement` phase and use the
   ticket as its durable source of truth. Apply delegated implementation and the
   shared gates below.

## Quick mode

Write a one-sentence goal and the minimum acceptance checks, then follow
`implement` directly and apply the shared gates below. Do not create a spec or
tickets. Quick mode stays with the main agent by default.

If quick work grows beyond one bounded context or reveals unresolved product
design, state that quick mode no longer fits and ask to promote it to full mode
before creating planning artifacts.

## Delegated implementation

For complex full-mode work, prefer a fresh host-native subagent for an
independently verifiable code ticket with clear ownership. Main agent owns decomposition, dependency order, integration, verification, review,
checkpointing, pushes, and the final cross-review.

1. Wait for blockers, then assign explicit non-overlapping files/modules,
   interfaces, and acceptance checks. Run concurrently only dependency-free
   slices.
2. Give the subagent minimum self-contained context: ticket goal, owned paths or
   seam, relevant repository rules, and narrow test commands. Use the host's
   no-history/fresh-context option when supported; never pass unrelated history.
   State that other agents may be editing and their work must not be reverted.
3. Subagents do not commit or push. They implement only their owned slice and
   return changed paths, check evidence, assumptions, and blockers.
4. The main agent reviews owned paths, integrates, runs relevant checks, then
   follows `checkpoint-commits`.

Use the main agent directly when a slice is trivial, ownership overlaps,
product/architecture is unresolved, or delegation would cost more context than
it saves. Do not create tickets or slices solely to use subagents. If
host-native subagents are unavailable, let the main agent implement and report
the fallback; delegation is not a workflow blocker.

## Shared gates

1. Follow `implement` inside the core-loop scope. After each coherent slice, run
   narrow checks and follow `checkpoint-commits`.
2. After implementation, run directly affected project verification once. Fix
   only failures caused by the change.
3. Run `cross-review` against `workflow_base`; it is the workflow's only review gate.
   Do not also run `code-review`.
4. Verify material findings against the scope rules. After accepted fixes,
   rerun affected checks and use cross-review's one permitted follow-up only
   when the diff changed materially.

## Persistence

Follow `checkpoint-commits`. This workflow additionally requires an ordinary
push after every checkpoint: use the upstream, or
`git push -u origin <current-branch>` when only `origin` exists.

Never use `--force`, force-with-lease, amend, rebase, squash, reset, or any
history-rewriting recovery. If push fails, keep the local commit, record the
pending SHA and reason, and continue only safe local work; do not claim the Goal complete
while required commits remain unpushed.

## Review and completion gates

If no different-model peer is available, preserve commits, finish safe
verification, and report the workflow as blocked on cross-review.

Complete when selected phases, accepted fixes, and relevant checks pass; all
workflow changes are committed and pushed; and no workflow-owned changes remain.
Acceptance checks are the stopping condition. Report the route, planning
artifacts, commits/branch, checks, review result, preserved user changes, and
blockers.
