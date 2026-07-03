---
description: Record one loop round as changed or unchanged
---

Use the `loop` skill. Record one loop tick:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-loop.sh" tick $ARGUMENTS
```

Use `changed` when the round produced meaningful progress toward a checkpoint
acceptance criterion. Use `unchanged` when no material progress was made.
