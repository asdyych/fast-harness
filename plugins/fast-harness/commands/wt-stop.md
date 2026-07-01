---
description: Stop the worktree dev environment (kill service PIDs, free ports; worktree left intact)
---

Use the `worktree-dev` skill. Stop the dev services for the current worktree:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-worktree-dev.sh" stop --worktree "$(pwd)" $ARGUMENTS
```

This kills the recorded service PIDs and frees their ports but leaves the
worktree, its env copies, and its symlinks intact. Only add `--remove-worktree`
if the user explicitly asked to delete this worktree.
