---
description: Get a bounded different-model second review after the normal code review
---

Use the `cross-review` skill. Treat this as an optional second opinion after
Matt Pocock's `code-review`, not as a replacement workflow.

Resolve `HARNESS_PLUGIN_ROOT` from `CODEX_PLUGIN_ROOT` or `CLAUDE_PLUGIN_ROOT`,
run `scripts/review-context.sh $ARGUMENTS`, and send the resulting scope plus a
one-sentence change goal to one different-model peer through
`scripts/harness-review-peer.sh --peer auto`. Verify findings before editing.
Run at most one follow-up review after fixes, then report consensus or unresolved
items.
