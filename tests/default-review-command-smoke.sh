#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="${1:?usage: default-review-command-smoke.sh <plugin-root>}"
REVIEW_COMMAND="$PLUGIN_ROOT/commands/review.md"
CROSS_REVIEW_SKILL="$PLUGIN_ROOT/skills/cross-review/SKILL.md"

test -f "$REVIEW_COMMAND"
grep -qF 'Use the `cross-review` skill.' "$REVIEW_COMMAND"
grep -qF 'default cross-model review path' "$REVIEW_COMMAND"
grep -qF 'Review the current diff with a cross-model peer by default.' "$CROSS_REVIEW_SKILL"
grep -qF 'default standalone review path' "$CROSS_REVIEW_SKILL"
