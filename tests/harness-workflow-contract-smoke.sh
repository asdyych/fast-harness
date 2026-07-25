#!/usr/bin/env bash
set -euo pipefail

SKILL="${1:?usage: harness-workflow-contract-smoke.sh <harness-workflow/SKILL.md>}"

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
  'Quick mode' \
  'Full mode' \
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
  'run both reviews'; do
  if grep -qF "$obsolete" "$SKILL"; then
    echo "obsolete double-review contract: $obsolete" >&2
    exit 1
  fi
done
