---
description: Start the worktree dev environment (copy env both ends, symlink deps, launch services, health-check)
---

Use the `worktree-dev` skill. Run the start subcommand for the current worktree:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-worktree-dev.sh" start --worktree "$(pwd)" $ARGUMENTS
```

If no `.harness-dev.conf` profile exists in the worktree, read the skill's
`example.harness-dev.conf` and help the user create one first. After starting,
report the service URLs and remind: backend `/healthz` green does not prove the
frontend can log in — confirm `VITE_*` made it into the bundle.
