---
name: sdd
description: |
  Lightweight spec-driven development workflow for fast-harness. Use when the
  user asks to start, continue, inspect, or finish an SDD/spec-driven change,
  wants OpenSpec-style spec/design/tasks without a heavy plugin, or asks for
  "sdd", "spec driven", "spec留档", "task记录", "checkpoint", or "执行账本".
---

# SDD — lightweight spec-driven development

Use a small spec bundle plus a local execution ledger. The durable docs record
what the change is; the `.harness` state records how this session executed it.

## Files

Durable, git-tracked:

```text
docs/specs/<change-id>/
  spec.md
  design.md
  tasks.md
```

Local, gitignored:

```text
.harness/<change-id>/
  manifest.json
  checkpoints.md
  task-log.md
  evidence/
```

## Run it

Resolve the installed plugin root first. In Claude Code, `CLAUDE_PLUGIN_ROOT` is
available. In Codex, use `CODEX_PLUGIN_ROOT` if provided; otherwise derive the
plugin root from this `SKILL.md` source path, two directories above this skill
directory.

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-sdd.sh" start  <change-id>
"${HARNESS_PLUGIN_ROOT}/scripts/harness-sdd.sh" status [change-id]
"${HARNESS_PLUGIN_ROOT}/scripts/harness-sdd.sh" finish <change-id>
```

`change-id` must be lowercase letters, digits, dots, underscores, or hyphens.

## Protocol

1. **Start or inspect the session.**
   - If no SDD session exists for the request, run `start <change-id>`.
   - If the user asks about progress, run `status [change-id]`.
   - If continuing work, read `manifest.json`, `spec.md`, `design.md`,
     `tasks.md`, `checkpoints.md`, and `task-log.md`.

2. **Make the spec executable before coding.**
   Fill or refine:
   - `spec.md`: goal, scope, out of scope, acceptance criteria.
   - `design.md`: affected files, approach, risks, verification layers.
   - `tasks.md`: user-readable task list.
   - `checkpoints.md`: agent execution slices with command-checkable or
     file-checkable acceptance.

3. **Execute checkpoint by checkpoint.**
   Keep `checkpoints.md` as the active execution ledger. Update `task-log.md`
   after meaningful actions, decisions, verification outputs, and skipped checks.
   Do not turn `task-log.md` into a raw shell transcript.

4. **Use existing harness gates.**
   - Run targeted tests for touched behavior.
   - Run `verify` before claiming code-level completion.
   - Run `e2e-browser` for UI, login, browser, or real data path changes.
   - Run `review-loop` before merge or for material changes.
   Store short summaries under `.harness/<change-id>/evidence/` when useful.

5. **Finish deliberately.**
   Before `finish`, sync final task status into `docs/specs/<change-id>/tasks.md`
   and record verification evidence or skipped-check reasons. Then run:
   ```bash
   "${HARNESS_PLUGIN_ROOT}/scripts/harness-sdd.sh" finish <change-id>
   ```

## Guardrails

- Treat `spec.md` as the scope guard. If implementation diverges, update the
  durable docs before continuing.
- Keep `tasks.md` user-readable; put session details in `task-log.md`.
- Keep `checkpoints.md` operational; do not duplicate the full spec there.
- Prefer a small, real checkpoint over a broad planner phase.
- Do not install or emulate the full OpenSpec lifecycle.
