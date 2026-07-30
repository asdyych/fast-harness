#!/usr/bin/env bash
# session-rules.sh — SessionStart hook for fast-harness.
#
# Injects a small set of always-on behavioral rules into every session
# (startup/clear/compact):
#   1) Address the user by their configured name at the start of every response —
#      a context-awareness signal (drop it and you've likely lost the thread).
#   2) Restate complex / multi-step requests before acting.
#   3) Keep implementation and tests focused on the core acceptance loop.
#   4) Automatically delegate independent complex-code slices with safe commits.
#   5) Require fresh command evidence before claiming verification success.
#   6) Create verified local checkpoint commits during implementation while
#      automatically pushing checkpoints in an active harness workflow.
#   7) Route the full and quick natural-language harness workflow triggers.
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
  name_rule="**Address the user as \"$NAME\" at the start of EVERY response.** If omitted, re-read the conversation before continuing."
else
  name_rule="**No name is configured yet.** In your first reply, ask the user what they would like to be called, then save it once by running: \`$PLUGIN_ROOT/scripts/harness-identity.sh set \"<name>\"\` (or set the HARNESS_USER_NAME env var). After that, address them by that name at the start of every response."
fi

rules="<fast-harness-rules>
${name_rule}

**Restate complex requests before acting.** State the goal, scope, and deliverable in one or two sentences and wait for confirmation. A harness workflow trigger confirms its route, so restate the mode and begin. Ask one clarifying question only when the request cannot be restated safely.

**Core-loop scope discipline.** Prove the smallest useful end-to-end behavior first. Do not implement or test speculative edge cases. Promote one only when required, reproduced, normally reachable, blocking the core flow, or a credible security/data-loss risk. Prefer one success test per slice; add failure tests only for required behavior, real branches, or regressions. Stop when the acceptance checks and directly affected existing tests pass. Skip exhaustive matrices, unrelated suites, and hypothetical hardening unless required.

**Complex-code delegation.** SessionStart owns automatic dispatch. Full and Quick may delegate independent slices to fresh subagents with non-overlapping ownership and minimum no-history context. Give only goal, acceptance, paths/seams, rules/interfaces, and narrow tests; keep trivial, overlapping, or unresolved work local. Subagents run necessary narrow tests. In a coordinator-granted serialized commit window, one may checkpoint-commit only owned paths; it never pushes or reverts others. The main agent schedules, reviews commits, integrates, final-verifies, cross-reviews, and pushes. Continue locally if unavailable.

**Evidence before completion claims.** Require fresh command output before claiming a fix, passing tests, or completion. State which relevant checks were not run.

**Checkpoint commits during implementation.** Coding and bug-fix tasks authorize local commits on the current branch by default. After each coherent verified slice, create a focused, buildable commit. Inspect the worktree and stage only this task's changes; preserve unrelated work. For delegated work, this authorization is limited by the serialized commit rule above. During a harness workflow, the main agent immediately ordinary-pushes every reviewed checkpoint. Outside it, pushing requires explicit authorization. User/repository rules take precedence. Never amend, rebase, squash, reset, force-push, or otherwise rewrite history without explicit authorization.

**Harness workflow routing.** \"按照 harness 的流程去实现\" selects full mode; \"快速实现\" selects quick mode. \`/fast-harness-full\` and \`/fast-harness-quick\` are fixed-mode direct aliases; remaining text is the goal. Restate the selected mode and begin unless a material product decision is unresolved. Both modes require one \`cross-review\` as the only review gate, relevant verification, checkpoint commits, and ordinary pushes.
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
