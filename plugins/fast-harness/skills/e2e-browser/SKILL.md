---
name: e2e-browser
description: |
  Agent-driven real-browser E2E testing. Opens a fresh isolated Chrome window via
  CDP (never touches your main Chrome), logs in with a recorded test account, and
  drives the actual business flow like a user — capturing screenshots, console
  errors, and failed requests as evidence. Project-agnostic: the app URL and login
  flow come from the project, not a hardcoded provider. Use for "e2e", "browser
  test", "实际测一下", "跑一遍 onboarding/wizard", or to verify a UI change end to
  end in a real browser.
---

# Real-browser E2E

You test the app the way a user would: a real Chrome, a real login, the real
business flow. The harness gives you an isolated browser and an account store;
you supply the judgment about what the flow should do.

## Why real browser (discipline)

- **Real browser only. No Preview MCP** — its simulated env diverges from real
  behavior on the exact paths that matter (auth, cookies, localStorage,
  WebSocket). `tsc`/`vitest` are a pre-check, not a substitute (run `/verify`).
- **Backend `/healthz` green does NOT prove the user can log in** — a real
  screenshot of the post-login screen with zero console errors is the proof.
- **Never pkill Chrome.** Use the script's `stop` (SIGTERM to its own PID only).

## Protocol

1. **Bring up the browser.** If the testing Chrome isn't up:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/harness-chrome-cdp.sh" start [--port 9222]
   ```
   A fresh isolated window on a persistent profile (`~/.harness/chrome-test`).
   Test-account logins persist there across runs, so step 3 is usually a no-op
   after the first time.

2. **Resolve the app URL.** Prefer the running worktree-dev frontend (the port
   from your `.harness-dev.conf` frontend service), else its `APP_URL`, else ask.

3. **Get a test account.**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/harness-test-accounts.sh" list
   ```
   If the account you need isn't there, **proactively `AskUserQuestion`** to
   record a batch — label, app URL, username, password, role, and a one-line
   *login hint* (what kind of login the app uses). Persist via `add`. Reuse
   across sessions. Never paste a password into the transcript beyond the actual
   login action.

4. **Attach a browser tool and drive — agent picks per task.**
   - **Chrome MCP** (`mcp__Claude_in_Chrome__*`) for exploratory real-ops: it
     drives the running Chrome directly. Good for "log in and click through X".
   - **Playwright over CDP** (`mcp__plugin_playwright_*`, `connectOverCDP("http://localhost:<port>")`)
     for a repeatable regression script.
   Read the actual app to perform the login (it is **not** assumed to be Logto —
   follow whatever the project uses, guided by the account's `login` hint).

5. **Exercise the business flow** named by the task's acceptance criteria:
   navigate, interact, assert. Capture **screenshots** of key states, the
   **console** (zero errors expected), and any **failed network calls**.

6. **Report with evidence**, then leave the testing profile logged in for reuse.
   Run `stop` only when asked, or before a turn boundary if you started it just
   for this check.

## Composes with

`/wt-start` (dev env up) → `/verify` (code: tsc + vitest) → `/e2e` (this) →
`/review-loop`. This skill reuses worktree-dev's running frontend; it does not
start dev servers itself.
