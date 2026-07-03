#!/usr/bin/env bash
# harness-loop.sh — deterministic loop state bookkeeping for fast-harness.
#
# The script owns counters and stop/resume state only. Agents own semantic
# decisions such as what to do next or whether implementation is correct.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "harness-loop.sh must be run inside a git repository" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
usage:
  harness-loop.sh status [change-id]
  harness-loop.sh tick <change-id> --progress changed|unchanged
  harness-loop.sh stop <change-id> [--reason <reason>]
  harness-loop.sh resume <change-id>
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

require_python3() {
  command -v python3 >/dev/null 2>&1 || die "python3 is required for harness-loop.sh"
}

now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

validate_change_id() {
  local id="${1:-}"
  [[ -n "$id" ]] || die "missing change-id"
  [[ "$id" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "invalid change-id: $id"
}

latest_change_id() {
  local latest_manifest
  latest_manifest="$(ls -t "$ROOT"/.harness/*/manifest.json 2>/dev/null | head -1 || true)"
  [[ -n "$latest_manifest" ]] || die "no SDD sessions found (create one with /sdd-start <change-id>)"
  basename "$(dirname "$latest_manifest")"
}

session_paths() {
  local id="$1"
  validate_change_id "$id"
  HARNESS_DIR="$ROOT/.harness/$id"
  MANIFEST="$HARNESS_DIR/manifest.json"
  STATE_FILE="$HARNESS_DIR/state.md"
  LOOP_LOG="$HARNESS_DIR/loop.log.md"
  TASK_LOG="$HARNESS_DIR/task-log.md"
  [[ -f "$MANIFEST" ]] || die "no SDD session for change-id: $id"
}

json_get() {
  local path="$1"
  local expr="$2"
  local default="$3"
  python3 - "$path" "$expr" "$default" <<'PY'
import json, sys
path, expr, default = sys.argv[1:4]
with open(path) as f:
    data = json.load(f)
value = data
for part in expr.split("."):
    if not isinstance(value, dict) or part not in value:
        print(default)
        sys.exit(0)
    value = value[part]
print(value)
PY
}

append_loop_event() {
  local id="$1"
  local round="$2"
  local action="$3"
  local decision="$4"
  local result="$5"
  local stop_reason="$6"
  [[ -f "$LOOP_LOG" ]] || {
    printf '# Loop Log: %s\n\n## Events\n' "$id" > "$LOOP_LOG"
  }
  {
    echo
    echo "- Round: $round"
    echo "  Action: $action"
    echo "  Decision: $decision"
    echo "  Evidence: $MANIFEST"
    echo "  Result: $result"
    echo "  Stop reason: $stop_reason"
  } >> "$LOOP_LOG"
  if [[ -f "$TASK_LOG" ]]; then
    {
      echo
      echo "- Loop round $round: $decision -> $result${stop_reason:+ ($stop_reason)}"
    } >> "$TASK_LOG"
  fi
}

update_loop() {
  local manifest="$1"
  local mode="$2"
  local progress="${3:-}"
  local reason="${4:-}"
  local now="$5"
  python3 - "$manifest" "$mode" "$progress" "$reason" "$now" <<'PY'
import json, sys
path, mode, progress, reason, now = sys.argv[1:6]
with open(path) as f:
    data = json.load(f)
loop = data.setdefault("loop", {})
loop.setdefault("phase", "planning")
loop.setdefault("round", 0)
loop.setdefault("max_rounds", 10)
loop.setdefault("no_progress_rounds", 0)
loop.setdefault("max_no_progress_rounds", 2)
loop.setdefault("status", "active")
loop.setdefault("last_progress_at", "")
loop.setdefault("last_tick_at", "")

if mode == "tick":
    if progress not in {"changed", "unchanged"}:
        print("progress must be changed or unchanged", file=sys.stderr)
        sys.exit(2)
    if loop.get("status") == "stopped":
        print("loop is stopped; resume before ticking", file=sys.stderr)
        sys.exit(2)
    loop["round"] = int(loop.get("round", 0)) + 1
    if progress == "changed":
        loop["no_progress_rounds"] = 0
        loop["last_progress_at"] = now
    else:
        loop["no_progress_rounds"] = int(loop.get("no_progress_rounds", 0)) + 1
    loop["last_tick_at"] = now
    loop["status"] = "active"
    loop.pop("stop_reason", None)
    result = "continue"
    stop_reason = "none"
    if int(loop["round"]) >= int(loop.get("max_rounds", 10)):
        loop["status"] = "stopped"
        loop["stop_reason"] = "max-rounds"
        result = "stop"
        stop_reason = "max-rounds"
    if int(loop["no_progress_rounds"]) >= int(loop.get("max_no_progress_rounds", 2)):
        loop["status"] = "stopped"
        loop["stop_reason"] = "no-progress"
        result = "stop"
        stop_reason = "no-progress"
elif mode == "stop":
    loop["status"] = "stopped"
    loop["stop_reason"] = reason or "manual"
    loop["last_tick_at"] = now
    result = "stop"
    stop_reason = loop["stop_reason"]
elif mode == "resume":
    if loop.get("stop_reason") == "max-rounds":
        print("max-rounds stop is terminal; raise loop.max_rounds or start a new SDD session", file=sys.stderr)
        sys.exit(2)
    loop["status"] = "active"
    loop["stop_reason"] = ""
    loop["last_tick_at"] = now
    result = "resumed"
    stop_reason = "none"
else:
    print(f"unknown update mode: {mode}", file=sys.stderr)
    sys.exit(2)

data["updated_at"] = now
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"{result}|{stop_reason}|{loop['round']}")
PY
}

status_loop() {
  local id="${1:-}"
  [[ -n "$id" ]] || id="$(latest_change_id)"
  session_paths "$id"
  echo "change-id: $id"
  echo "status: $(json_get "$MANIFEST" "loop.status" "active")"
  echo "phase: $(json_get "$MANIFEST" "loop.phase" "planning")"
  echo "round: $(json_get "$MANIFEST" "loop.round" "0")/$(json_get "$MANIFEST" "loop.max_rounds" "10")"
  echo "no-progress: $(json_get "$MANIFEST" "loop.no_progress_rounds" "0")/$(json_get "$MANIFEST" "loop.max_no_progress_rounds" "2")"
  echo "current-checkpoint: $(json_get "$MANIFEST" "current_checkpoint" "checkpoint-1")"
  if [[ -f "$STATE_FILE" ]]; then
    grep -E '^(Next action:|下一步：|Blockers:|阻塞项：)' "$STATE_FILE" || true
  fi
}

tick_loop() {
  local id="$1"
  shift
  local progress=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --progress) progress="${2:-}"; shift 2;;
      *) shift;;
    esac
  done
  [[ -n "$progress" ]] || die "missing --progress changed|unchanged"
  session_paths "$id"
  local out result reason round now
  now="$(now_utc)"
  out="$(update_loop "$MANIFEST" tick "$progress" "" "$now")"
  IFS='|' read -r result reason round <<< "$out"
  append_loop_event "$id" "$round" "tick" "progress $progress" "$result" "$reason"
  if [[ "$result" == "stop" ]]; then
    echo "LOOP: STOP $reason"
  else
    echo "LOOP: CONTINUE"
  fi
}

