#!/usr/bin/env bash
# Resolve one installed Matt Pocock skill without pinning the harness to a host's cache layout.
set -euo pipefail

skill="${1:-}"
if [[ ! "$skill" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "usage: resolve-matt-skill.sh <skill-name>" >&2
  exit 2
fi

# Print the requested skill from CC's registered Matt plugin installation.
resolve_from_cc_registry() {
  local claude_dir registry pybin matt_root candidate
  claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  registry="$claude_dir/plugins/installed_plugins.json"
  [[ -f "$registry" ]] || return 1

  pybin="$(command -v python3 || command -v python || true)"
  [[ -n "$pybin" ]] || return 1
  matt_root="$("$pybin" - "$registry" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    entries = json.load(handle).get("plugins", {}).get("mattpocock-skills@mattpocock", [])

entries = [entry for entry in entries if entry.get("installPath")]
latest = max(entries, key=lambda entry: entry.get("lastUpdated", ""), default={})
print(latest.get("installPath", ""))
PY
)"
  [[ -n "$matt_root" && -d "$matt_root/skills" ]] || return 1

  candidate="$(find "$matt_root/skills" -type f -path "*/$skill/SKILL.md" -print -quit 2>/dev/null || true)"
  [[ -n "$candidate" ]] || return 1
  printf '%s\n' "$candidate"
}

if [[ -n "${HARNESS_MATT_SKILLS_ROOT:-}" && -f "$HARNESS_MATT_SKILLS_ROOT/$skill/SKILL.md" ]]; then
  printf '%s\n' "$HARNESS_MATT_SKILLS_ROOT/$skill/SKILL.md"
  exit 0
fi

# CC can coexist with unrelated shared skills, so its registry is authoritative
# when the plugin environment identifies CC as the active host.
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  if resolve_from_cc_registry; then
    exit 0
  fi
fi

for root in \
  "$HOME/.agents/skills" \
  "${CODEX_HOME:-$HOME/.codex}/skills"; do
  [[ -z "$root" ]] && continue
  if [[ -f "$root/$skill/SKILL.md" ]]; then
    printf '%s\n' "$root/$skill/SKILL.md"
    exit 0
  fi
  if [[ -d "$root" ]]; then
    candidate="$(find "$root" -type f -path "*/$skill/SKILL.md" -print -quit 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      exit 0
    fi
  fi
done

if resolve_from_cc_registry; then
  exit 0
fi

echo "Matt skill not found: $skill" >&2
echo "Install mattpocock/skills or set HARNESS_MATT_SKILLS_ROOT." >&2
exit 1
