---
description: Resume a stopped fast-harness loop and show current state
---

Use the `loop` skill. Resume the loop:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-loop.sh" resume $ARGUMENTS
```

Then inspect `state.md` and `checkpoints.md`, summarize the next proposed action,
and wait for confirmation before executing.
