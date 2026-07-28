#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="${1:?usage: context-budget-smoke.sh <plugin-root>}"

markdown_words="$(
  find "$PLUGIN_ROOT/skills" "$PLUGIN_ROOT/commands" \
    -type f -name '*.md' -print0 |
    xargs -0 cat |
    wc -w |
    tr -d ' '
)"
(( markdown_words <= 2800 )) || {
  echo "skill and command context exceeds 2800 words: $markdown_words" >&2
  exit 1
}

session_words="$(
  HARNESS_USER_NAME=royde "$PLUGIN_ROOT/hooks/session-rules.sh" |
    python3 -c 'import json, sys; print(len(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"].split()))'
)"
(( session_words <= 400 )) || {
  echo "SessionStart context exceeds 400 words: $session_words" >&2
  exit 1
}
