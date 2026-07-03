---
description: Stop the current fast-harness loop and record a reason
---

Use the `loop` skill. Stop the loop:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-loop.sh" stop $ARGUMENTS
```

After stopping, summarize the stop reason and the next human decision needed.
