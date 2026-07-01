---
description: Open/stop an isolated CDP-enabled Chrome window for E2E (never touches your main Chrome)
---

Manage the isolated testing Chrome used by the `e2e-browser` skill:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-chrome-cdp.sh" $ARGUMENTS
```

Subcommands: `start [--port N] [--url URL]` (fresh window on the persistent
`~/.harness/chrome-test` profile, prints the CDP endpoint), `status`, `stop`
(SIGTERM its own PID only). Attach a browser tool to `http://localhost:<port>` —
Chrome MCP, or Playwright `connectOverCDP`. Your main Chrome is never relaunched
or killed.
