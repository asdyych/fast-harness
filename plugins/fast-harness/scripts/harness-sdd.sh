#!/usr/bin/env bash
# harness-sdd.sh — lightweight SDD session scaffolding for fast-harness.
#
# The script owns deterministic file mechanics only. Agents own the judgment:
# filling specs, deriving checkpoints, and deciding verification scope.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "harness-sdd.sh must be run inside a git repository" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
usage:
  harness-sdd.sh start <change-id>
  harness-sdd.sh status [change-id]
  harness-sdd.sh finish <change-id>

change-id must use lowercase letters, digits, dots, underscores, or hyphens.
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

require_python3() {
  command -v python3 >/dev/null 2>&1 || die "python3 is required for harness-sdd.sh"
}

now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

validate_change_id() {
  local id="${1:-}"
  [[ -n "$id" ]] || die "missing change-id"
  [[ "$id" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "invalid change-id: $id"
}

ensure_gitignore() {
  local ignore="$ROOT/.gitignore"
  [[ -f "$ignore" ]] || : > "$ignore"
  if ! grep -qE '^/?\.harness(/|\*|\*\*)?$' "$ignore"; then
    {
      [[ -s "$ignore" ]] && echo
      echo ".harness/"
    } >> "$ignore"
  fi
}

write_if_missing() {
  local path="$1"
  shift
  if [[ ! -f "$path" ]]; then
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$@" > "$path"
  fi
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

status_from_manifest() {
  local manifest="$1"
  python3 - "$manifest" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    print(json.load(f).get("status", "unknown"))
PY
}

manifest_field() {
  local manifest="$1"
  local field="$2"
  local default="$3"
  python3 - "$manifest" "$field" "$default" <<'PY'
import json, sys
manifest, field, default = sys.argv[1:4]
try:
    with open(manifest) as f:
        data = json.load(f)
except Exception as exc:
    print(f"invalid manifest JSON: {manifest}: {exc}", file=sys.stderr)
    sys.exit(1)
print(data.get(field) or default)
PY
}

write_manifest() {
  local id="$1"
  local status="$2"
  local manifest="$ROOT/.harness/$id/manifest.json"
  local created_at updated_at current_checkpoint
  updated_at="$(now_utc)"
  if [[ -f "$manifest" ]]; then
    created_at="$(manifest_field "$manifest" "created_at" "$updated_at")"
    current_checkpoint="$(manifest_field "$manifest" "current_checkpoint" "checkpoint-1")"
  else
    created_at="$updated_at"
    current_checkpoint="checkpoint-1"
  fi

  cat > "$manifest" <<EOF
{
  "change_id": $(json_escape "$id"),
  "status": $(json_escape "$status"),
  "created_at": $(json_escape "$created_at"),
  "updated_at": $(json_escape "$updated_at"),
  "docs_dir": $(json_escape "docs/specs/$id"),
  "harness_dir": $(json_escape ".harness/$id"),
  "current_checkpoint": $(json_escape "$current_checkpoint")
}
EOF
}

start_session() {
  local id="$1"
  validate_change_id "$id"
  ensure_gitignore

  local docs="$ROOT/docs/specs/$id"
  local state="$ROOT/.harness/$id"
  mkdir -p "$docs" "$state/evidence"

  write_if_missing "$docs/spec.md" \
    "# Spec: $id" \
    "" \
    "Status: draft" \
    "" \
    "## Goal" \
    "" \
    "Describe the user or system outcome this change must deliver." \
    "" \
    "## Scope" \
    "" \
    "- In scope:" \
    "- Out of scope:" \
    "" \
    "## Acceptance Criteria" \
    "" \
    "- [ ] Add at least one command-checkable or file-checkable criterion."

  write_if_missing "$docs/design.md" \
    "# Design: $id" \
    "" \
    "Status: draft" \
    "" \
    "## Approach" \
    "" \
    "Describe the technical approach, affected files, and boundaries." \
    "" \
    "## Verification" \
    "" \
    "- Targeted checks:" \
    "- /verify:" \
    "- /e2e:" \
    "- /review-loop:"

  write_if_missing "$docs/tasks.md" \
    "# Tasks: $id" \
    "" \
    "- [ ] Confirm spec and design are complete enough to execute." \
    "- [ ] Implement the first checkpoint." \
    "- [ ] Record verification evidence." \
    "- [ ] Sync final task status before finishing."

  write_if_missing "$state/checkpoints.md" \
    "# Checkpoints: $id" \
    "" \
    "## Checkpoint 1: Spec-ready execution slice" \
    "" \
    "Status: active" \
    "" \
    "Acceptance:" \
    "- docs/specs/$id/spec.md has concrete acceptance criteria." \
    "- docs/specs/$id/design.md names the affected implementation surface." \
    "- docs/specs/$id/tasks.md reflects the first executable task slice." \
    "" \
    "Evidence:" \
    "- Record actions and verification in .harness/$id/task-log.md."

  write_if_missing "$state/task-log.md" \
    "# Task Log: $id" \
    "" \
    "Started: $(now_utc)" \
    "" \
    "## Entries" \
    "" \
    "- Created lightweight SDD session scaffold."

  write_manifest "$id" "active"

  echo "SDD session started"
  echo "change-id: $id"
  echo "docs: docs/specs/$id"
  echo "state: .harness/$id"
}

latest_change_id() {
  local latest_manifest
  latest_manifest="$(ls -t "$ROOT"/.harness/*/manifest.json 2>/dev/null | head -1 || true)"
  [[ -n "$latest_manifest" ]] || die "no SDD sessions found (create one with /sdd-start <change-id>)"
  basename "$(dirname "$latest_manifest")"
}

status_session() {
  local id="${1:-}"
  [[ -n "$id" ]] || id="$(latest_change_id)"
  validate_change_id "$id"
  local manifest="$ROOT/.harness/$id/manifest.json"
  [[ -f "$manifest" ]] || die "no SDD session for change-id: $id"

  local status
  status="$(status_from_manifest "$manifest")"
  echo "change-id: $id"
  echo "status: $status"
  echo "docs: docs/specs/$id"
  echo "state: .harness/$id"
  echo "manifest: .harness/$id/manifest.json"
}

finish_session() {
  local id="$1"
  validate_change_id "$id"
  local manifest="$ROOT/.harness/$id/manifest.json"
  local log="$ROOT/.harness/$id/task-log.md"
  [[ -f "$manifest" ]] || die "no SDD session for change-id: $id"
  [[ -f "$log" ]] || die "missing task log for change-id: $id"
  [[ "$(status_from_manifest "$manifest")" != "finished" ]] || die "SDD session already finished: $id"

  write_manifest "$id" "finished"
  {
    echo
    echo "Finished: $(now_utc)"
  } >> "$log"

  echo "SDD session finished"
  echo "change-id: $id"
}

cmd="${1:-}"
[[ -n "$cmd" ]] || { usage; exit 2; }
shift || true
require_python3

case "$cmd" in
  start)
    [[ $# -eq 1 ]] || { usage; exit 2; }
    start_session "$1"
    ;;
  status)
    [[ $# -le 1 ]] || { usage; exit 2; }
    status_session "${1:-}"
    ;;
  finish)
    [[ $# -eq 1 ]] || { usage; exit 2; }
    finish_session "$1"
    ;;
  *)
    usage
    exit 2
    ;;
esac
