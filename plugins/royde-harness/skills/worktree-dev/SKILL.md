---
name: worktree-dev
description: |
  Start, inspect, or tear down a per-worktree local dev environment: copy env
  files for BOTH backend AND frontend from the main checkout, symlink the heavy
  dependency dirs, free ports, launch the service trio in the background, and
  health-check. Use when starting local dev inside a git worktree, "起服务",
  "启动前后端给我测", "worktree 里跑一下", or when verifying a frontend change
  needs a real running stack.
---

# Worktree dev environment

For a worktree-per-task workflow, every task needs the same setup ritual. This
skill drives `scripts/harness-worktree-dev.sh`, a profile-driven manager, so the
ritual is one command instead of ten.

## Run it

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/harness-worktree-dev.sh" start  --worktree <path>
"${CLAUDE_PLUGIN_ROOT}/scripts/harness-worktree-dev.sh" status --worktree <path>
"${CLAUDE_PLUGIN_ROOT}/scripts/harness-worktree-dev.sh" stop   --worktree <path>
```

`--worktree` defaults to the current directory. `--services backend,frontend`
limits the action to a subset. The script reads a profile (default
`<worktree>/.harness-dev.conf`) — see `example.harness-dev.conf` in this skill
dir for the format. The profile declares `MAIN_CHECKOUT`, `ENV_FILES`,
`SYMLINKS`, `SERVICES` (`name|port|subdir|command`), and `HEALTH`.

## The judgment the script can't make (read before claiming "it works")

The script does the mechanical work. You own these calls:

- **Copy ALL env files for BOTH ends.** A missing `frontend/.env*` does NOT
  error — Vite starts, `curl /` returns 200, backend `/healthz` is green — and
  then login is broken because `VITE_LOGTO_*` is `undefined`. List every env
  variant in the profile's `ENV_FILES`, frontend included.
- **Backend `/healthz` green ≠ the frontend can log in.** The real divide is
  whether `VITE_LOGTO_*` / `VITE_API_BASE_URL` made it into the bundle. Don't
  report success off a backend health check alone.
- **Vite snapshots `VITE_*` at startup.** If you copy/edit env after the dev
  server is up, you MUST `stop` then `start` that service — HMR will not pick up
  env changes.
- **Never remove the worktree implicitly.** `stop` leaves it intact. Only pass
  `--remove-worktree` when the user explicitly asks to clean up this worktree.

## Teardown discipline

When the user signals they're done ("测完了 / OK / 可以停了"), run `stop`
immediately — don't let background dev servers outlive the turn (resource +
port-conflict). `stop` kills recorded PIDs and frees ports but keeps the
worktree, its env copies, and its symlinks.
