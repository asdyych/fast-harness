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
    "local commits on the current branch are authorized by default",
    "stage only this task's changes",
    "immediately ordinary-push every checkpoint",
    "Harness workflow routing",
    "按照 harness 的流程去实现",
    "快速实现",
    "/fast-harness-full",
    "/fast-harness-quick",
    "fixed-mode direct aliases",
    "Both modes require normal code review, `cross-review`",
    "Never amend, rebase, squash, reset, force-push",
]

for phrase in required:
    if phrase not in context:
        raise SystemExit(f"missing session rule phrase: {phrase}")

if "Commit only on explicit request" in context:
    raise SystemExit("obsolete commit rule is still injected")
PY
