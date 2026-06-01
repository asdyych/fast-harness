# Design: harness testing component (E2E real-browser + code-level coverage)

Status: **draft for review** · 2026-06-01

## Goal

Give the harness a real, repeatable testing story across two layers, **project-agnostic** — the plugin ships the *mechanism*; each repo supplies its own app URL, login flow, accounts, and test commands.

1. **Code level** — frontend `tsc --noEmit` + `vitest run --coverage` (and a backend test command when configured). The fast green gate.
2. **E2E real browser** — drive a real Chrome (via CDP) through actual business flows. Reuse a local Chrome profile so sessions persist; keep a recorded batch of test accounts; let the agent perform the test by browsing the app like a user.

## Hard constraints (from royde's habits + answers)

- **Project-agnostic.** The login is **not necessarily Logto** — it depends on the actual project. No stack, auth provider, or URL is hardcoded. The harness provides CDP + an account store + an agent protocol; the repo describes the rest.
- **Always a new Chrome window** on a dedicated, persistent testing profile (`--user-data-dir=~/.harness/chrome-test`). Never relaunches or touches the user's main Chrome — no `real`-profile mode (too intrusive).
- **Agent picks the browser tool per task** — Chrome MCP (`mcp__Claude_in_Chrome__*`) for exploratory real-ops, Playwright-over-CDP (`mcp__plugin_playwright_*`) for repeatable regression.
- **Real browser only.** No Preview MCP (gives false positives on auth/cookie/WS paths). `tsc` is a pre-check, not a substitute.
- **Never pkill Chrome** — graceful quit only; the testing instance is a separate `--user-data-dir`, stopped by SIGTERM to its own recorded PID so the user's main Chrome is never touched.
- **Accounts are secret** — `.harness/test-accounts.json`, gitignored, `chmod 600`, never committed, passwords never echoed beyond the login step.

## Components

### 1. `scripts/harness-chrome-cdp.sh` — CDP-enabled Chrome manager

```
harness-chrome-cdp.sh start  [--port 9222] [--url <url>]
harness-chrome-cdp.sh status
harness-chrome-cdp.sh stop
```

- `start` opens a **new Chrome window** as a separate instance with a dedicated, persistent `--user-data-dir=~/.harness/chrome-test` and `--remote-debugging-port=9222`. It is a fresh window on its own profile — the user's main Chrome is never relaunched or touched. Test-account logins on this profile persist across runs. Records the launch PID, verifies the CDP endpoint (`curl -s http://localhost:9222/json/version`), and prints the endpoint for the browser tool to attach to.
- `status` — is the CDP endpoint up, and on which PID.
- `stop` sends SIGTERM to the recorded testing PID only (never `pkill`, never `-9`) — the user's main Chrome is unaffected.

There is **no `real`-profile mode**: relaunching the user's logged-in Chrome is too intrusive. Testing always runs in a fresh, isolated window.

### 2. `scripts/harness-test-accounts.sh` — gitignored account store

Store: `.harness/test-accounts.json` (repo root), `chmod 600`, auto-added to `.gitignore`.

```
harness-test-accounts.sh list                      # labels + url + username + role (password MASKED)
harness-test-accounts.sh get <label> [--field f]   # emit a field for the agent to use at login time
harness-test-accounts.sh add --label L --url U --username U --password P [--role R] [--login HINT] [--notes N]
```

Generic record (no Logto assumption):
```json
{ "accounts": [
  { "label": "admin", "app_url": "http://localhost:3105", "username": "...", "password": "...",
    "role": "admin", "login": "logto|basic|oauth|custom", "notes": "free text for the agent" }
]}
```
`login` is a free hint for the agent's login flow, not a fixed enum the harness enforces.

### 3. `skills/e2e-browser/SKILL.md` — agent-driven real-browser E2E

Protocol:
1. **Bring up the browser.** If the testing Chrome isn't already up, `harness-chrome-cdp.sh start` — a fresh isolated window on the persistent testing profile.
2. **Resolve the app URL** — from the running worktree-dev frontend (`:3105`), the repo config, or ask.
3. **Pick/record an account.** `harness-test-accounts.sh list`; if the needed account isn't there, **proactively `AskUserQuestion`** to record a batch (generic fields above), persist via `add`. Reuse across sessions.
4. **Log in per the project's flow.** The agent reads the actual app and drives the login (Logto, basic, SSO, whatever it is) — not a hardcoded flow.
5. **Exercise the business flow** named by the task's acceptance criteria: navigate, interact, assert. Capture **screenshots, console errors, failed network calls** as evidence.
6. **Tool choice per task** — Chrome MCP for exploratory real-ops; Playwright-over-CDP for a repeatable regression script.
7. **Report** with evidence. Discipline: backend `/healthz` green ≠ the user can log in; a real screenshot + zero console errors is the proof. Leave the testing profile logged in; graceful-quit only if asked.

### 4. `skills/verify/SKILL.md` (+ `scripts/harness-verify.sh`) — code-level green gate

- **Frontend:** `npx tsc --noEmit` then `npx vitest run --coverage` (threshold from config, default lenient).
- **Backend:** the repo's configured test command (e.g. `uv run pytest --cov`) when present.
- Reads commands/thresholds from the repo config; sensible no-config defaults. Reports pass/fail + coverage. This is the code-level coverage that runs *alongside* E2E, not instead of it.

### 5. Config + commands

- Extend the existing `.harness-dev.conf` (one profile per repo) with test keys: `APP_URL`, `FRONTEND_DIR`, `TYPECHECK_CMD`, `TEST_CMD`, `COVERAGE_THRESHOLD`, `CHROME_PROFILE`. All optional with defaults.
- Commands: `/e2e` (skill 3), `/verify` (skill 4), `/chrome-cdp` (start/stop/status helper).

## Flow / integration with the existing harness

```
/wt-start            # worktree-dev: backend+frontend up (:8105 / :3105)
  → /verify          # tsc + vitest coverage (code level)
  → /e2e             # CDP Chrome (testing|real) → login as test account → drive business flow → evidence
  → /review-loop     # optional cross-model review, can fold in verify+e2e results
```
Reuses worktree-dev's running frontend; no new dev-server logic.

## Security

`.harness/test-accounts.json` gitignored + `0600` + never committed + passwords never logged beyond the login action. Never pkill Chrome. `real` mode warns it runs as the real account. All mechanism is generic → safe to ship; accounts and per-repo config stay local.

## Deliberately NOT in scope

- No headless CI runner (this is local, real-browser, agent-driven by design).
- No bundled Playwright test files (the agent writes/drives per task; repeatable scripts are a later, optional add).
- No auth-provider-specific code (project-agnostic).
- No account sync/secrets-manager integration (local gitignored store is the MVP).
- No settings.json / rules injection (plugin can't own that layer).

## Resolved decisions

| Question | Decision |
|---|---|
| Browser session | **Always a new Chrome window** on a dedicated persistent testing profile; no `real`-profile mode (too intrusive) |
| Login flow | **Project-defined, not Logto-specific** — harness is generic |
| Browser tool | **Agent picks per task** (Chrome MCP exploratory / Playwright regression) |
| Account store | per-repo `.harness/test-accounts.json`, gitignored, 0600 |
| Build scope | Full (CDP script + account store + e2e skill + verify skill + commands) — **after this spec is approved** |
