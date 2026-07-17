#!/usr/bin/env bash
# harness-review-peer.sh - invoke one shell CLI peer for cross-review.
#
# The script is intentionally thin: the agent still owns prompt construction,
# triage, fixes, and convergence. This wrapper makes CLI invocation repeatable
# and leaves diagnostics when a peer hangs or exits without a final answer.
set -euo pipefail

# Print the stable CLI contract without performing any peer discovery.
usage() {
  cat >&2 <<'EOF'
usage:
  harness-review-peer.sh [--peer auto|codex|cc|gemini] --prompt-file <path> [--timeout <seconds>] [--log-dir <dir>]

environment:
  HARNESS_HOST=codex|cc                         optional host override for auto peer selection
  HARNESS_REVIEW_PEER_CC_MODE=bare|safe-mode       default: bare
  HARNESS_REVIEW_PEER_CC_INCLUDE_PARTIALS=1        include CC partial chunks in raw.jsonl
EOF
}

# Report a caller or environment error and stop before invoking a peer.
die() {
  echo "$*" >&2
  exit 1
}

PEER="auto"
PROMPT_FILE=""
TIMEOUT=1200
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

[[ -n "$PROMPT_FILE" ]] || die "missing --prompt-file"
[[ -f "$PROMPT_FILE" ]] || die "prompt file not found: $PROMPT_FILE"
[[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] || die "timeout must be a positive integer"

if [[ -z "$LOG_DIR" ]]; then
  LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/harness-review-peer.XXXXXX")"
fi
mkdir -p "$LOG_DIR"

RAW_LOG="$LOG_DIR/raw.jsonl"
STDERR_LOG="$LOG_DIR/stderr.txt"
DEBUG_LOG="$LOG_DIR/cc-debug.log"
META_LOG="$LOG_DIR/meta.txt"
RESULT_FILE="$LOG_DIR/result.txt"
PROMPT_BYTES="$(wc -c < "$PROMPT_FILE" | tr -d ' ')"
CC_MODE="${HARNESS_REVIEW_PEER_CC_MODE:-${HARNESS_REVIEW_PEER_CLAUDE_MODE:-bare}}"
CC_INCLUDE_PARTIALS="${HARNESS_REVIEW_PEER_CC_INCLUDE_PARTIALS:-${HARNESS_REVIEW_PEER_INCLUDE_PARTIALS:-0}}"

# Normalize supported executable aliases to one invocation protocol.
peer_kind() {
  case "$1" in
    auto) printf '%s' auto ;;
    codex) printf '%s' codex ;;
    gemini) printf '%s' gemini ;;
    cc|claude|claudecode|claude-code) printf '%s' cc ;;
    *) return 1 ;;
  esac
}

# Confirm that an executable implements the CC CLI rather than another command
# that happens to be named `cc` (commonly the system C compiler).
is_cc_cli() {
  local candidate="$1"
  local version
  command -v "$candidate" >/dev/null 2>&1 || return 1
  version="$("$candidate" --version 2>/dev/null | head -n 1 || true)"
  [[ "$version" == *"Claude Code"* ]]
}

# Return success when an executable matches the requested peer protocol.
is_peer_cli() {
  local candidate="$1"
  case "$(peer_kind "$candidate" 2>/dev/null || true)" in
    cc) is_cc_cli "$candidate" ;;
    codex|gemini) command -v "$candidate" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# Return success when auto-selection should avoid reviewing Codex with Codex.
is_codex_host() {
  case "${HARNESS_HOST:-}" in
    codex) return 0 ;;
    cc) return 1 ;;
    "") ;;
    *) die "unsupported HARNESS_HOST: $HARNESS_HOST (expected codex or cc)" ;;
  esac
  [[ "${CODEX_SHELL:-}" == "1" || -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]]
}

PEER_KIND="$(peer_kind "$PEER" || true)"
[[ -n "$PEER_KIND" ]] || die "unsupported peer: $PEER (expected auto, codex, cc, or gemini)"

case "$CC_MODE" in
  bare|safe-mode) ;;
  *) die "unsupported HARNESS_REVIEW_PEER_CC_MODE: $CC_MODE (expected bare or safe-mode)" ;;
esac

