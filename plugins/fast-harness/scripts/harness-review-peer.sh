#!/usr/bin/env bash
# harness-review-peer.sh - invoke one shell CLI peer for review-loop.
#
# The script is intentionally thin: the agent still owns prompt construction,
# triage, fixes, and convergence. This wrapper makes CLI invocation repeatable
# and leaves diagnostics when a peer hangs or exits without a final answer.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  harness-review-peer.sh --peer codex|gemini|claude --prompt-file <path> [--timeout <seconds>] [--log-dir <dir>]

environment:
  HARNESS_REVIEW_PEER_CLAUDE_MODE=bare|safe-mode   default: bare
  HARNESS_REVIEW_PEER_INCLUDE_PARTIALS=1           include Claude partial chunks in raw.jsonl
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

PEER=""
PROMPT_FILE=""
TIMEOUT=600
LOG_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --peer) PEER="${2:-}"; shift 2 ;;
    --prompt-file) PROMPT_FILE="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --log-dir) LOG_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown option: $1" ;;
  esac
done

[[ -n "$PEER" ]] || die "missing --peer"
[[ -n "$PROMPT_FILE" ]] || die "missing --prompt-file"
[[ -f "$PROMPT_FILE" ]] || die "prompt file not found: $PROMPT_FILE"
[[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] || die "timeout must be a positive integer"

if [[ -z "$LOG_DIR" ]]; then
  LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/harness-review-peer.XXXXXX")"
fi
mkdir -p "$LOG_DIR"

RAW_LOG="$LOG_DIR/raw.jsonl"
STDERR_LOG="$LOG_DIR/stderr.txt"
DEBUG_LOG="$LOG_DIR/claude-debug.log"
META_LOG="$LOG_DIR/meta.txt"
RESULT_FILE="$LOG_DIR/result.txt"
PROMPT_BYTES="$(wc -c < "$PROMPT_FILE" | tr -d ' ')"
CLAUDE_MODE="${HARNESS_REVIEW_PEER_CLAUDE_MODE:-bare}"

case "$PEER" in
  codex|gemini|claude) ;;
  *) die "unsupported peer: $PEER (expected codex, gemini, or claude)" ;;
esac

case "$CLAUDE_MODE" in
  bare|safe-mode) ;;
  *) die "unsupported HARNESS_REVIEW_PEER_CLAUDE_MODE: $CLAUDE_MODE (expected bare or safe-mode)" ;;
esac

select_peer() {
  local requested="$1"
  if command -v "$requested" >/dev/null 2>&1; then
    printf '%s' "$requested"
    return
  fi

  local candidate
  for candidate in codex gemini claude; do
    if command -v "$candidate" >/dev/null 2>&1; then
      echo "warning: $requested CLI not found, falling back to $candidate" >&2
      printf '%s' "$candidate"
      return
    fi
  done
  die "no peer CLI found; install codex, gemini, or claude"
}

if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout "$TIMEOUT")
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout "$TIMEOUT")
else
  run_with_timeout() {
    local secs="$1"
    shift
    "$@" &
    local pid=$!
    ( sleep "$secs" && kill "$pid" 2>/dev/null ) &
    local watcher=$!
    wait "$pid" 2>/dev/null
    local result=$?
    kill "$watcher" 2>/dev/null || true
    wait "$watcher" 2>/dev/null || true
    if [[ $result -eq 137 || $result -eq 143 ]]; then
      return 124
    fi
    return "$result"
  }
  TIMEOUT_CMD=(run_with_timeout "$TIMEOUT")
fi

write_meta() {
  {
    echo "peer=$PEER"
    echo "selected_peer=$SELECTED_PEER"
    echo "prompt_file=$PROMPT_FILE"
    echo "prompt_bytes=$PROMPT_BYTES"
    echo "timeout=$TIMEOUT"
    echo "log_dir=$LOG_DIR"
    echo "started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    if [[ "$SELECTED_PEER" == "claude" ]]; then
      echo "claude_mode=$CLAUDE_MODE stream-json"
      echo "claude_include_partials=${HARNESS_REVIEW_PEER_INCLUDE_PARTIALS:-0}"
      claude --version 2>/dev/null || true
    elif command -v "$SELECTED_PEER" >/dev/null 2>&1; then
      "$SELECTED_PEER" --version 2>/dev/null || true
    fi
  } > "$META_LOG"
}

