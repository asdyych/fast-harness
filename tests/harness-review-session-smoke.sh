#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${1:?usage: harness-review-session-smoke.sh <harness-review-session.sh>}"
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cd "$tmp"
git init -q
printf '# tmp\n' > README.md
git add README.md
git commit -qm init

"$SCRIPT" init --meta-goal "keep scripts deterministic" --peer claude --max-rounds 3 > init.out
grep -q 'review-session:' init.out
session_id="$(sed -n 's/^review-session: //p' init.out)"
test -n "$session_id"
test -f ".review-loop/$session_id/meta.json"
test -f ".review-loop/$session_id/summary.md"
test -f ".review-loop/latest"
grep -qxF '.review-loop/' .gitignore
test "$session_id" = "$(cat .review-loop/latest)"

python3 - "$session_id" <<'PY'
import json, sys
session_id = sys.argv[1]
with open(f".review-loop/{session_id}/meta.json") as f:
    data = json.load(f)
assert data["session_id"] == session_id
assert data["meta_goal"] == "keep scripts deterministic"
assert data["peer"] == "claude"
assert data["max_rounds"] == 3
assert data["status"] == "active"
assert data["round_count"] == 0
PY

"$SCRIPT" init --meta-goal "second session should not overwrite first" --peer claude --max-rounds 3 > second-init.out
second_session_id="$(sed -n 's/^review-session: //p' second-init.out)"
test -n "$second_session_id"
test "$session_id" != "$second_session_id"
python3 - "$session_id" <<'PY'
import json, sys
with open(f".review-loop/{sys.argv[1]}/meta.json") as f:
    data = json.load(f)
assert data["meta_goal"] == "keep scripts deterministic"
assert data["round_count"] == 0
PY

"$SCRIPT" round "$session_id" \
  --decision "accepted deterministic ledger" \
  --result "fixed" \
  --findings 1 \
  --accepted 1 \
  --rejected 0 \
  --escalated "none" \
  --evidence "tests/harness-review-session-smoke.sh" > round.out
grep -q 'round: 1' round.out
test -f ".review-loop/$session_id/round-01.json"
python3 - "$session_id" <<'PY'
import json, sys
session_id = sys.argv[1]
with open(f".review-loop/{session_id}/meta.json") as f:
    meta = json.load(f)
assert meta["round_count"] == 1
assert meta["status"] == "active"
with open(f".review-loop/{session_id}/round-01.json") as f:
    round_data = json.load(f)
assert round_data["round"] == 1
assert round_data["findings"] == 1
assert round_data["accepted"] == 1
assert round_data["rejected"] == 0
assert round_data["escalated"] == "none"
assert round_data["decision"] == "accepted deterministic ledger"
assert round_data["result"] == "fixed"
assert round_data["evidence"] == "tests/harness-review-session-smoke.sh"
PY

"$SCRIPT" round "$session_id" \
  --decision "no new findings" \
  --result "consensus" \
  --findings 0 \
  --accepted 0 \
  --rejected 0 \
  --escalated "none" \
  --evidence "tests/harness-review-session-smoke.sh" > consensus.out
grep -q 'status: consensus' consensus.out
python3 - "$session_id" <<'PY'
import json, sys
with open(f".review-loop/{sys.argv[1]}/meta.json") as f:
    data = json.load(f)
assert data["round_count"] == 2
assert data["status"] == "consensus"
PY

"$SCRIPT" summary --session ".review-loop/$session_id" > summary.out
grep -q 'status: consensus' summary.out
grep -q 'round-count: 2' summary.out
grep -q 'accepted deterministic ledger' ".review-loop/$session_id/summary.md"
grep -q 'no new findings' ".review-loop/$session_id/summary.md"
grep -q 'Escalated items' ".review-loop/$session_id/summary.md"
grep -q 'none' ".review-loop/$session_id/summary.md"

"$SCRIPT" path "$session_id" > path.out
grep -q ".review-loop/$session_id" path.out
"$SCRIPT" path > latest-path.out
grep -q ".review-loop/$second_session_id" latest-path.out

if "$SCRIPT" init --meta-goal "bad" --max-rounds 0 > bad-init.out 2> bad-init.err; then
  echo "expected max-rounds 0 to fail" >&2
  exit 1
fi
grep -q 'max-rounds must be a positive integer' bad-init.err

if "$SCRIPT" round missing-session --decision x --result y --findings 0 --accepted 0 --rejected 0 > missing.out 2> missing.err; then
  echo "expected missing session to fail" >&2
  exit 1
fi
grep -q 'no review-loop session' missing.err

"$SCRIPT" init --meta-goal "timeout is not consensus" --peer claude --max-rounds 3 > escalated-init.out
escalated_session_id="$(sed -n 's/^review-session: //p' escalated-init.out)"
"$SCRIPT" round "$escalated_session_id" \
  --decision "peer timed out" \
  --result "escalated" \
  --findings 0 \
  --accepted 0 \
  --rejected 0 \
  --escalated "external peer timeout" \
  --evidence "timeout claude -p review" > escalated-round.out
grep -q 'status: escalated' escalated-round.out
python3 - "$escalated_session_id" <<'PY'
import json, sys
with open(f".review-loop/{sys.argv[1]}/meta.json") as f:
    data = json.load(f)
assert data["status"] == "escalated"
PY
