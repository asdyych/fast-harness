---
name: loop
description: |
  Lightweight Loop Engineering support for fast-harness SDD sessions. Use when
  the user asks to inspect, tick, stop, resume, or automatically advance a
  loop with /fast-harness-loop. Keeps semantic planning in the agent and
  deterministic counters in scripts.
---

# Loop — supervised SDD execution loop

Use loop state to keep a long-running SDD change resumable and bounded. The
loop layer sits above `sdd`: SDD records the durable spec, while loop state
records where execution is, what happened this round, and when to stop.

## Files

Durable:

```text
docs/specs/<change-id>/
  spec.md
  design.md
  tasks.md
  learnings.md
```

Local, gitignored:

```text
.harness/<change-id>/
  manifest.json
  checkpoints.md
  task-log.md
  state.md
  loop.log.md
  evidence/
```

Project config, git-tracked:

```text
.harness/config.json
```

## Script boundary

`harness-loop.sh` is intentionally small. It only owns deterministic state:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-loop.sh" status [change-id]
"${HARNESS_PLUGIN_ROOT}/scripts/harness-loop.sh" tick <change-id> --progress changed|unchanged
"${HARNESS_PLUGIN_ROOT}/scripts/harness-loop.sh" stop <change-id> [--reason <reason>]
"${HARNESS_PLUGIN_ROOT}/scripts/harness-loop.sh" resume <change-id>
```

The script does **not** decide the next implementation step, run tests, spawn
agents, or determine correctness. The agent does that by reading the SDD docs,
state, checkpoints, and evidence.

## Stop conditions

Development v1 uses two hard brakes:

- `max_rounds`: stop once the round counter reaches this value.
- `max_no_progress_rounds`: stop after this many consecutive `unchanged` ticks.

Do not add cost or token accounting unless a future integration provides a
trustworthy source. Do not fabricate cost numbers.

## Commands

- `/loop-status [change-id]`: read-only state summary.
- `/loop-next [change-id]`: propose the next action, then wait for confirmation.
- `/loop-tick <change-id> changed|unchanged`: record one round outcome.
- `/loop-stop <change-id> [reason]`: stop and record why.
- `/loop-resume <change-id>`: resume and show state.
- `/fast-harness-loop [change-id] [--max-rounds N] [--yes]`: agent-driven loop
  advancement.

## `/fast-harness-loop` discipline

Default mode advances one round only:

1. Inspect `manifest.json`, `state.md`, `checkpoints.md`, `tasks.md`, and recent
   evidence.
2. Choose the smallest next action tied to one checkpoint acceptance criterion.
3. Execute only if the action is non-destructive and within the current spec.
4. Record evidence under `.harness/<change-id>/evidence/`.
5. Update `state.md` and append a concise `loop.log.md` event.
6. Run `harness-loop.sh tick ... --progress changed|unchanged`.
7. Report the result and stop.

With `--yes`, repeat bounded rounds, but still stop immediately if any of these
occur:

- an action is destructive or outside the spec;
- credentials, private config, or external approval are missing;
- requirements or acceptance criteria are ambiguous;
- the worktree has unexpected dirty changes;
- verification cannot determine pass/fail;
- review-loop reaches a stalemate;
- `max_rounds` or `max_no_progress_rounds` is reached.

## Composition rules

- Use `sdd` first if no SDD session exists.
- Use `worktree-dev` before a checkpoint that needs running services.
- Use `verify` after code changes that can be checked deterministically.
- Use `e2e-browser` for UI, login, browser, or real data path changes.
- Use `review-loop` before merge or for material changes.
- Use `clean-context` for independent exploration, broad reads, or fresh review.
- Use `retro` only for repeated harness friction or explicit retrospectives.
- If MCP/plugins/external tools are needed, record the dependency and purpose in
  `state.md` or `design.md`; do not auto-configure external systems unless the
  checkpoint explicitly requires it.

## Privacy

`loop.log.md` records round, action, decision, evidence path, result, and stop
reason. Do not record full prompts, credentials, cookies, tokens, or long raw
command output. Put long outputs under `evidence/` and summarize them.