print_diagnostics() {
  echo "Diagnostics: $LOG_DIR" >&2
  echo "  meta: $META_LOG" >&2
  echo "  raw: $RAW_LOG" >&2
  echo "  stderr: $STDERR_LOG" >&2
  if [[ -f "$DEBUG_LOG" ]]; then
    echo "  claude debug: $DEBUG_LOG" >&2
  fi
}

parse_claude_stream_json() {
  python3 - "$RAW_LOG" "$RESULT_FILE" <<'PY'
import json
import pathlib
import sys

raw_path = pathlib.Path(sys.argv[1])
result_path = pathlib.Path(sys.argv[2])
result = None
is_error = False

for line in raw_path.read_text(errors="replace").splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        continue
    if not isinstance(event, dict):
        continue
    if event.get("type") == "result":
        result = event.get("result")
        is_error = bool(event.get("is_error"))

if result is None:
    raise SystemExit("Claude stream-json did not include a result event")

result_path.write_text(str(result))
if is_error:
    raise SystemExit("Claude returned an error result")
PY
}

SELECTED_PEER="$(select_peer "$PEER")"
write_meta
echo "harness-review-peer: invoking $SELECTED_PEER (timeout=${TIMEOUT}s, logs=$LOG_DIR)" >&2

exit_code=0
case "$SELECTED_PEER" in
  claude)
    CLAUDE_ARGS=(
      "--$CLAUDE_MODE"
      -p
      --output-format stream-json
      --verbose
      --debug-file "$DEBUG_LOG"
      --dangerously-skip-permissions
    )
    if [[ "${HARNESS_REVIEW_PEER_INCLUDE_PARTIALS:-0}" == "1" ]]; then
      CLAUDE_ARGS+=(--include-partial-messages)
    fi
    "${TIMEOUT_CMD[@]}" claude \
      "${CLAUDE_ARGS[@]}" \
      < "$PROMPT_FILE" > "$RAW_LOG" 2> "$STDERR_LOG" || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
      if [[ $exit_code -eq 124 ]]; then
        echo "Error: claude peer timed out after ${TIMEOUT}s" >&2
      else
        echo "Error: claude peer exited with status $exit_code" >&2
      fi
      print_diagnostics
      exit "$exit_code"
    fi
    if ! parse_claude_stream_json; then
      echo "Error: claude peer produced no parseable final result" >&2
      print_diagnostics
      exit 1
    fi
    cat "$RESULT_FILE"
    printf '\n'
    ;;
  gemini)
    prompt="$(cat "$PROMPT_FILE")"
    "${TIMEOUT_CMD[@]}" gemini -p "$prompt" > "$RESULT_FILE" 2> "$STDERR_LOG" || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
      if [[ $exit_code -eq 124 ]]; then
        echo "Error: gemini peer timed out after ${TIMEOUT}s" >&2
      else
        echo "Error: gemini peer exited with status $exit_code" >&2
      fi
      print_diagnostics
      exit "$exit_code"
    fi
    cat "$RESULT_FILE"
    ;;
  codex)
    "${TIMEOUT_CMD[@]}" codex exec \
      --sandbox read-only \
      --output-last-message "$RESULT_FILE" \
      - < "$PROMPT_FILE" > "$RAW_LOG" 2> "$STDERR_LOG" || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
      if [[ $exit_code -eq 124 ]]; then
        echo "Error: codex peer timed out after ${TIMEOUT}s" >&2
      else
        echo "Error: codex peer exited with status $exit_code" >&2
      fi
      print_diagnostics
      exit "$exit_code"
    fi
    cat "$RESULT_FILE"
    ;;
esac
