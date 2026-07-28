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

grep -qF 'Use the `fast-harness-full` skill with `$ARGUMENTS`.' "$full_command"
grep -qF 'Use the `fast-harness-quick` skill with `$ARGUMENTS`.' "$quick_command"

grep -qF 'name: fast-harness-full' "$full_skill"
grep -qF 'Use `harness-workflow` in full mode.' "$full_skill"
grep -qF 'Treat all remaining user text as the goal.' "$full_skill"
grep -qF 'name: fast-harness-quick' "$quick_skill"
grep -qF 'Use `harness-workflow` in quick mode.' "$quick_skill"
grep -qF 'Treat all remaining user text as the goal.' "$quick_skill"
