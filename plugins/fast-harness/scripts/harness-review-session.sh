#!/usr/bin/env bash
# harness-review-session.sh — deterministic local ledger for review-loop rounds.
#
# The script records session metadata and round summaries only. Agents own peer
# selection, review prompts, triage, fixes, and convergence judgment.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "harness-review-session.sh must be run inside a git repository" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
usage:
  harness-review-session.sh init --meta-goal <goal> [--peer <name>] [--max-rounds <n>]
  harness-review-session.sh round <session-id> --decision <text> --result <text> --findings <n> --accepted <n> --rejected <n> [--escalated <text>] [--evidence <path>]
  harness-review-session.sh summary [session-id|--session <id-or-dir>]
  harness-review-session.sh path [session-id|--session <id-or-dir>]
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

require_python3() {
  command -v python3 >/dev/null 2>&1 || die "python3 is required for harness-review-session.sh"
}

now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

is_positive_int() {
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

is_nonnegative_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

ensure_gitignore() {
  local ignore="$ROOT/.gitignore"
  [[ -f "$ignore" ]] || : > "$ignore"
  grep -qxF '.review-loop/' "$ignore" || {
    [[ -s "$ignore" ]] && echo >> "$ignore"
    echo ".review-loop/" >> "$ignore"
  }
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1], ensure_ascii=False))' "$1"
}

session_path() {
  local id="$1"
  [[ -n "$id" ]] || die "missing session-id"
  id="${id%/}"
  id="${id#./}"
  id="${id#.review-loop/}"
  [[ "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid session-id: $id"
  SESSION_DIR="$ROOT/.review-loop/$id"
  META_FILE="$SESSION_DIR/meta.json"
  SUMMARY_FILE="$SESSION_DIR/summary.md"
  [[ -f "$META_FILE" ]] || die "no review-loop session: $id"
}

latest_session_id() {
  local latest="$ROOT/.review-loop/latest"
  [[ -f "$latest" ]] || die "no review-loop sessions found"
  local id
  id="$(cat "$latest")"
  [[ -n "$id" ]] || die "empty latest review-loop session"
  echo "$id"
}

slugify_peer() {
  local peer="$1"
  peer="$(printf '%s' "$peer" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-')"
  peer="${peer#-}"
  peer="${peer%-}"
  [[ -n "$peer" ]] || peer="peer"
  printf '%s' "$peer"
}

write_summary() {
  local id="$1"
  local meta="$ROOT/.review-loop/$id/meta.json"
  local summary="$ROOT/.review-loop/$id/summary.md"
  python3 - "$meta" "$summary" <<'PY'
import glob
import json
import os
import sys

meta_path, summary_path = sys.argv[1:3]
with open(meta_path) as f:
    meta = json.load(f)

rounds = []
for path in sorted(glob.glob(os.path.join(os.path.dirname(meta_path), "round-*.json"))):
    with open(path) as f:
        rounds.append(json.load(f))

lines = [
    f"# Review Loop Session: {meta['session_id']}",
    "",
    f"- Meta-goal: {meta['meta_goal']}",
    f"- Peer: {meta['peer']}",
    f"- Status: {meta['status']}",
    f"- Round count: {meta['round_count']}/{meta['max_rounds']}",
    f"- Created: {meta['created_at']}",
    f"- Updated: {meta['updated_at']}",
    "",
    "## Rounds",
]
if not rounds:
    lines.append("")
    lines.append("- No rounds recorded yet.")
else:
    for item in rounds:
        lines.extend([
            "",
            f"### Round {item['round']}",
            "",
            f"- Decision: {item['decision']}",
            f"- Result: {item['result']}",
            f"- Findings: {item['findings']}",
            f"- Accepted: {item['accepted']}",
            f"- Rejected: {item['rejected']}",
            f"- Escalated items: {item.get('escalated') or 'none'}",
            f"- Evidence: {item['evidence'] or 'none'}",
            f"- Recorded: {item['created_at']}",
        ])

with open(summary_path, "w") as f:
    f.write("\n".join(lines) + "\n")
PY
}

init_session() {
  local meta_goal="" peer="peer" max_rounds="5"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --meta-goal) meta_goal="${2:-}"; shift 2;;
      --peer) peer="${2:-peer}"; shift 2;;
      --max-rounds) max_rounds="${2:-}"; shift 2;;
      *) usage; exit 2;;
    esac
  done
  [[ -n "$meta_goal" ]] || die "missing --meta-goal"
  is_positive_int "$max_rounds" || die "max-rounds must be a positive integer"

  ensure_gitignore
  local now session_id slug dir
  now="$(now_utc)"
  slug="$(slugify_peer "$peer")"
  session_id="$(date -u +"%Y%m%dT%H%M%SZ")-$$-$slug"
  dir="$ROOT/.review-loop/$session_id"
  mkdir -p "$dir"

  cat > "$dir/meta.json" <<EOF
{
  "session_id": $(json_escape "$session_id"),
  "meta_goal": $(json_escape "$meta_goal"),
  "peer": $(json_escape "$peer"),
  "max_rounds": $max_rounds,
  "round_count": 0,
  "status": "active",
  "created_at": $(json_escape "$now"),
  "updated_at": $(json_escape "$now")
}
EOF
  printf '%s\n' "$session_id" > "$ROOT/.review-loop/latest"
  write_summary "$session_id"

  echo "review-session: $session_id"
  echo "path: .review-loop/$session_id"
  echo "status: active"
}

