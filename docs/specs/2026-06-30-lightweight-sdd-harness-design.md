# Design: lightweight SDD harness layer

Status: **draft for review** · 2026-06-30

## Goal

Add a lightweight spec-driven development layer to fast-harness by absorbing the useful parts of OpenSpec's workflow without adopting a heavy plugin or lifecycle.

The harness should keep using its existing strengths: worktree setup, code-level verification, real-browser E2E, review-loop, clean-context, and retro. The new layer provides the missing front half: a small, durable spec/design/tasks structure plus an execution checkpoint ledger that agents can follow and resume.

## Direction

Use **SDD as the driver**, not a heavyweight Planner phase.

The user-facing source of truth is a small spec bundle. The agent execution source of truth is a separate checkpoint ledger. The two are linked by `change-id`, but they serve different purposes:

- `docs/specs/<change-id>/` is durable documentation for the change.
- `.harness/<change-id>/` is the local execution workspace and evidence ledger.

This keeps the best OpenSpec ideas: one change per folder, spec/design/tasks separation, and a task list that survives the session. It avoids proposal/archive machinery, extra daemon state, and an additional plugin dependency.

## Directory layout

Durable, git-tracked documentation:

```text
docs/specs/<change-id>/
  spec.md       # goal, scope, behavior, acceptance criteria
  design.md     # technical approach, boundaries, risks, test strategy
  tasks.md      # user-readable task list and final completion state
```

Local, gitignored execution state:

```text
.harness/<change-id>/
  manifest.json       # change id, status, current checkpoint, doc paths
  checkpoints.md      # ordered execution checkpoints derived from spec/design
  task-log.md         # what the agent actually did, in execution order
  evidence/
    verify.md         # code-level verification summary
    e2e.md            # browser evidence summary when applicable
    review-loop.md    # peer review consensus/escalation summary
```

`.harness/` already fits the local process-state role used by test accounts and similar harness artifacts. A future implementation should ensure `.harness/` is gitignored in consuming repos when an SDD session is initialized.

## File responsibilities

### `spec.md`

The behavioral contract. It should answer:

- What user or system outcome is required?
- What is explicitly in scope?
- What is explicitly out of scope?
- What acceptance criteria prove the change is done?
- What constraints came directly from the user?

This file should stay implementation-light. It is the document the agent checks before adding scope.

### `design.md`

The technical plan. It should answer:

- Which modules, files, commands, or skills are expected to change?
- What data flow or state changes are introduced?
- What risks are known?
- What compatibility or migration concerns exist?
- Which verification layers are required: tests, `/verify`, `/e2e`, `/review-loop`.

The design can be short. Its job is to make execution deliberate, not ceremonial.

### `tasks.md`

The durable task record. It should be readable after the session and map to the user's goal, not every tiny edit.

Example:

```text
- [ ] Add SDD session initialization skill and command.
- [ ] Generate spec/design/tasks templates from a change id.
- [ ] Add checkpoint ledger creation and update rules.
- [ ] Document the SDD workflow in README.
- [ ] Verify the implementation with targeted tests or script checks.
```

### `checkpoints.md`

The agent execution plan. It is more operational than `tasks.md` and should be safe to resume from.

Example:

```text
## Checkpoint 1: Session scaffold

Status: pending

Acceptance:
- `docs/specs/<change-id>/` is created with complete templates.
- `.harness/<change-id>/manifest.json` points to the doc bundle.

Evidence:
- Command output or file paths recorded in `task-log.md`.
```

### `task-log.md`

The chronological execution trace. It should record meaningful actions, decisions, verification outputs, and skipped checks with reasons. It is not a verbose shell transcript.

## Workflow

