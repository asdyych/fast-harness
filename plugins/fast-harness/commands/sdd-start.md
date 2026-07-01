---
description: Start a lightweight SDD session (spec/design/tasks + local checkpoint ledger)
---

Use the `sdd` skill. Start an SDD session for the requested change id:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/harness-sdd.sh" start $ARGUMENTS
```

After the script runs, fill or refine `docs/specs/<change-id>/spec.md`,
`design.md`, and `tasks.md`, then derive executable checkpoints in
`.harness/<change-id>/checkpoints.md`.