record_round() {
  local id="$1"
  shift
  session_path "$id"

  local decision="" result="" findings="" accepted="" rejected="" escalated="none" evidence=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --decision) decision="${2:-}"; shift 2;;
      --result) result="${2:-}"; shift 2;;
      --findings) findings="${2:-}"; shift 2;;
      --accepted) accepted="${2:-}"; shift 2;;
      --rejected) rejected="${2:-}"; shift 2;;
      --escalated) escalated="${2:-none}"; shift 2;;
      --evidence) evidence="${2:-}"; shift 2;;
      *) usage; exit 2;;
    esac
  done
  [[ -n "$decision" ]] || die "missing --decision"
  [[ -n "$result" ]] || die "missing --result"
  is_nonnegative_int "$findings" || die "findings must be a non-negative integer"
  is_nonnegative_int "$accepted" || die "accepted must be a non-negative integer"
  is_nonnegative_int "$rejected" || die "rejected must be a non-negative integer"

  local out round status now
  now="$(now_utc)"
  out="$(python3 - "$META_FILE" "$decision" "$result" "$findings" "$accepted" "$rejected" "$escalated" "$evidence" "$now" <<'PY'
import json
import os
import sys

meta_path, decision, result, findings, accepted, rejected, escalated, evidence, now = sys.argv[1:10]
findings = int(findings)
accepted = int(accepted)
rejected = int(rejected)
with open(meta_path) as f:
    meta = json.load(f)

round_no = int(meta.get("round_count", 0)) + 1
max_rounds = int(meta.get("max_rounds", 5))
if result in {"consensus", "escalated", "deferred"}:
    status = result
elif findings == 0:
    status = "consensus"
else:
    status = "active"
if round_no >= max_rounds and status == "active":
    status = "max-rounds"

meta["round_count"] = round_no
meta["status"] = status
meta["updated_at"] = now
with open(meta_path, "w") as f:
    json.dump(meta, f, indent=2, ensure_ascii=False)
    f.write("\n")

round_path = os.path.join(os.path.dirname(meta_path), f"round-{round_no:02d}.json")
with open(round_path, "w") as f:
    json.dump({
        "round": round_no,
        "decision": decision,
        "result": result,
        "findings": findings,
        "accepted": accepted,
        "rejected": rejected,
        "escalated": escalated,
        "evidence": evidence,
        "created_at": now,
    }, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"{round_no}|{status}")
PY
)"
  IFS='|' read -r round status <<< "$out"
  write_summary "$id"
  echo "review-session: $id"
  echo "round: $round"
  echo "status: $status"
}

summary_session() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) id="${2:-}"; shift 2;;
      *) id="$1"; shift;;
    esac
  done
  [[ -n "$id" ]] || id="$(latest_session_id)"
  session_path "$id"
  id="$(basename "$SESSION_DIR")"
  write_summary "$id"
  python3 - "$META_FILE" <<'PY'
import json
import sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(f"review-session: {data['session_id']}")
print(f"status: {data['status']}")
print(f"round-count: {data['round_count']}")
print(f"summary: .review-loop/{data['session_id']}/summary.md")
PY
}

path_session() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) id="${2:-}"; shift 2;;
      *) id="$1"; shift;;
    esac
  done
  [[ -n "$id" ]] || id="$(latest_session_id)"
  session_path "$id"
  id="$(basename "$SESSION_DIR")"
  echo ".review-loop/$id"
}

cmd="${1:-}"
[[ -n "$cmd" ]] || { usage; exit 2; }
shift || true
require_python3

case "$cmd" in
  init)
    init_session "$@"
    ;;
  round)
    [[ $# -ge 1 ]] || { usage; exit 2; }
    id="$1"; shift
    record_round "$id" "$@"
    ;;
  summary)
    summary_session "$@"
    ;;
  path)
    path_session "$@"
    ;;
  *)
    usage
    exit 2
    ;;
esac
