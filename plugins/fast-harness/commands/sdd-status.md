---
description: Show the current lightweight SDD session status
---

Use the `sdd` skill. Report the SDD session status:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-sdd.sh" status $ARGUMENTS
```

Then summarize the active checkpoint from `.harness/<change-id>/checkpoints.md`
and the latest meaningful entry from `.harness/<change-id>/task-log.md` if those
files exist.
