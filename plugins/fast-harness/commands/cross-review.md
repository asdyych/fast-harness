---
description: Review the current change with a different-model peer
---

Use the `cross-review` skill. This is the default standalone review path;
Matt Pocock's `code-review` remains available when its Standards and Spec
review is explicitly requested. Inside `harness-workflow`, this is the single
review gate; do not also run `code-review`.

Resolve `HARNESS_PLUGIN_ROOT` from `CODEX_PLUGIN_ROOT` or `CLAUDE_PLUGIN_ROOT`,
run `scripts/review-context.sh $ARGUMENTS`, and send the resulting scope plus a
one-sentence change goal to one different-model peer through
`scripts/harness-review-peer.sh --peer auto`. Verify findings before editing.
Run at most one follow-up review after fixes, then report consensus or unresolved
items.
