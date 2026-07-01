---
description: Show which worktree dev services are running and whether their ports are up
---

Use the `worktree-dev` skill. Report the dev service status for the current worktree:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-worktree-dev.sh" status --worktree "$(pwd)" $ARGUMENTS
```
