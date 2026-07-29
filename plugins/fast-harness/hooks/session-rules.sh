#!/usr/bin/env bash
# session-rules.sh — SessionStart hook for fast-harness.
#
# Injects a small set of always-on behavioral rules into every session
# (startup/clear/compact):
#   1) Address the user by their configured name at the start of every response —
#      a context-awareness signal (drop it and you've likely lost the thread).
#   2) Restate complex / multi-step requests before acting.
#   3) Keep implementation and tests focused on the core acceptance loop.
#   4) Delegate independent complex-code slices while the main agent integrates.
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

**Complex-code delegation.** In full mode, the main agent orchestrates and reviews while fresh subagents implement independent slices with non-overlapping ownership and minimum self-contained context. Quick mode must promote to full before delegation. Subagents do not commit or push; the checkpoint rule applies to the main agent, which integrates and verifies. Do not create slices solely for delegation.

**Evidence before completion claims.** Require fresh command output before claiming a fix, passing tests, or completion. State which relevant checks were not run.

**Checkpoint commits during implementation.** Coding and bug-fix tasks authorize local commits on the current branch by default. After each coherent verified slice, create a focused, buildable commit. Inspect the worktree and stage only this task's changes; preserve unrelated work. During a harness workflow, immediately ordinary-push every checkpoint. Outside it, pushing requires explicit authorization. User/repository rules take precedence. Never amend, rebase, squash, reset, force-push, or otherwise rewrite history without explicit authorization.

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
