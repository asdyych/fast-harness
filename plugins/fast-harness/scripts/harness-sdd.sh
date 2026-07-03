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
  if grep -qE '^/?\.harness(/|\*|\*\*)?$' "$ignore"; then
    python3 - "$ignore" <<'PY'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.read().splitlines()
out = []
replaced = False
for line in lines:
    if line in {".harness", ".harness/", ".harness/*", ".harness/**", "/.harness", "/.harness/", "/.harness/*", "/.harness/**"}:
        if not replaced:
            out.extend([".harness/*", "!.harness/config.json"])
            replaced = True
        continue
    out.append(line)
with open(path, "w") as f:
    f.write("\n".join(out) + ("\n" if out else ""))
PY
  elif ! grep -qxF '.harness/*' "$ignore"; then
    {
      [[ -s "$ignore" ]] && echo
      echo ".harness/*"
      echo "!.harness/config.json"
    } >> "$ignore"
  fi
  grep -qxF '!.harness/config.json' "$ignore" || echo "!.harness/config.json" >> "$ignore"
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

config_json() {
  local field="$1"
  local default="$2"
  local config="$ROOT/.harness/config.json"
  python3 - "$config" "$field" "$default" <<'PY'
import json, sys
path, field, default = sys.argv[1:4]
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    print(default)
    sys.exit(0)
except Exception as exc:
    print(f"invalid harness config JSON: {path}: {exc}", file=sys.stderr)
    sys.exit(1)

value = data
for part in field.split("."):
    if not isinstance(value, dict) or part not in value:
        print(default)
        sys.exit(0)
    value = value[part]
print(value)
PY
}

sdd_language() {
  local lang
  lang="$(config_json "sdd_language" "en")"
  case "$lang" in
    en|zh-CN) echo "$lang";;
    *) die "unsupported sdd_language: $lang (supported: en, zh-CN)";;
  esac
}

loop_config_int() {
  local field="$1"
  local default="$2"
  local value
  value="$(config_json "loop.$field" "$default")"
  [[ "$value" =~ ^[0-9]+$ ]] || die "invalid loop.$field in .harness/config.json: $value"
  echo "$value"
}

write_manifest() {
  local id="$1"
  local status="$2"
  local manifest="$ROOT/.harness/$id/manifest.json"
  local created_at updated_at current_checkpoint loop_phase loop_round loop_no_progress loop_max_rounds loop_max_no_progress loop_status loop_stop_reason last_progress_at last_tick_at
  updated_at="$(now_utc)"
  if [[ -f "$manifest" ]]; then
    created_at="$(manifest_field "$manifest" "created_at" "$updated_at")"
    current_checkpoint="$(manifest_field "$manifest" "current_checkpoint" "checkpoint-1")"
    loop_phase="$(python3 - "$manifest" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("loop", {}).get("phase", "planning"))
PY
)"
    loop_round="$(python3 - "$manifest" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("loop", {}).get("round", 0))
PY
)"
    loop_no_progress="$(python3 - "$manifest" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("loop", {}).get("no_progress_rounds", 0))
PY
)"
    loop_max_rounds="$(python3 - "$manifest" "$(loop_config_int "max_rounds" "10")" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("loop", {}).get("max_rounds", int(sys.argv[2])))
PY
)"
    loop_max_no_progress="$(python3 - "$manifest" "$(loop_config_int "max_no_progress_rounds" "2")" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("loop", {}).get("max_no_progress_rounds", int(sys.argv[2])))
PY
)"
    loop_status="$(python3 - "$manifest" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("loop", {}).get("status", "active"))
PY
)"
    loop_stop_reason="$(python3 - "$manifest" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("loop", {}).get("stop_reason", ""))
PY
)"
    last_progress_at="$(python3 - "$manifest" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("loop", {}).get("last_progress_at", ""))
PY
)"
    last_tick_at="$(python3 - "$manifest" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("loop", {}).get("last_tick_at", ""))
