---
description: Advance a fast-harness SDD loop by one bounded round, or multiple safe rounds with --yes
---

Use the `loop` skill. This command is agent-driven; `harness-loop.sh` only
records deterministic state.

Default mode advances one round:

1. Inspect SDD docs, manifest, `state.md`, checkpoints, and evidence.
2. Select the smallest next action tied to one checkpoint acceptance criterion.
3. Execute only non-destructive in-scope work.
4. Record evidence under `.harness/<change-id>/evidence/`.
5. Update `state.md` and append a concise `loop.log.md` event.
6. Run:
   ```bash
   HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
   if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
     echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
     exit 2
   fi
   "${HARNESS_PLUGIN_ROOT}/scripts/harness-loop.sh" tick <change-id> --progress changed|unchanged
   ```
7. Report the result and stop.

If `$ARGUMENTS` includes `--yes`, continue for bounded safe rounds only. Stop
immediately for destructive operations, missing credentials, ambiguous
requirements, unexpected dirty changes, inconclusive verification, review-loop
stalemate, or loop stop conditions.
