---
description: Run a lean cross-LLM review loop on the current diff/PR (codex/gemini peer, apply accepted fixes, max 2 rounds)
---

Use the `review-loop` skill to review the current change.

First state the meta-goal of the change in one sentence, then gather context:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/review-context.sh" $ARGUMENTS
```

Send it to one peer reviewer (codex MCP, read-only sandbox; or `gemini` CLI),
biased toward simplicity. Apply only findings you accept, re-review once if you
changed something substantive, and stop after at most two rounds — checking the
diff against the original goal, not against self-consistency. Rigor ≠ right.
