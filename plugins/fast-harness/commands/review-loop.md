---
description: Multi-round cross-LLM review loop on the current diff/PR (codex/gemini peer, iterate to convergence, evidence-based rejects)
---

Use the `review-loop` skill to review the current change.

First state the meta-goal in one sentence and apply the deletion rule (if a
change can be removed without hurting the goal, it shouldn't exist). Then run the
single-shot preflight:

```bash
HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
  echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
  exit 2
fi
"${HARNESS_PLUGIN_ROOT}/scripts/review-context.sh" $ARGUMENTS
```

Send it to one peer (codex MCP, read-only; or shell CLI through the deterministic
wrapper):

```bash
"${HARNESS_PLUGIN_ROOT}/scripts/harness-review-peer.sh" \
  --peer "<codex|gemini|claude>" \
  --prompt-file "<round prompt file>" \
  --timeout 600 \
  --log-dir ".review-loop/<session>/peer-round-01"
```

For Claude CLI, the wrapper defaults to `--bare` stream-json mode and leaves
`meta.txt`, `raw.jsonl`, `stderr.txt`, and `claude-debug.log` in the log dir on
failure, so no-output timeouts are diagnosable. Apply only
findings you accept — rejecting a material finding requires a Verification block
(command + output), not just "the spec says so." Re-review after each round of
fixes and **iterate until the peer has no new findings** (max 5 rounds; escalate
a finding debated 2 rounds). Each round, re-check against the original goal —
rigor ≠ right. End with consensus or an Escalated Items list.
