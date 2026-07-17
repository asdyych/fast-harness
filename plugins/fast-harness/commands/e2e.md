---
description: Run real-browser E2E through a Trace Browser fingerprint profile
---

Use the `e2e-browser` skill. Query Trace Browser LaunchServer at
`http://127.0.0.1:19876`, choose or ask for the appropriate fingerprint profile,
launch it through `/api/launch`, connect through the returned CDP endpoint, and
drive the business flow described by `$ARGUMENTS`. Capture screenshots, console
errors, and failed requests. Do not launch or kill generic Chrome while Trace
Browser is available.
