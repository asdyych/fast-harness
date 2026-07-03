#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${1:?usage: harness-review-peer-smoke.sh <harness-review-peer.sh>}"
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"

cat > "$tmp/bin/claude" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" > "$FAKE_CLAUDE_ARGS"

has_arg() {
  local want="$1"
  shift
  for arg in "$@"; do
    [[ "$arg" == "$want" ]] && return 0
  done
  return 1
}

if [[ "${EXPECT_CLAUDE_MODE:-bare}" == "bare" ]]; then
  has_arg "--bare" "$@" || { echo "missing --bare" >&2; exit 91; }
  ! has_arg "--safe-mode" "$@" || { echo "unexpected --safe-mode" >&2; exit 99; }
else
  has_arg "--safe-mode" "$@" || { echo "missing --safe-mode" >&2; exit 91; }
  ! has_arg "--bare" "$@" || { echo "unexpected --bare" >&2; exit 99; }
fi
has_arg "-p" "$@" || { echo "missing -p" >&2; exit 92; }
has_arg "--dangerously-skip-permissions" "$@" || { echo "missing --dangerously-skip-permissions" >&2; exit 94; }
has_arg "--verbose" "$@" || { echo "missing --verbose" >&2; exit 97; }
if [[ "${EXPECT_PARTIALS:-0}" == "1" ]]; then
  has_arg "--include-partial-messages" "$@" || { echo "missing --include-partial-messages" >&2; exit 93; }
else
  ! has_arg "--include-partial-messages" "$@" || { echo "unexpected --include-partial-messages" >&2; exit 98; }
fi

debug_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-format)
      [[ "${2:-}" == "stream-json" ]] || { echo "expected stream-json output" >&2; exit 95; }
      shift 2
      ;;
    --debug-file)
      debug_file="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

[[ -n "$debug_file" ]] || { echo "missing --debug-file" >&2; exit 96; }
printf 'debug log\n' > "$debug_file"

prompt="$(cat)"
printf '%s' "$prompt" > "$FAKE_CLAUDE_STDIN"
if [[ "$prompt" == *"SLEEP"* ]]; then
  sleep 5
fi

printf '%s\n' '{"type":"system","subtype":"init","session_id":"stub-session"}'
printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"result":"NO_FINDINGS: stubbed claude peer","session_id":"stub-session"}'
SH
chmod +x "$tmp/bin/claude"

export PATH="$tmp/bin:$PATH"
export FAKE_CLAUDE_ARGS="$tmp/claude-args.txt"
export FAKE_CLAUDE_STDIN="$tmp/claude-stdin.txt"

printf 'review prompt\n' > "$tmp/prompt.md"
"$SCRIPT" --peer claude --prompt-file "$tmp/prompt.md" --timeout 10 --log-dir "$tmp/logs-ok" > "$tmp/out.txt" 2> "$tmp/err.txt"

grep -qxF 'NO_FINDINGS: stubbed claude peer' "$tmp/out.txt"
grep -q -- '--bare' "$FAKE_CLAUDE_ARGS"
grep -q 'review prompt' "$FAKE_CLAUDE_STDIN"
test -f "$tmp/logs-ok/claude-debug.log"

EXPECT_CLAUDE_MODE=safe-mode HARNESS_REVIEW_PEER_CLAUDE_MODE=safe-mode \
  "$SCRIPT" --peer claude --prompt-file "$tmp/prompt.md" --timeout 10 --log-dir "$tmp/logs-safe" > "$tmp/safe-out.txt" 2> "$tmp/safe-err.txt"
grep -qxF 'NO_FINDINGS: stubbed claude peer' "$tmp/safe-out.txt"

EXPECT_PARTIALS=1 HARNESS_REVIEW_PEER_INCLUDE_PARTIALS=1 \
  "$SCRIPT" --peer claude --prompt-file "$tmp/prompt.md" --timeout 10 --log-dir "$tmp/logs-partials" > "$tmp/partials-out.txt" 2> "$tmp/partials-err.txt"
grep -qxF 'NO_FINDINGS: stubbed claude peer' "$tmp/partials-out.txt"

printf 'SLEEP\n' > "$tmp/slow.md"
if "$SCRIPT" --peer claude --prompt-file "$tmp/slow.md" --timeout 1 --log-dir "$tmp/logs-timeout" > "$tmp/slow-out.txt" 2> "$tmp/slow-err.txt"; then
  echo "expected timeout to fail" >&2
  exit 1
fi
grep -q 'timed out after 1s' "$tmp/slow-err.txt"
grep -q 'Diagnostics:' "$tmp/slow-err.txt"
test -f "$tmp/logs-timeout/meta.txt"
