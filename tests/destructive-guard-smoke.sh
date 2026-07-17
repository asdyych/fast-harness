#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${1:?usage: destructive-guard-smoke.sh <destructive_guard.sh>}"
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Send one Bash command through the CC PreToolUse hook protocol.
run_guard() {
  local command="$1"
  python3 - "$command" <<'PY' | "$SCRIPT"
import json
import sys

print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
PY
}

run_guard "npm test"
run_guard "kubectl delete pod disposable-worker"
run_guard "rm -rf node_modules"

if run_guard "terraform destroy -auto-approve" 2> "$tmp/blocked.err"; then
  echo "expected terraform destroy to be blocked" >&2
  exit 1
fi
grep -q "terraform/tofu destroy" "$tmp/blocked.err"

run_guard "terraform destroy -auto-approve #DESTRUCTIVE-OK" 2> "$tmp/override.err"
grep -q "override marker present" "$tmp/override.err"

if run_guard "psql -c 'DROP TABLE accounts'" 2> "$tmp/sql.err"; then
  echo "expected destructive SQL to be blocked" >&2
  exit 1
fi
grep -q "destructive SQL" "$tmp/sql.err"
