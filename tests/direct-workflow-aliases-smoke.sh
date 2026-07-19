#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="${1:?usage: direct-workflow-aliases-smoke.sh <plugin-root>}"

full_command="$PLUGIN_ROOT/commands/fast-harness-full.md"
quick_command="$PLUGIN_ROOT/commands/fast-harness-quick.md"
full_skill="$PLUGIN_ROOT/skills/fast-harness-full/SKILL.md"
quick_skill="$PLUGIN_ROOT/skills/fast-harness-quick/SKILL.md"

for file in "$full_command" "$quick_command" "$full_skill" "$quick_skill"; do
  [[ -f "$file" ]] || { echo "missing direct workflow alias: $file" >&2; exit 1; }
done

grep -qF 'always selects' "$full_command"
grep -qF 'full mode' "$full_command"
grep -qF 'cannot switch it to quick mode' "$full_command"
grep -qF 'always selects' "$quick_command"
grep -qF 'quick mode' "$quick_command"
grep -qF 'cannot switch it to full mode' "$quick_command"

grep -qF 'name: fast-harness-full' "$full_skill"
grep -qF 'to-spec, to-tickets, per-ticket implement' "$full_skill"
grep -qF 'Do not let words' "$full_skill"
grep -qF 'name: fast-harness-quick' "$quick_skill"
grep -qF 'without spec or tickets' "$quick_skill"
grep -qF 'Do not let words' "$quick_skill"
