#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${1:?usage: session-rules-smoke.sh <session-rules.sh>}"
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

HARNESS_USER_NAME="royde" "$SCRIPT" > "$tmp/output.json"

python3 - "$tmp/output.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

context = payload["hookSpecificOutput"]["additionalContext"]
required = [
    'Address the user as "royde"',
    "Checkpoint commits during implementation",
    "Core-loop scope discipline",
    "Complex-code delegation",
    "SessionStart owns automatic dispatch",
    "Full and Quick may delegate independent slices",
    "non-overlapping ownership",
    "minimum no-history context",
    "narrow tests",
    "Subagents run necessary narrow tests",
    "coordinator-granted serialized commit window",
    "may checkpoint-commit only owned paths",
    "never pushes or reverts others",
    "main agent schedules, reviews commits, integrates, final-verifies, cross-reviews, and pushes",
    "Do not implement or test speculative edge cases",
    "Stop when the acceptance checks and directly affected existing tests pass",
    "authorize local commits on the current branch by default",
    "stage only this task's changes",
    "main agent immediately ordinary-pushes every reviewed checkpoint",
    "Harness workflow routing",
    "按照 harness 的流程去实现",
    "快速实现",
    "/fast-harness-full",
    "/fast-harness-quick",
    "fixed-mode direct aliases",
    "Both modes require one `cross-review` as the only review gate",
    "Never amend, rebase, squash, reset, force-push",
]

for phrase in required:
    if phrase not in context:
        raise SystemExit(f"missing session rule phrase: {phrase}")

if "Commit only on explicit request" in context:
    raise SystemExit("obsolete commit rule is still injected")

for obsolete in [
    "Quick mode must promote to full before delegation",
    "Subagents do not commit or push",
    "checkpoint rule applies to the main agent",
]:
    if obsolete in context:
        raise SystemExit(f"obsolete delegation rule is still injected: {obsolete}")
PY
