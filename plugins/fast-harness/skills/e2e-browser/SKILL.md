---
name: e2e-browser
description: |
  Run a real-browser E2E flow through Trace Browser and its existing fingerprint
  profiles, then capture screenshots, console errors, and failed requests. Use
  for "e2e", "browser test", "实际测一下", or to verify a UI/login flow end to end.
---

# Trace Browser E2E

Test the app the way a user would through Trace Browser. Reuse its managed
fingerprint profiles and signed-in sessions instead of maintaining a second
Chrome profile or a plaintext credential store in this plugin.

## Boundaries

- Use a real browser. Simulated previews diverge on auth, cookies, localStorage,
  and WebSocket behavior.
- Prefer Trace Browser. Do not launch generic Chrome while its LaunchServer is
  available.
- Reuse a signed-in Trace profile. If login is required, ask the user to choose
  or prepare the appropriate profile; never print credentials.
- A green backend health check is not proof of a working user flow.

## Protocol

1. Check Trace Browser LaunchServer, normally at `http://127.0.0.1:19876`:

   ```bash
   curl -fsS http://127.0.0.1:19876/api/profiles
   ```

   When the server requires a key, read `TRACE_BROWSER_API_KEY` and optional
   `TRACE_BROWSER_API_KEY_HEADER` from the environment. Do not print the key.
2. Select an already-running profile whose purpose and signed-in state match the
   task. If several profiles are plausible, ask the user rather than guessing.
3. Launch only when needed. Use `GET /api/launch/<launchCode>` when a launch code
   is available, otherwise `POST /api/launch` with `{"profileId":"..."}`.
4. Read `debugPort` or `cdpUrl` from the launch response and attach Playwright or
   another CDP-capable browser tool. A local probe helper may be used for
   diagnostics when the project documents one, but the HTTP/CDP contract is
   authoritative.
5. Trace Browser RPA at `127.0.0.1:64606/trace/proto` requires an app-injected
   IPC token. Use it only when the user explicitly requests RPA.
6. Resolve the running app URL from project documentation or service output. Ask
   when it cannot be discovered safely.
7. Exercise the requested acceptance flow and capture screenshots, console
   errors, and failed network requests. A screenshot alone is insufficient when
   the console or network shows a failed business request.
8. Leave profile lifecycle to Trace Browser. Do not kill the browser or mutate
   or delete its profiles as cleanup.

## Fallback

If LaunchServer is unavailable, report that fact and use an already-configured
generic browser automation tool only when it provides an isolated session. Do
not silently switch to the user's everyday Chrome profile.