```text
sdd start <change-id>
  -> create or update docs/specs/<change-id>/{spec,design,tasks}.md
  -> create .harness/<change-id>/{manifest,checkpoints,task-log}.*
  -> derive checkpoints from spec/design/tasks

sdd execute
  -> work checkpoint by checkpoint
  -> update task-log.md after each meaningful action
  -> update checkpoints.md status as work passes local acceptance

sdd verify
  -> run targeted checks
  -> run /verify when code changed
  -> run /e2e for UI, login, or real data path changes
  -> run /review-loop before merge or on material changes
  -> store summaries under .harness/<change-id>/evidence/

sdd finish
  -> sync final task status into docs/specs/<change-id>/tasks.md
  -> leave .harness/<change-id>/ as local execution evidence
  -> run retro when harness friction repeats or the workflow itself needs improvement
```

## Skill and command surface

Add a new shared skill:

```text
skills/sdd/SKILL.md
```

The skill should cover:

- when to create an SDD session;
- how to fill `spec.md`, `design.md`, and `tasks.md`;
- how to derive checkpoints;
- how to keep `task-log.md` current;
- how to decide which verification layers apply;
- how to finish and summarize.

For Claude Code, add thin slash commands that route to the skill:

```text
/sdd-start <change-id>
/sdd-status [change-id]
/sdd-checkpoint [change-id]
/sdd-finish [change-id]
```

For Codex, users trigger the same flow by asking for the SDD workflow directly. Codex installs the shared skill and scripts; it does not need slash commands.

## Script support

Keep scripts mechanical and small. The agent owns judgment.

Candidate script:

```text
scripts/harness-sdd.sh
```

Commands:

```text
harness-sdd.sh start <change-id>
harness-sdd.sh status [change-id]
harness-sdd.sh checkpoint <change-id> --complete <checkpoint-id>
harness-sdd.sh finish <change-id>
```

Responsibilities:

- create directories and template files;
- write `manifest.json`;
- ensure `.harness/` is gitignored in the consuming repo;
- print paths and current status;
- avoid interpreting the spec or deciding task scope.

Do not build a full OpenSpec clone. No proposal approval engine, no archive command, no schema-heavy validation, no daemon, and no cross-repo state.

## Integration with existing fast-harness skills

The SDD layer should compose with existing skills instead of replacing them:

- `worktree-dev`: start the local environment when implementation needs running services.
- `verify`: write code-level evidence to `.harness/<change-id>/evidence/verify.md`.
- `e2e-browser`: write browser evidence to `.harness/<change-id>/evidence/e2e.md`.
- `review-loop`: write peer review summary to `.harness/<change-id>/evidence/review-loop.md`.
- `clean-context`: dispatch independent exploration or review while keeping the SDD ledger authoritative.
- `retro`: improve the harness when SDD friction repeats.

Superpowers remains complementary. Use its brainstorming, TDD, debugging, and verification disciplines inside the SDD workflow when those skills are available. The SDD layer should not vendor or duplicate Superpowers.

## Guardrails

- Keep the change folder small enough to read in one session.
- Do not let `tasks.md` become a shell transcript.
- Do not let `checkpoints.md` become a second spec.
- If implementation diverges from `spec.md` or `design.md`, update the durable docs before continuing.
- Every non-trivial checkpoint needs at least one command-checkable or file-checkable acceptance criterion.
- If a verification layer is skipped, record the reason in `task-log.md` or the relevant evidence file.

## Deliberately not in scope

- Installing or wrapping the OpenSpec plugin.
- Recreating OpenSpec proposal/archive commands.
- Replacing the existing review-loop, verify, e2e, or worktree-dev flows.
- Enforcing a rigid JSON schema for every task or checkpoint.
- Creating autonomous planner agents as the default path.

## Resolved decisions

| Question | Decision |
|---|---|
| OpenSpec dependency | Do not add it; absorb the lightweight spec/design/tasks pattern |
| Driver | SDD drives the work; no heavyweight Planner phase by default |
| Durable docs | `docs/specs/<change-id>/{spec.md,design.md,tasks.md}` |
| Execution state | `.harness/<change-id>/` with manifest, checkpoints, task log, and evidence |
| Commands | Add thin SDD commands for Claude Code; Codex uses the shared skill |
| Scripts | Optional small `harness-sdd.sh` for filesystem mechanics only |