stop_loop() {
  local id="$1"
  shift
  local reason="manual"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason) reason="${2:-manual}"; shift 2;;
      *) reason="$1"; shift;;
    esac
  done
  session_paths "$id"
  local out result stop_reason round now
  now="$(now_utc)"
  out="$(update_loop "$MANIFEST" stop "" "$reason" "$now")"
  IFS='|' read -r result stop_reason round <<< "$out"
  append_loop_event "$id" "$round" "stop" "manual stop" "$result" "$stop_reason"
  echo "LOOP: STOP $stop_reason"
}

resume_loop() {
  local id="$1"
  session_paths "$id"
  local out result reason round now
  now="$(now_utc)"
  out="$(update_loop "$MANIFEST" resume "" "" "$now")"
  IFS='|' read -r result reason round <<< "$out"
  append_loop_event "$id" "$round" "resume" "manual resume" "$result" "$reason"
  echo "LOOP: RESUMED"
  status_loop "$id"
}

cmd="${1:-}"
[[ -n "$cmd" ]] || { usage; exit 2; }
shift || true
require_python3

case "$cmd" in
  status)
    [[ $# -le 1 ]] || { usage; exit 2; }
    status_loop "${1:-}"
    ;;
  tick)
    [[ $# -ge 1 ]] || { usage; exit 2; }
    id="$1"; shift
    tick_loop "$id" "$@"
    ;;
  stop)
    [[ $# -ge 1 ]] || { usage; exit 2; }
    id="$1"; shift
    stop_loop "$id" "$@"
    ;;
  resume)
    [[ $# -eq 1 ]] || { usage; exit 2; }
    resume_loop "$1"
    ;;
  *)
    usage
    exit 2
    ;;
esac
