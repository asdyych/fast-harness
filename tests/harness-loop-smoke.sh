#!/usr/bin/env bash
set -euo pipefail

SDD_SCRIPT="${1:?usage: harness-loop-smoke.sh <harness-sdd.sh> <harness-loop.sh>}"
LOOP_SCRIPT="${2:?usage: harness-loop-smoke.sh <harness-sdd.sh> <harness-loop.sh>}"
SDD_SCRIPT="$(cd "$(dirname "$SDD_SCRIPT")" && pwd)/$(basename "$SDD_SCRIPT")"
LOOP_SCRIPT="$(cd "$(dirname "$LOOP_SCRIPT")" && pwd)/$(basename "$LOOP_SCRIPT")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cd "$tmp"
git init -q
printf '# tmp\n' > README.md
git add README.md
git commit -qm init

mkdir -p .harness
cat > .harness/config.json <<'JSON'
{
  "loop": {
    "max_rounds": 3,
    "max_no_progress_rounds": 2
  }
}
JSON

"$SDD_SCRIPT" start loop-flow > start.out

"$LOOP_SCRIPT" status loop-flow > status.out
grep -q 'change-id: loop-flow' status.out
grep -q 'status: active' status.out
grep -q 'phase: planning' status.out
grep -q 'round: 0/3' status.out
grep -q 'no-progress: 0/2' status.out

"$LOOP_SCRIPT" tick loop-flow --progress changed > tick-changed.out
grep -q 'LOOP: CONTINUE' tick-changed.out
python3 - <<'PY'
import json
with open(".harness/loop-flow/manifest.json") as f:
    data = json.load(f)
loop = data["loop"]
assert loop["round"] == 1
assert loop["no_progress_rounds"] == 0
assert loop["last_progress_at"]
assert loop["last_tick_at"]
PY
grep -q 'Decision: progress changed' .harness/loop-flow/loop.log.md

"$LOOP_SCRIPT" tick loop-flow --progress unchanged > tick-unchanged-1.out
grep -q 'LOOP: CONTINUE' tick-unchanged-1.out
"$LOOP_SCRIPT" tick loop-flow --progress unchanged > tick-unchanged-2.out
grep -q 'LOOP: STOP no-progress' tick-unchanged-2.out
python3 - <<'PY'
import json
with open(".harness/loop-flow/manifest.json") as f:
    data = json.load(f)
loop = data["loop"]
assert loop["round"] == 3
assert loop["no_progress_rounds"] == 2
assert loop["status"] == "stopped"
assert loop["stop_reason"] == "no-progress"
PY

"$LOOP_SCRIPT" resume loop-flow > resume.out
grep -q 'LOOP: RESUMED' resume.out
"$LOOP_SCRIPT" stop loop-flow --reason manual-pause > stop.out
grep -q 'LOOP: STOP manual-pause' stop.out
python3 - <<'PY'
import json
with open(".harness/loop-flow/manifest.json") as f:
    data = json.load(f)
loop = data["loop"]
assert loop["status"] == "stopped"
assert loop["stop_reason"] == "manual-pause"
PY
if "$LOOP_SCRIPT" tick loop-flow --progress changed > tick-stopped.out 2> tick-stopped.err; then
  echo "expected tick on stopped loop to fail" >&2
  exit 1
fi
grep -q 'loop is stopped; resume before ticking' tick-stopped.err

"$SDD_SCRIPT" start max-round-flow > max-start.out
"$LOOP_SCRIPT" tick max-round-flow --progress changed > max-1.out
grep -q 'LOOP: CONTINUE' max-1.out
"$LOOP_SCRIPT" tick max-round-flow --progress changed > max-2.out
grep -q 'LOOP: CONTINUE' max-2.out
"$LOOP_SCRIPT" tick max-round-flow --progress changed > max-3.out
grep -q 'LOOP: STOP max-rounds' max-3.out
if "$LOOP_SCRIPT" resume max-round-flow > max-resume.out 2> max-resume.err; then
  echo "expected resume after max-rounds to fail" >&2
  exit 1
fi
grep -q 'max-rounds stop is terminal' max-resume.err

if "$LOOP_SCRIPT" tick loop-flow --progress maybe > bad-progress.out 2> bad-progress.err; then
  echo "expected invalid progress to fail" >&2
  exit 1
fi
grep -q 'progress must be changed or unchanged' bad-progress.err

if "$LOOP_SCRIPT" status missing-flow > missing.out 2> missing.err; then
  echo "expected missing status to fail" >&2
  exit 1
fi
grep -q 'no SDD session' missing.err
