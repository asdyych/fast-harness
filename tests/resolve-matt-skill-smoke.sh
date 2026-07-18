#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${1:?usage: resolve-matt-skill-smoke.sh <resolve-matt-skill.sh>}"
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/home/.agents/skills/to-spec"
printf '%s\n' '# shared' > "$tmp/home/.agents/skills/to-spec/SKILL.md"
resolved="$(HOME="$tmp/home" "$SCRIPT" to-spec)"
[[ "$resolved" == "$tmp/home/.agents/skills/to-spec/SKILL.md" ]]

rm -rf "$tmp/home/.agents"
mkdir -p "$tmp/codex/skills/implement"
printf '%s\n' '# codex' > "$tmp/codex/skills/implement/SKILL.md"
resolved="$(HOME="$tmp/home" CODEX_HOME="$tmp/codex" "$SCRIPT" implement)"
[[ "$resolved" == "$tmp/codex/skills/implement/SKILL.md" ]]

rm -rf "$tmp/codex"
cc_root="$tmp/home/.claude/plugins/cache/mattpocock/mattpocock-skills/1.2.0"
mkdir -p "$cc_root/skills/engineering/code-review"
printf '%s\n' '# cc' > "$cc_root/skills/engineering/code-review/SKILL.md"
mkdir -p "$tmp/home/.claude/plugins"
cat > "$tmp/home/.claude/plugins/installed_plugins.json" <<JSON
{"plugins":{"mattpocock-skills@mattpocock":[{"installPath":"$cc_root","lastUpdated":"2026-07-18T00:00:00Z"}]}}
JSON
resolved="$(HOME="$tmp/home" "$SCRIPT" code-review)"
[[ "$resolved" == "$cc_root/skills/engineering/code-review/SKILL.md" ]]

mkdir -p "$tmp/home/.agents/skills/code-review"
printf '%s\n' '# unrelated shared skill' > "$tmp/home/.agents/skills/code-review/SKILL.md"
resolved="$(HOME="$tmp/home" CLAUDE_PLUGIN_ROOT="$tmp/fast-harness" "$SCRIPT" code-review)"
[[ "$resolved" == "$cc_root/skills/engineering/code-review/SKILL.md" ]]

if HOME="$tmp/home" "$SCRIPT" '../bad' > /dev/null 2>&1; then
  echo "expected unsafe skill name to be rejected" >&2
  exit 1
fi

if HOME="$tmp/home" "$SCRIPT" missing-skill > /dev/null 2>&1; then
  echo "expected missing skill to fail" >&2
  exit 1
fi