PY
)"
  else
    created_at="$updated_at"
    current_checkpoint="checkpoint-1"
    loop_phase="planning"
    loop_round="0"
    loop_no_progress="0"
    loop_max_rounds="$(loop_config_int "max_rounds" "10")"
    loop_max_no_progress="$(loop_config_int "max_no_progress_rounds" "2")"
    loop_status="active"
    loop_stop_reason=""
    last_progress_at=""
    last_tick_at=""
  fi

  cat > "$manifest" <<EOF
{
  "change_id": $(json_escape "$id"),
  "status": $(json_escape "$status"),
  "created_at": $(json_escape "$created_at"),
  "updated_at": $(json_escape "$updated_at"),
  "docs_dir": $(json_escape "docs/specs/$id"),
  "harness_dir": $(json_escape ".harness/$id"),
  "current_checkpoint": $(json_escape "$current_checkpoint"),
  "loop": {
    "phase": $(json_escape "$loop_phase"),
    "round": $loop_round,
    "max_rounds": $loop_max_rounds,
    "no_progress_rounds": $loop_no_progress,
    "max_no_progress_rounds": $loop_max_no_progress,
    "status": $(json_escape "$loop_status"),
    "stop_reason": $(json_escape "$loop_stop_reason"),
    "last_progress_at": $(json_escape "$last_progress_at"),
    "last_tick_at": $(json_escape "$last_tick_at")
  }
}
EOF
}

start_session() {
  local id="$1"
  validate_change_id "$id"
  ensure_gitignore

  local docs="$ROOT/docs/specs/$id"
  local state="$ROOT/.harness/$id"
  local lang
  lang="$(sdd_language)"
  mkdir -p "$docs" "$state/evidence"

  if [[ "$lang" == "zh-CN" ]]; then
    write_if_missing "$docs/spec.md" \
      "# 规格说明：$id" \
      "" \
      "状态：草案" \
      "" \
      "## 目标" \
      "" \
      "描述这个变更需要交付的用户或系统结果。" \
      "" \
      "## 范围" \
      "" \
      "- 范围内：" \
      "- 范围外：" \
      "" \
      "## 验收标准" \
      "" \
      "- [ ] 至少添加一个可通过命令或文件检查的标准。"

    write_if_missing "$docs/design.md" \
      "# 设计说明：$id" \
      "" \
      "状态：草案" \
      "" \
      "## 方案" \
      "" \
      "描述技术方案、影响文件和边界。" \
      "" \
      "## 验证" \
      "" \
      "- Targeted checks:" \
      "- /verify:" \
      "- /e2e:" \
      "- /review-loop:"

    write_if_missing "$docs/tasks.md" \
      "# 任务清单：$id" \
      "" \
      "- [ ] 确认 spec 和 design 足够可执行。" \
      "- [ ] 实现第一个 checkpoint。" \
      "- [ ] 记录验证证据。" \
      "- [ ] finish 前同步最终任务状态。"

    write_if_missing "$docs/learnings.md" \
      "# 经验沉淀：$id" \
      "" \
      "## 约束" \
      "" \
      "## 已验证模式" \
      "" \
      "## 避免重复的错误" \
      "" \
      "## 后续 Harness 改进"

    write_if_missing "$state/checkpoints.md" \
      "# Checkpoints: $id" \
      "" \
      "## Checkpoint 1: 可执行规格切片" \
      "" \
      "Status: active" \
      "" \
      "Acceptance:" \
      "- docs/specs/$id/spec.md 有具体验收标准。" \
      "- docs/specs/$id/design.md 说明受影响实现面。" \
      "- docs/specs/$id/tasks.md 反映第一个可执行任务切片。" \
      "" \
      "Evidence:" \
      "- 在 .harness/$id/task-log.md 记录动作和验证。"

    write_if_missing "$state/task-log.md" \
      "# 任务日志：$id" \
      "" \
      "Started: $(now_utc)" \
      "" \
      "## Entries" \
      "" \
      "- 创建轻量 SDD 会话 scaffold。"

    write_if_missing "$state/state.md" \
      "# Loop 状态：$id" \
      "" \
      "目标：" \
      "当前阶段：planning" \
      "当前 checkpoint：checkpoint-1" \
      "最近有效进展：" \
      "下一步：" \
      "阻塞项：" \
      "升级条件：" \
      "证据："
  else
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

    write_if_missing "$docs/learnings.md" \
      "# Learnings: $id" \
      "" \
      "## Constraints" \
      "" \
      "## Validated Patterns" \
      "" \
      "## Mistakes To Avoid" \
      "" \
      "## Follow-up Harness Improvements"

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

    write_if_missing "$state/state.md" \
      "# Loop State: $id" \
      "" \
      "Goal:" \
      "Current phase: planning" \
      "Current checkpoint: checkpoint-1" \
      "Last meaningful progress:" \
      "Next action:" \
      "Blockers:" \
      "Escalation:" \
      "Evidence:"
  fi

  write_if_missing "$state/loop.log.md" \
    "# Loop Log: $id" \
    "" \
    "## Events" \
    "" \
    "- Round: 0" \
    "  Action: create SDD session scaffold" \
    "  Decision: initialized" \
    "  Evidence: .harness/$id/manifest.json" \
    "  Result: continue" \
    "  Stop reason: none"

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