# Select the requested peer or a cross-model-aware fallback available on PATH.
select_peer() {
  local requested="$1"
  local requested_kind
  requested_kind="$(peer_kind "$requested" || true)"

  local candidates=()
  case "$requested_kind" in
    auto)
      if is_codex_host; then
        candidates=(cc claude claudecode claude-code gemini codex)
      else
        candidates=(codex gemini claude claudecode claude-code cc)
      fi
      ;;
    codex) candidates=(codex) ;;
    gemini) candidates=(gemini) ;;
    cc) candidates=(cc claude claudecode claude-code) ;;
  esac

  local candidate
  for candidate in "${candidates[@]}"; do
    if is_peer_cli "$candidate"; then
      if [[ "$candidate" != "$requested" ]]; then
        if [[ "$requested" != "auto" ]]; then
          echo "warning: $requested CLI not found, using compatible CLI $candidate" >&2
        fi
      fi
      printf '%s' "$candidate"
      return
    fi
  done

  local fallback_candidates=(codex gemini claude claudecode claude-code cc)
  if is_codex_host; then
    fallback_candidates=(claude claudecode claude-code cc gemini codex)
  fi
  for candidate in "${fallback_candidates[@]}"; do
    if is_peer_cli "$candidate"; then
      echo "warning: $requested CLI not found, falling back to $candidate" >&2
      printf '%s' "$candidate"
      return
    fi
  done
  die "no peer CLI found; install codex, cc, or gemini"
}

if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout "$TIMEOUT")
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout "$TIMEOUT")
else
  # Run a command with a portable timeout on systems without timeout/gtimeout.
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

# Persist invocation metadata needed to diagnose timeouts and empty responses.
write_meta() {
  {
    echo "peer=$PEER"
    echo "selected_peer=$SELECTED_PEER"
    echo "prompt_file=$PROMPT_FILE"
    echo "prompt_bytes=$PROMPT_BYTES"
    echo "timeout=$TIMEOUT"
    echo "log_dir=$LOG_DIR"
    echo "started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    if [[ "$SELECTED_PEER_KIND" == "cc" ]]; then
      echo "cc_mode=$CC_MODE stream-json"
      echo "cc_include_partials=$CC_INCLUDE_PARTIALS"
      "$SELECTED_PEER" --version 2>/dev/null || true
    elif command -v "$SELECTED_PEER" >/dev/null 2>&1; then
      "$SELECTED_PEER" --version 2>/dev/null || true
    fi
  } > "$META_LOG"
}

# Print diagnostic file locations without dumping potentially large logs.
print_diagnostics() {
  echo "Diagnostics: $LOG_DIR" >&2
  echo "  meta: $META_LOG" >&2
  echo "  raw: $RAW_LOG" >&2
  echo "  stderr: $STDERR_LOG" >&2
  if [[ -f "$DEBUG_LOG" ]]; then
    echo "  cc debug: $DEBUG_LOG" >&2
  fi
}

# Extract CC's final result event from its stream-json transcript.
parse_cc_stream_json() {
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
    raise SystemExit("CC stream-json did not include a result event")

result_path.write_text(str(result))
if is_error:
    raise SystemExit("CC returned an error result")
PY
}

SELECTED_PEER="$(select_peer "$PEER")"
SELECTED_PEER_KIND="$(peer_kind "$SELECTED_PEER")"
write_meta
echo "harness-review-peer: invoking $SELECTED_PEER (timeout=${TIMEOUT}s, logs=$LOG_DIR)" >&2

exit_code=0
case "$SELECTED_PEER_KIND" in
  cc)
    CC_ARGS=(
      "--$CC_MODE"
      -p
      --output-format stream-json
      --verbose
      --debug-file "$DEBUG_LOG"
      --permission-mode plan
      --tools ""
    )
    if [[ "$CC_INCLUDE_PARTIALS" == "1" ]]; then
      CC_ARGS+=(--include-partial-messages)
    fi
    "${TIMEOUT_CMD[@]}" "$SELECTED_PEER" \
      "${CC_ARGS[@]}" \
      < "$PROMPT_FILE" > "$RAW_LOG" 2> "$STDERR_LOG" || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
      if [[ $exit_code -eq 124 ]]; then
        echo "Error: cc peer timed out after ${TIMEOUT}s" >&2
      else
        echo "Error: cc peer exited with status $exit_code" >&2
      fi
      print_diagnostics
      exit "$exit_code"
    fi
    if ! parse_cc_stream_json; then
      echo "Error: cc peer produced no parseable final result" >&2
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
