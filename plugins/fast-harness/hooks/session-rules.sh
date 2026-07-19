#!/usr/bin/env bash
# session-rules.sh — SessionStart hook for fast-harness.
#
# Injects a small set of always-on behavioral rules into every session
# (startup/clear/compact):
#   1) Address the user by their configured name at the start of every response —
#      a context-awareness signal (drop it and you've likely lost the thread).
#   2) Restate complex / multi-step requests before acting.
#   3) Require fresh command evidence before claiming verification success.
#   4) Create verified local checkpoint commits during implementation while
#      automatically pushing checkpoints in an active harness workflow.
#   5) Route the full and quick natural-language harness workflow triggers.
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

**Restate complex requests before acting.** For any non-trivial or multi-step request, first restate it back in one or two sentences — the goal, the scope, and the deliverable — and let the user confirm you understood correctly before starting work. A recognized harness workflow trigger is itself confirmation of the selected route, so restate that route and begin without asking again. If you cannot restate the request confidently, ask one clarifying question instead of assuming. This catches a misunderstanding before it costs real work.

**Evidence before completion claims.** Do not claim that code is fixed, tests pass, or work is complete without fresh command output from the current change. State clearly when a relevant check was not run.

**Checkpoint commits during implementation.** For coding and bug-fix tasks, local commits on the current branch are authorized by default. Do not leave a large verified diff uncommitted until the end: after each coherent, independently understandable milestone, run the relevant checks and create a focused checkpoint commit. Inspect the worktree first and stage only this task's changes; never absorb, revert, or overwrite unrelated user work. Keep each commit buildable and revertable, avoid WIP commits, and use one final commit only when the task is genuinely a single small step. During an active harness workflow, immediately ordinary-push every checkpoint to the current branch; the workflow trigger is authorization for those pushes. Outside a harness workflow, pushing still requires explicit user authorization. A user or repository rule that says not to commit or push takes precedence. Never amend, rebase, squash, reset, force-push, or otherwise rewrite history without explicit user authorization.

**Harness workflow routing.** When the user says \"按照 harness 的流程去实现\", \"按 harness 流程实现\", or an equivalent full-flow request, use the \`harness-workflow\` skill in full mode. When the user says \"快速实现\", \"quick implement\", or an equivalent quick-flow request, use it in quick mode. \`/fast-harness-full\` and \`/fast-harness-quick\` are fixed-mode direct aliases; treat everything after either command as the goal, never as a mode override. The trigger confirms the route: restate the selected mode, then start without asking for a second confirmation unless a material product decision is unresolved. Both modes require normal code review, \`cross-review\`, relevant verification, and automatic checkpoint commit plus ordinary push.
</fast-harness-rules>"

# Emit the Claude Code SessionStart additionalContext as JSON (json.dumps handles
# all escaping). This plugin wires SessionStart for Claude Code only. python is
# the only encoder used — if it is unavailable, skip injection cleanly (exit 0)
# rather than break the session.
PYBIN="$(command -v python3 || command -v python || true)"
[[ -z "$PYBIN" ]] && exit 0

HARNESS_RULES="$rules" "$PYBIN" -c '
import json, os
ctx = os.environ["HARNESS_RULES"]
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}}))
'
exit 0
