#!/usr/bin/env bash
# harness-chrome-cdp.sh — open a fresh, isolated Chrome window with CDP enabled,
# for agent-driven E2E testing. NEVER touches the user's main Chrome: it launches
# a separate instance on a dedicated, persistent profile dir, and only ever
# SIGTERMs its own recorded PID (no pkill, no -9).
#
# Subcommands:
#   start [--port N] [--url URL]   open the window, wait for CDP, print the endpoint
#   status                         is the CDP endpoint up, on which PID
#   stop                           SIGTERM the recorded testing-Chrome PID only
#
# Attach a browser tool to http://localhost:<port> :
#   - Chrome MCP (mcp__Claude_in_Chrome__*), or
#   - Playwright: connectOverCDP("http://localhost:<port>")
#
# Env overrides: HARNESS_CHROME_DIR (profile dir), CHROME_BIN (Chrome binary).
set -uo pipefail

PORT=9222
URL=""
DATA_DIR="${HARNESS_CHROME_DIR:-$HOME/.harness/chrome-test}"
RUN="$HOME/.harness/chrome-cdp"

# Cross-platform Chrome/Chromium discovery (override with CHROME_BIN).
find_chrome(){
  [[ -n "${CHROME_BIN:-}" ]] && { echo "$CHROME_BIN"; return; }
  local p
  for p in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
    [[ -x "$p" ]] && { echo "$p"; return; }
  done
  for p in google-chrome google-chrome-stable chromium chromium-browser microsoft-edge chrome; do
    command -v "$p" >/dev/null 2>&1 && { echo "$p"; return; }
  done
  echo ""   # not found
}
CHROME_BIN="$(find_chrome)"
chrome_ok(){ [[ -n "$CHROME_BIN" ]] && { [[ "$CHROME_BIN" == */* ]] && [[ -x "$CHROME_BIN" ]] || command -v "$CHROME_BIN" >/dev/null 2>&1; }; }

usage(){ cat <<EOF
harness-chrome-cdp.sh <start|status|stop> [--port N] [--url URL]
  Fresh isolated Chrome window with --remote-debugging-port (default $PORT) on a
  dedicated persistent profile ($DATA_DIR). Your main Chrome is never touched.
EOF
}

CMD="${1:-}"; [[ -n "$CMD" ]] && shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="${2:?}"; shift 2;;
    --url)  URL="${2:?}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "unknown arg: $1" >&2; usage; exit 2;;
  esac
done
mkdir -p "$RUN" "$DATA_DIR"
PIDFILE="$RUN/$PORT.pid"

cdp_json(){ curl -s -m 3 "http://localhost:$PORT/json/version" 2>/dev/null; }
cdp_up(){ cdp_json | grep -q 'webSocketDebuggerUrl\|Browser'; }
print_browser(){ cdp_json | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); print("  ", d.get("Browser","?"));
    ws=d.get("webSocketDebuggerUrl","")
    if ws: print("   ws:", ws)
except Exception: pass' 2>/dev/null; }

# Is this PID our harness testing Chrome (right profile + right port)? Guards
# against attaching to / killing the user's main Chrome or a reused PID.
is_ours(){
  local c; c="$(ps -p "${1:-0}" -o command= 2>/dev/null)" || return 1
  [[ "$c" == *"--user-data-dir=$DATA_DIR"* && "$c" == *"--remote-debugging-port=$PORT"* ]]
}

cmd_start(){
  if cdp_up; then
    if [[ -f "$PIDFILE" ]] && is_ours "$(cat "$PIDFILE")"; then
      echo "CDP already up on :$PORT (harness testing window, pid $(cat "$PIDFILE"))."
      print_browser; return 0
    fi
    echo "✗ Something else already serves CDP on :$PORT — NOT the harness profile" >&2
    echo "  (likely your main Chrome or a browser-use session). Refusing to attach." >&2
    echo "  Use a different port:  harness-chrome-cdp.sh start --port 9333" >&2
    exit 1
  fi
  chrome_ok || { echo "Chrome/Chromium not found. Install it or set CHROME_BIN to the binary path." >&2; exit 1; }
  echo "opening a fresh Chrome window — profile $DATA_DIR, port $PORT …"
  "$CHROME_BIN" \
    --user-data-dir="$DATA_DIR" \
    --remote-debugging-port="$PORT" \
    --no-first-run --no-default-browser-check --new-window \
    ${URL:+"$URL"} >/dev/null 2>&1 &
  echo $! > "$PIDFILE"
  for _ in $(seq 1 25); do cdp_up && break; sleep 0.3; done
  if cdp_up; then
    echo "  ✓ CDP up on http://localhost:$PORT  (pid $(cat "$PIDFILE"))"
    print_browser
    echo "  attach: Chrome MCP, or Playwright connectOverCDP(\"http://localhost:$PORT\")"
  else
    echo "  ✗ CDP did not come up — check CHROME_BIN ($CHROME_BIN)" >&2; exit 1
  fi
}

cmd_status(){
  if cdp_up; then
    echo "CDP up on :$PORT  $([[ -f "$PIDFILE" ]] && echo "(pid $(cat "$PIDFILE"))")"
    print_browser
  else
    echo "CDP down on :$PORT"
  fi
}

cmd_stop(){
  if [[ -f "$PIDFILE" ]]; then
    pid="$(cat "$PIDFILE")"
    if is_ours "$pid"; then
      kill "$pid" 2>/dev/null && echo "stopped testing Chrome (pid $pid, SIGTERM)"
    elif kill -0 "$pid" 2>/dev/null; then
      echo "recorded pid $pid is NOT the harness Chrome (stale/reused) — leaving it alone"
    else
      echo "recorded pid $pid not running"
    fi
    rm -f "$PIDFILE"
  else
    echo "no recorded testing-Chrome PID for :$PORT — nothing to stop"
  fi
  echo "note: your main Chrome was never touched."
}

case "$CMD" in
  start)  cmd_start;;
  status) cmd_status;;
  stop)   cmd_stop;;
  *) usage; exit 2;;
esac
