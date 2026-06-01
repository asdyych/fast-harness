#!/usr/bin/env bash
# harness-verify.sh — code-level green gate: frontend typecheck + tests (with
# coverage), and an optional backend test command. Project-agnostic: reads
# commands from the repo's .harness-dev.conf, with sensible defaults.
#
# Usage: harness-verify.sh [all|frontend|backend|types]   (default all)
#
# Config keys (all optional; in .harness-dev.conf):
#   FRONTEND_DIR=frontend
#   TYPECHECK_CMD="npx tsc --noEmit"
#   TEST_CMD="npx vitest run"
#   COVERAGE_CMD="npx vitest run --coverage"   # preferred over TEST_CMD when set
#   BACKEND_DIR=backend
#   BACKEND_TEST_CMD="uv run pytest --cov"
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONF="${HARNESS_CONF:-$ROOT/.harness-dev.conf}"

FRONTEND_DIR="frontend"
TYPECHECK_CMD="npx tsc --noEmit"
TEST_CMD="npx vitest run"
COVERAGE_CMD=""
BACKEND_DIR=""
BACKEND_TEST_CMD=""
# shellcheck disable=SC1090
if [[ -f "$CONF" ]]; then source "$CONF" || { echo "failed to source $CONF (syntax error?)" >&2; exit 1; }; fi

WHICH="${1:-all}"
case "$WHICH" in all|frontend|backend|types) ;; *) echo "unknown target: $WHICH (use: all|frontend|backend|types)" >&2; exit 2;; esac
fail=0
run(){ # label  workdir  command
  echo "▶ $1"
  if [[ ! -d "$2" ]]; then echo "  – skip ($2 not present)"; return 0; fi
  ( cd "$2" && eval "$3" )
  local rc=$?
  if [[ $rc -eq 0 ]]; then echo "  ✓ ok"; else echo "  ✗ FAILED (rc=$rc)"; fail=1; fi
}

if [[ "$WHICH" == all || "$WHICH" == frontend || "$WHICH" == types ]]; then
  [[ -n "$TYPECHECK_CMD" ]] && run "typecheck ($FRONTEND_DIR): $TYPECHECK_CMD" "$ROOT/$FRONTEND_DIR" "$TYPECHECK_CMD"
fi
if [[ "$WHICH" == all || "$WHICH" == frontend ]]; then
  cmd="${COVERAGE_CMD:-$TEST_CMD}"
  [[ -n "$cmd" ]] && run "frontend tests ($FRONTEND_DIR): $cmd" "$ROOT/$FRONTEND_DIR" "$cmd"
fi
if [[ "$WHICH" == all || "$WHICH" == backend ]]; then
  if [[ -n "$BACKEND_TEST_CMD" && -n "$BACKEND_DIR" ]]; then
    run "backend tests ($BACKEND_DIR): $BACKEND_TEST_CMD" "$ROOT/$BACKEND_DIR" "$BACKEND_TEST_CMD"
  fi
fi

if [[ $fail -eq 0 ]]; then echo "VERIFY: PASS"; else echo "VERIFY: FAIL"; exit 1; fi
