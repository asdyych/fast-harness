#!/usr/bin/env bash
set -euo pipefail

SKILL="${1:?usage: harness-workflow-contract-smoke.sh <harness-workflow/SKILL.md>}"
PLUGIN_ROOT="$(cd "$(dirname "$SKILL")/../.." && pwd)"
CHECKPOINT_SKILL="$PLUGIN_ROOT/skills/checkpoint-commits/SKILL.md"

for phrase in \
  '按照 harness 的流程去实现' \
  '按照harness的流程去实现' \
  '快速实现' \
  '/fast-harness-full' \
  '/fast-harness-quick' \
  'to-spec' \
  'to-tickets' \
  'implement' \
  'single mandatory `cross-review`' \
  'git push -u origin <current-branch>' \
  'Never use `--force`' \
  'workflow_base=$(git rev-parse HEAD)'; do
  grep -qF "$phrase" "$SKILL" || {
    echo "missing workflow contract phrase: $phrase" >&2
    exit 1
  }
done

for phrase in \
  'main agent ordinary-pushes every' \
  'coordinator-granted serialized commit window' \
  'never pushes' \
  'delegated subagent stops after returning its commit'; do
  grep -qF "$phrase" "$CHECKPOINT_SKILL" || {
    echo "missing delegated checkpoint contract phrase: $phrase" >&2
    exit 1
  }
done

for phrase in \
  'Quick mode' \
  'Full mode' \
  'Core-loop scope discipline' \
  'Automatic delegation' \
  'Both Full and Quick modes may delegate independent code slices' \
  'Apply the core automatic-delegation rule' \
  'SessionStart delegation rule' \
  'ordinary-pushes every reviewed' \
  'run it through `e2e-browser`' \
  'If the change has no browser-reachable behavior' \
  'console errors and failed business requests as failures' \
  'Do not add implementation or tests for speculative edge cases' \
  'Stop expanding tests when the acceptance checks' \
  'Require either a configured upstream or an `origin` remote' \
  "workflow's only review gate" \
  'fixed-mode direct aliases' \
  'do not claim the Goal complete'; do
  grep -qF "$phrase" "$SKILL" || {
    echo "missing workflow boundary phrase: $phrase" >&2
    exit 1
  }
done

if grep -qF 'both required' "$SKILL"; then
  echo 'workflow must not require two reviews' >&2
  exit 1
fi

for obsolete in \
  'code-review` -> `cross-review' \
  'normal `code-review` and different-model' \
  'run both reviews' \
  'Subagents do not commit or push' \
  'Quick mode stays with the main agent by default'; do
  if grep -qF "$obsolete" "$SKILL"; then
    echo "obsolete double-review contract: $obsolete" >&2
    exit 1
  fi
done
