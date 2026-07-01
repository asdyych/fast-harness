---
description: Code-level green gate — frontend typecheck (tsc) + tests with coverage (vitest) + optional backend tests
---

Use the `verify` skill. Run the code-level checks:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-verify.sh" $ARGUMENTS
```

Reads commands/coverage from `.harness-dev.conf` (defaults: `npx tsc --noEmit`,
`npx vitest run`). `VERIFY: PASS` means every configured check passed; missing
dirs are skipped. Green here is necessary but not sufficient — follow with `/e2e`
for anything that touches a screen, a login, or a real data path.
