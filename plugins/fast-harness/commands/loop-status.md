---
description: Show the current fast-harness loop status
---

Use the `loop` skill. Report the current loop status:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-loop.sh" status $ARGUMENTS
```

Then summarize the next action and blockers from `.harness/<change-id>/state.md`
if present.
