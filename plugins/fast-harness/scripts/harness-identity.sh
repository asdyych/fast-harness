#!/usr/bin/env bash
# harness-identity.sh — the name the harness should address you by.
# Stored globally (your name is the same across projects): ~/.harness/identity
# Runtime override: the HARNESS_USER_NAME env var takes precedence.
set -uo pipefail

STORE="${HARNESS_IDENTITY_FILE:-$HOME/.harness/identity}"
CMD="${1:-get}"; [[ $# -gt 0 ]] && shift || true

case "$CMD" in
  set)
    name="${*:-}"
    [[ -n "$name" ]] || { echo "usage: harness-identity.sh set <name>" >&2; exit 2; }
    mkdir -p "$(dirname "$STORE")"
    printf '%s\n' "$name" > "$STORE"
    echo "saved — the harness will address you as: $name"
    ;;
  get)
    if [[ -n "${HARNESS_USER_NAME:-}" ]]; then printf '%s\n' "$HARNESS_USER_NAME"
    elif [[ -f "$STORE" ]]; then head -n1 "$STORE"
    fi
    ;;
  path) echo "$STORE";;
  *) echo "usage: harness-identity.sh <get|set <name>|path>" >&2; exit 2;;
esac
