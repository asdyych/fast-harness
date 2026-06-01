#!/usr/bin/env bash
# harness-worktree-dev.sh — profile-driven dev environment for a git worktree.
#
# A worktree-per-task workflow needs the same ritual every time: copy the
# main checkout's env files into the worktree, symlink the heavy dependency
# dirs (.venv / node_modules) instead of reinstalling, free the ports, start
# the service trio in the background, health-check, and tear down on demand.
# This script encodes that ritual once and drives it from a per-repo profile.
#
# Subcommands:
#   start   copy env + symlink deps + start services + health-check
#   stop    kill recorded service PIDs + free ports  (worktree left intact)
#   status  show which services are running / ports up
#
# Profile: a sourced bash file (default: <worktree>/.harness-dev.conf) that sets
#   MAIN_CHECKOUT="/abs/path/to/main/checkout"
#   ENV_FILES=( "backend/.env" "frontend/.env" "frontend/.env.staging" )   # relpaths copied main -> worktree
#   SYMLINKS=( "backend/.venv" "frontend/node_modules" )                   # relpaths symlinked main -> worktree
#   SERVICES=( "backend|8105|backend|uv run uvicorn api.main:app --reload --host 0.0.0.0 --port 8105"
#              "frontend|3105|frontend|npm run dev"
#              "stripe|0|.|./dev-stripe.sh" )                              # name|port|subdir|command  (port 0 = no port)
#   HEALTH=( "backend|http://localhost:8105/healthz" "frontend|http://localhost:3105" )
#
# Design rule (matches the author's standing worktree habits):
#   - Backend /healthz green does NOT prove the frontend can log in — copy ALL
#     env files for BOTH ends; a missing frontend VITE_* is silently undefined.
#   - Vite snapshots VITE_* at startup, so a restart is required after env edits.
#   - NEVER remove a worktree implicitly. `stop` leaves it intact unless the
#     explicit --remove-worktree flag is passed.

set -euo pipefail

usage() {
  cat <<'EOF'
harness-worktree-dev <start|stop|status> [options]
  --profile <file>      profile to source (default: <worktree>/.harness-dev.conf)
  --worktree <path>     worktree path (default: current directory)
  --services a,b,c      only act on these services (default: all in profile)
  --remove-worktree     (stop only) also `git worktree remove --force` afterwards
EOF
}

CMD="${1:-}"; [[ -n "$CMD" ]] && shift || true
PROFILE=""; WT=""; SERVICES_FILTER=""; REMOVE_WT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:?}"; shift 2;;
    --worktree) WT="${2:?}"; shift 2;;
    --services) SERVICES_FILTER="${2:?}"; shift 2;;
    --remove-worktree) REMOVE_WT=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "unknown arg: $1" >&2; usage; exit 2;;
  esac
done

WT="$(cd "${WT:-$PWD}" && pwd)"
PROFILE="${PROFILE:-$WT/.harness-dev.conf}"
[[ -f "$PROFILE" ]] || { echo "profile not found: $PROFILE" >&2; echo "(create one — see the worktree-dev skill for the format)" >&2; exit 1; }
# shellcheck disable=SC1090
source "$PROFILE"
: "${MAIN_CHECKOUT:?profile must set MAIN_CHECKOUT}"
[[ -d "$MAIN_CHECKOUT" ]] || { echo "MAIN_CHECKOUT does not exist: $MAIN_CHECKOUT" >&2; exit 1; }

KEY="$(printf '%s' "$WT" | shasum | cut -c1-8)"
RUN="/tmp/harness-wt-$KEY"
mkdir -p "$RUN"

want() { [[ -z "$SERVICES_FILTER" ]] && return 0; [[ ",$SERVICES_FILTER," == *",$1,"* ]]; }
free_port() {
  local p="$1"; [[ "$p" == "0" || -z "$p" ]] && return 0
  local pid; pid="$(lsof -ti tcp:"$p" 2>/dev/null || true)"
  [[ -n "$pid" ]] && { echo "  free port $p (pid $pid)"; kill -9 $pid 2>/dev/null || true; }
  return 0
}

