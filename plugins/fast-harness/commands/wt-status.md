---
description: Show which worktree dev services are running and whether their ports are up
---

Use the `worktree-dev` skill. Report the dev service status for the current worktree:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/harness-worktree-dev.sh" status --worktree "$(pwd)" $ARGUMENTS
```
