---
description: Finish a lightweight SDD session after syncing tasks and evidence
---

Use the `sdd` skill. Before finishing, sync final task status in
`docs/specs/<change-id>/tasks.md` and record verification evidence or skipped
checks. Then run:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-sdd.sh" finish $ARGUMENTS
```