cmd_start() {
  echo "▶ worktree: $WT"
  echo "▶ main:     $MAIN_CHECKOUT   (run-dir $RUN)"
  for rel in "${ENV_FILES[@]:-}"; do
    [[ -z "$rel" ]] && continue
    if [[ -f "$MAIN_CHECKOUT/$rel" ]]; then
      mkdir -p "$WT/$(dirname "$rel")"; cp "$MAIN_CHECKOUT/$rel" "$WT/$rel"; echo "  env  ✓ $rel"
    else echo "  env  – $rel (absent in main, skipped)"; fi
  done
  for rel in "${SYMLINKS[@]:-}"; do
    [[ -z "$rel" ]] && continue
    if [[ -e "$MAIN_CHECKOUT/$rel" ]]; then
      mkdir -p "$WT/$(dirname "$rel")"; ln -sfn "$MAIN_CHECKOUT/$rel" "$WT/$rel"; echo "  link ✓ $rel"
    else echo "  link – $rel (absent in main)"; fi
  done
  for svc in "${SERVICES[@]:-}"; do
    [[ -z "$svc" ]] && continue
    IFS='|' read -r name port subdir command <<< "$svc"
    want "$name" || continue
    free_port "$port"
    local wd="$WT/$subdir" log="$RUN/$name.log" pf="$RUN/$name.pid"
    echo "  start $name → $log"
    ( cd "$wd" && nohup bash -c "$command" >"$log" 2>&1 & echo $! >"$pf" )
  done
  sleep 3
  echo "— health —"
  for h in "${HEALTH[@]:-}"; do
    [[ -z "$h" ]] && continue
    IFS='|' read -r name url <<< "$h"
    want "$name" || continue
    if curl -sf -m 4 "$url" >/dev/null 2>&1; then echo "  ✓ $name  $url"
    else echo "  … $name  $url  (not ready — tail $RUN/$name.log)"; fi
  done
}

cmd_stop() {
  shopt -s nullglob
  for pf in "$RUN"/*.pid; do
    name="$(basename "$pf" .pid)"; want "$name" || continue
    pid="$(cat "$pf" 2>/dev/null || true)"
    if [[ -n "$pid" ]]; then pkill -P "$pid" 2>/dev/null || true; kill "$pid" 2>/dev/null || true; echo "  stopped $name (pid $pid)"; fi
    rm -f "$pf"
  done
  for svc in "${SERVICES[@]:-}"; do
    [[ -z "$svc" ]] && continue
    IFS='|' read -r name port subdir command <<< "$svc"; want "$name" || continue; free_port "$port"
  done
  rm -f "$RUN"/*.log 2>/dev/null || true
  echo "stopped. worktree left intact: $WT"
  if [[ "$REMOVE_WT" == "1" ]]; then
    echo "removing worktree (explicit --remove-worktree)…"
    ( cd "$MAIN_CHECKOUT" && git worktree remove --force "$WT" ) && echo "  removed $WT"
  fi
}

cmd_status() {
  echo "worktree: $WT   run-dir: $RUN"
  for svc in "${SERVICES[@]:-}"; do
    [[ -z "$svc" ]] && continue
    IFS='|' read -r name port subdir command <<< "$svc"; want "$name" || continue
    state="stopped"; pf="$RUN/$name.pid"
    [[ -f "$pf" ]] && { pid="$(cat "$pf")"; kill -0 "$pid" 2>/dev/null && state="running(pid $pid)"; }
    portinfo=""
    [[ "$port" != "0" ]] && { lsof -ti tcp:"$port" >/dev/null 2>&1 && portinfo="port $port up" || portinfo="port $port down"; }
    printf "  %-10s %-18s %s\n" "$name" "$state" "$portinfo"
  done
}

case "$CMD" in
  start)  cmd_start;;
  stop)   cmd_stop;;
  status) cmd_status;;
  *) usage; exit 2;;
esac
