---
name: verify
description: |
  Code-level green gate — frontend typecheck (tsc --noEmit) + tests with coverage
  (vitest), plus an optional backend test command. Project-agnostic via
  .harness-dev.conf, with sensible defaults. Use before declaring a change done,
  before /e2e, or on "verify", "跑测试", "typecheck + 覆盖率", "code-level coverage".
---

# Verify — the code-level green gate

The fast, deterministic layer that runs before the browser layer. It does not
replace real-browser E2E (`/e2e`) — it catches type and unit regressions cheaply
so the browser pass tests real behavior, not typos.

## Run it

First resolve the installed plugin root. In Claude Code, use
`CLAUDE_PLUGIN_ROOT`. In Codex, use `CODEX_PLUGIN_ROOT` if the host provides it;
otherwise derive the plugin root from this `SKILL.md` source path (two
directories above this skill directory) and substitute that absolute path.

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-verify.sh" [all|frontend|backend|types]
```

It runs, per the repo's `.harness-dev.conf` (all keys optional, defaults shown):

- `TYPECHECK_CMD` (default `npx tsc --noEmit`) in `FRONTEND_DIR` (default `frontend`)
- `COVERAGE_CMD` if set, else `TEST_CMD` (default `npx vitest run`) — set
  `COVERAGE_CMD="npx vitest run --coverage"` to get code-level coverage
- `BACKEND_TEST_CMD` in `BACKEND_DIR` (e.g. `uv run pytest --cov`) when configured

Missing directories are skipped, not failed. Exit 0 + `VERIFY: PASS` means every
configured check passed; `VERIFY: FAIL` (exit 1) lists what broke.

## Discipline

- **Green here is necessary, not sufficient.** `tsc` + `vitest` passing does not
  prove the user-facing flow works — follow with `/e2e` for anything that touches
  a screen, a login, or a real data path.
- **Coverage is a signal, not a goal.** Prefer one meaningful test of the real
  path over chasing a percentage with shallow tests.
- Treat a failure as the work, not noise — fix the implementation (or the test if
  the test is wrong), don't suppress it.
