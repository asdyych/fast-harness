---
name: cross-review
description: |
  Review the current diff with a cross-model peer by default. Use for "review",
  "cross review", "peer review", "交叉 review", or when a material change needs
  an independent reviewer before merge.
---

# Default cross-model review

Use this as the default standalone review path. Matt Pocock's `code-review`
remains available when its Standards and Spec review is explicitly requested,
while `harness-workflow` uses this as its single review gate. This skill does
not create another task ledger or own the development workflow.

## Protocol

1. Run the project's own relevant checks first. If they fail, fix the known
   failure before asking another model to review.
2. State the change goal in one sentence. Treat that goal as the scope boundary.
3. Resolve the installed plugin root from whichever host is running the skill:

   ```bash
   HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
   ```

   If neither variable is available, derive the root from this `SKILL.md` path,
   two directories above this skill directory.
4. Collect the review scope in one call:

   ```bash
   "${HARNESS_PLUGIN_ROOT}/scripts/review-context.sh" [--scope auto|diff|branch|pr] [--base <ref>] [--peer auto|codex|cc|gemini]
   ```

5. Write a temporary prompt containing the goal, applicable repository rules,
   acceptance criteria or spec, and the preflight output. Ask for mismatches
   against the goal or rules plus correctness, security, data-loss, concurrency,
   and clear scope-creep findings. Require `file:line`, severity, and a concrete
   failure scenario.
6. Send the prompt to one different-model peer:

   ```bash
   "${HARNESS_PLUGIN_ROOT}/scripts/harness-review-peer.sh" \
     --peer <auto|codex|cc|gemini> \
     --prompt-file <path> \
     --timeout 1200 \
     --log-dir <temporary-log-dir>
   ```

   Prefer `auto`: when running in Codex it tries CC before Codex; on other hosts
   it tries Codex before CC. Set `HARNESS_HOST=codex|cc` only when automatic host
   detection is unavailable. Codex runs read-only and CC runs in plan mode.
7. Verify every material finding against the code. Apply only findings supported
   by evidence. Style preferences and speculative hardening are not defects.
8. If fixes materially change the diff, run one follow-up review. Stop after the
   second review and surface any unresolved disagreement to the user.

## Completion

Report the peer used, accepted fixes, rejected findings with evidence, checks
run after fixes, and unresolved items. Do not persist a review state machine in
the repository.
