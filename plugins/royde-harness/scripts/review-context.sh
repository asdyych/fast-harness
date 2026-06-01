#!/usr/bin/env bash
# review-context.sh — dump the review payload (changed files + diff + status)
# for feeding a cross-LLM peer reviewer in the review-loop skill.
#
# Usage: review-context.sh [base-ref]
#   base-ref defaults to the first of: origin/main, main, origin/master, master.
set -euo pipefail

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  for c in origin/main main origin/master master; do
    git rev-parse --verify "$c" >/dev/null 2>&1 && { BASE="$c"; break; }
  done
fi
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"

echo "=== review context | base=${BASE:-<none>} head=$HEAD_SHA ==="
echo
echo "=== changed files (committed, base...HEAD) ==="
[[ -n "$BASE" ]] && git diff --stat "$BASE...HEAD" || echo "(no base ref found — review the working tree only)"
echo
echo "=== uncommitted (working tree) ==="
git status --short
echo
echo "=== committed diff (base...HEAD) ==="
[[ -n "$BASE" ]] && git diff "$BASE...HEAD"
echo
echo "=== uncommitted diff ==="
git diff
