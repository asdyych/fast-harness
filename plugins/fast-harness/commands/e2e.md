---
description: Agent-driven real-browser E2E — isolated CDP Chrome, login with a recorded test account, drive the business flow, capture evidence
---

Use the `e2e-browser` skill.

Bring up an isolated testing Chrome (never your main one):

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-chrome-cdp.sh" start $ARGUMENTS
```

Resolve the app URL (prefer the running worktree-dev frontend), get a test
account (`harness-test-accounts.sh list`; if missing, ask the user and record a
batch), attach a browser tool (Chrome MCP for exploratory, Playwright over CDP
for repeatable), log in per the project's actual flow, and drive the business
flow the task names. Capture screenshots + console + failed requests as evidence.
Real browser only — backend `/healthz` green doesn't prove login works. Leave the
profile logged in; `stop` only when asked.
