#!/usr/bin/env bash
# session-rules.sh — SessionStart hook for fast-harness.
#
# Injects two always-on behavioral rules into every session (startup/clear/compact):
#   1) Address the user by their configured name at the start of every response —
#      a context-awareness signal (drop it and you've likely lost the thread).
#   2) Restate complex / multi-step requests before acting, so the user can
#      confirm the agent understood correctly.
#
# These are *additional context*, not user instructions — the user's own
# CLAUDE.md always takes precedence. Name lookup: HARNESS_USER_NAME env, else the
# global ~/.harness/identity file (set via scripts/harness-identity.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NAME="${HARNESS_USER_NAME:-}"
IDFILE="${HARNESS_IDENTITY_FILE:-$HOME/.harness/identity}"
if [[ -z "$NAME" && -f "$IDFILE" ]]; then
  NAME="$(head -n1 "$IDFILE" 2>/dev/null | tr -d '\r\n' || true)"
fi

if [[ -n "$NAME" ]]; then
  name_rule="**Address the user as \"$NAME\" at the start of EVERY response.** This is a context-awareness signal — if you ever forget it, you have probably lost the thread of the conversation; stop and re-read before continuing."
else
  name_rule="**No name is configured yet.** In your first reply, ask the user what they would like to be called, then save it once by running: \`$PLUGIN_ROOT/scripts/harness-identity.sh set \"<name>\"\` (or set the HARNESS_USER_NAME env var). After that, address them by that name at the start of every response."
fi

rules="<fast-harness-rules>
${name_rule}

**Restate complex requests before acting.** For any non-trivial or multi-step request, first restate it back in one or two sentences — the goal, the scope, and the deliverable — and let the user confirm you understood correctly before starting work. If you cannot restate it confidently, ask one clarifying question instead of assuming. This catches a misunderstanding before it costs real work.
</fast-harness-rules>"

# Emit only the field the current host consumes (mirrors superpowers' contract).
# JSON is built with python's json.dumps for bulletproof escaping.
if [[ -n "${CURSOR_PLUGIN_ROOT:-}" ]]; then mode=cursor
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -z "${COPILOT_CLI:-}" ]]; then mode=claude
else mode=sdk
fi

HARNESS_RULES="$rules" python3 -c '
import json, os, sys
ctx = os.environ["HARNESS_RULES"]
mode = sys.argv[1]
if mode == "cursor":
    print(json.dumps({"additional_context": ctx}))
elif mode == "claude":
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}}))
else:
    print(json.dumps({"additionalContext": ctx}))
' "$mode"
exit 0
