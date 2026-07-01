#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${1:?usage: harness-sdd-smoke.sh <harness-sdd.sh>}"
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cd "$tmp"
git init -q
printf '# tmp\n' > README.md
git add README.md
git commit -qm init

"$SCRIPT" start add-sdd-flow > start.out

test -f docs/specs/add-sdd-flow/spec.md
test -f docs/specs/add-sdd-flow/design.md
test -f docs/specs/add-sdd-flow/tasks.md
test -f .harness/add-sdd-flow/manifest.json
test -f .harness/add-sdd-flow/checkpoints.md
test -f .harness/add-sdd-flow/task-log.md
test -d .harness/add-sdd-flow/evidence
grep -qxF '.harness/' .gitignore
python3 - <<'PY'
import json
with open(".harness/add-sdd-flow/manifest.json") as f:
    data = json.load(f)
assert data["change_id"] == "add-sdd-flow"
assert data["status"] == "active"
PY
grep -q 'Status: active' .harness/add-sdd-flow/checkpoints.md

printf 'custom spec content\n' > docs/specs/add-sdd-flow/spec.md
"$SCRIPT" start add-sdd-flow > start-again.out
grep -q 'custom spec content' docs/specs/add-sdd-flow/spec.md

"$SCRIPT" status add-sdd-flow > status.out
grep -q 'change-id: add-sdd-flow' status.out
grep -q 'status: active' status.out

"$SCRIPT" start z-latest-flow > latest-start.out
"$SCRIPT" status > latest-status.out
grep -q 'change-id: z-latest-flow' latest-status.out

"$SCRIPT" finish add-sdd-flow > finish.out
python3 - <<'PY'
import json
with open(".harness/add-sdd-flow/manifest.json") as f:
    data = json.load(f)
assert data["status"] == "finished"
PY
grep -q 'Finished:' .harness/add-sdd-flow/task-log.md
finished_count="$(grep -c 'Finished:' .harness/add-sdd-flow/task-log.md)"
if "$SCRIPT" finish add-sdd-flow > finish-again.out 2> finish-again.err; then
  echo "expected second finish to fail" >&2
  exit 1
fi
grep -q 'already finished' finish-again.err
test "$finished_count" = "$(grep -c 'Finished:' .harness/add-sdd-flow/task-log.md)"

"$SCRIPT" status add-sdd-flow > status-finished.out
grep -q 'status: finished' status-finished.out

if "$SCRIPT" status missing-flow > missing-status.out 2> missing-status.err; then
  echo "expected missing status to fail" >&2
  exit 1
fi
grep -q 'no SDD session' missing-status.err

if "$SCRIPT" start 'Bad Change!' > bad.out 2> bad.err; then
  echo "expected invalid change-id to fail" >&2
  exit 1
fi
grep -q 'invalid change-id' bad.err
