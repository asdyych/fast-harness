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
  "按 harness 流程实现", `harness full`, `/fast-harness-full`, or an equivalent
  request. Run
  `to-spec` -> `to-tickets` -> one
  `implement` phase per ticket -> `cross-review` -> full
  verification.
- **Quick mode**: "快速实现", `quick implement`, `harness quick`,
  `/fast-harness-quick`, or an equivalent request. Skip `to-spec` and
  `to-tickets`; run `implement` directly, then `cross-review` -> full
  verification.
- The explicit `/fast-harness-full` and `/fast-harness-quick` commands are
  fixed-mode direct aliases. They lock their modes: treat all following text as
  the goal and do not reinterpret it as a route override.
- If both signals appear, explicit quick wording wins. If this skill is invoked
  without a mode, use full mode.

The route phrase confirms the route and authorizes ordinary checkpoint pushes.
Restate the selected route and begin without asking for a second confirmation.
Pause only for a material product decision that the grill/context did not
settle, an inseparable dirty-worktree conflict, a destructive action, or missing
repository/tracker information that cannot be discovered.

## Upstream skills

Resolve the plugin root from `CODEX_PLUGIN_ROOT` or `CLAUDE_PLUGIN_ROOT`; when
neither exists, derive it from this file, two directories above the skill
directory. Before each Matt phase, resolve its installed source:

```bash
"${HARNESS_PLUGIN_ROOT}/scripts/resolve-matt-skill.sh" <skill-name>
```

Read the returned file in full and execute it as the phase sub-protocol. The
wrapper changes only routing, checkpoint persistence, and the mandatory final
cross-review. Matt's requirements for TDD, testing seams, and ticket shape still
apply. `code-review` remains available for explicit standalone use, but the
harness route does not run it in addition to `cross-review`. If a required Matt
skill is unavailable, stop before editing and report the missing installation.

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
5. Discover the project's own test, typecheck, lint, build, and E2E commands.
   Do not invent generic commands when the repository documents its own.
6. In full mode, ensure Matt's issue-tracker/domain setup exists. If missing,
   follow `setup-matt-pocock-skills`; use discoverable defaults, but do not
   fabricate a tracker choice.

## Full mode

1. Follow `to-spec` using the grilled conversation. Reuse testing seams already
   confirmed during grilling. Ask about a seam only when the existing context
   does not settle it.
2. Follow `to-tickets` and create tracer-bullet tickets with blocking edges. The
   route trigger approves a recommended breakdown that stays within the agreed
   scope; ask only when a split changes scope or introduces a material choice.
3. If planning artifacts changed tracked repository files, verify their format,
   checkpoint-commit them, and ordinary-push immediately.
4. Work the ticket frontier blockers-first. Bound each ticket as its own phase
   and use the ticket as the source of truth when Goal mode continues in a fresh
   turn or context.
5. For each ticket, record `ticket_base`, follow `implement`, and apply
   `checkpoint-commits` after every coherent verified slice. Override and skip
   the `code-review` phase offered by `implement`; the workflow's single review
   gate is the aggregate `cross-review`. Rerun the relevant checks,
   checkpoint-commit, ordinary-push, and update ticket status.
6. When all tickets are done, run the full relevant project verification. Fix,
   verify, commit, and push any failures.
7. Run the single mandatory `cross-review` against `workflow_base`. Verify every
   finding;
   after accepted fixes, rerun relevant checks, commit, ordinary-push, and run
   the skill's one allowed follow-up review when the diff changed materially.

## Quick mode

1. Write a one-sentence goal and concrete acceptance checks in the working
   context; do not create a spec or tickets.
2. Record `workflow_base`, follow `implement` directly, and apply
   `checkpoint-commits` after every coherent verified slice. Override and skip
   the `code-review` phase offered by `implement`; the workflow's single review
   gate is `cross-review`.
3. Run relevant project verification. Fix failures, verify, commit, and
   ordinary-push.
4. Run the single mandatory `cross-review` against `workflow_base`. Verify
   findings; after
   accepted fixes, rerun checks, commit, ordinary-push, and use the one allowed
   follow-up review when needed.
5. Run the full relevant verification once at the end. Commit and ordinary-push
   any final fix.

If quick work grows beyond one bounded context or reveals unresolved product
design, state that quick mode no longer fits and ask to promote it to full mode
before creating planning artifacts.

## Persistence contract

At every checkpoint:

1. Run the narrow relevant checks and inspect the diff.
2. Stage only this workflow's files or hunks; never absorb initial user changes.
3. Run `git diff --cached --check` and create a focused, buildable commit.
4. If an upstream exists, run ordinary `git push`. Otherwise, when `origin`
   exists, run `git push -u origin <current-branch>`.

Never use `--force`, force-with-lease, amend, rebase, squash, reset, or any
history-rewriting recovery. If push fails, keep the local commit, record the
pending SHA and reason, and continue only safe local work. Retry ordinary push
after later checkpoints, but do not claim the Goal complete while required
commits remain unpushed.

## Review and completion gates

Different-model `cross-review` is the workflow's only review gate. Do not also
run normal `code-review`; it remains an explicit standalone capability. If no
peer is available, do not fake or silently skip cross-review: preserve all
commits, finish safe verification, and report the workflow as blocked on that
gate.

Complete only when all selected phases, accepted review fixes, and relevant
checks pass; every workflow-owned change is committed; every required ordinary
push succeeds; and the worktree contains no new workflow-owned changes. Report
the route, spec/tickets used, commits and remote branch, checks, the review
result, any preserved pre-existing changes, and any unresolved blocker.
