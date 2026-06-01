---
description: Open/stop an isolated CDP-enabled Chrome window for E2E (never touches your main Chrome)
---

Manage the isolated testing Chrome used by the `e2e-browser` skill:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/harness-chrome-cdp.sh" $ARGUMENTS
```

Subcommands: `start [--port N] [--url URL]` (fresh window on the persistent
`~/.harness/chrome-test` profile, prints the CDP endpoint), `status`, `stop`
(SIGTERM its own PID only). Attach a browser tool to `http://localhost:<port>` —
Chrome MCP, or Playwright `connectOverCDP`. Your main Chrome is never relaunched
or killed.
