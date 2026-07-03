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
test -f docs/specs/add-sdd-flow/learnings.md
test -f .harness/add-sdd-flow/manifest.json
test -f .harness/add-sdd-flow/checkpoints.md
test -f .harness/add-sdd-flow/task-log.md
test -f .harness/add-sdd-flow/state.md
test -f .harness/add-sdd-flow/loop.log.md
test -d .harness/add-sdd-flow/evidence
grep -qxF '.harness/*' .gitignore
grep -qxF '!.harness/config.json' .gitignore
git check-ignore -q .harness/add-sdd-flow/manifest.json
if git check-ignore -q .harness/config.json; then
  echo "expected .harness/config.json to be trackable" >&2
  exit 1
fi
python3 - <<'PY'
import json
with open(".harness/add-sdd-flow/manifest.json") as f:
    data = json.load(f)
assert data["change_id"] == "add-sdd-flow"
assert data["status"] == "active"
assert data["loop"]["phase"] == "planning"
assert data["loop"]["round"] == 0
assert data["loop"]["max_rounds"] == 10
assert data["loop"]["no_progress_rounds"] == 0
assert data["loop"]["max_no_progress_rounds"] == 2
PY
grep -q 'Status: active' .harness/add-sdd-flow/checkpoints.md
grep -q 'Goal:' .harness/add-sdd-flow/state.md
grep -q '## Constraints' docs/specs/add-sdd-flow/learnings.md
grep -q '## Events' .harness/add-sdd-flow/loop.log.md

mkdir -p .harness
cat > .harness/config.json <<'JSON'
{
  "sdd_language": "zh-CN",
  "loop": {
    "max_rounds": 4,
    "max_no_progress_rounds": 1
  }
}
JSON
"$SCRIPT" start chinese-flow > chinese-start.out
grep -q '# 规格说明：chinese-flow' docs/specs/chinese-flow/spec.md
grep -q '# 设计说明：chinese-flow' docs/specs/chinese-flow/design.md
grep -q '# 任务清单：chinese-flow' docs/specs/chinese-flow/tasks.md
grep -q '# 经验沉淀：chinese-flow' docs/specs/chinese-flow/learnings.md
grep -q '# Loop 状态：chinese-flow' .harness/chinese-flow/state.md
python3 - <<'PY'
import json
with open(".harness/chinese-flow/manifest.json") as f:
    data = json.load(f)
assert data["loop"]["max_rounds"] == 4
assert data["loop"]["max_no_progress_rounds"] == 1
PY

for legacy_ignore in '.harness/' '/.harness/' '.harness'; do
  legacy_tmp="$(mktemp -d)"
  (
    cd "$legacy_tmp"
    git init -q
    printf '# tmp\n' > README.md
    printf '%s\n' "$legacy_ignore" > .gitignore
    git add README.md .gitignore
    git commit -qm init
    "$SCRIPT" start legacy-ignore-flow > legacy-start.out
    grep -qxF '.harness/*' .gitignore
    grep -qxF '!.harness/config.json' .gitignore
    if git check-ignore -q .harness/config.json; then
      echo "expected .harness/config.json to be trackable after migrating $legacy_ignore" >&2
      exit 1
    fi
    printf '{"sdd_language":"en"}\n' > .harness/config.json
    git add .harness/config.json
  )
  rm -rf "$legacy_tmp"
done

printf 'custom spec content\n' > docs/specs/add-sdd-flow/spec.md
"$SCRIPT" start add-sdd-flow > start-again.out
grep -q 'custom spec content' docs/specs/add-sdd-flow/spec.md
python3 - <<'PY'
import json
path = ".harness/add-sdd-flow/manifest.json"
with open(path) as f:
    data = json.load(f)
data["loop"]["status"] = "stopped"
data["loop"]["stop_reason"] = "manual-review"
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
"$SCRIPT" start add-sdd-flow > start-preserve-stop.out
python3 - <<'PY'
import json
with open(".harness/add-sdd-flow/manifest.json") as f:
    data = json.load(f)
assert data["loop"]["status"] == "stopped"
assert data["loop"]["stop_reason"] == "manual-review"
PY

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
