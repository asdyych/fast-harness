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
  'code-review' \
  'mandatory `cross-review`' \
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
  'do not duplicate that' \
  'fixed-mode direct aliases' \
  'do not claim the Goal complete'; do
  grep -qF "$phrase" "$SKILL" || {
    echo "missing workflow boundary phrase: $phrase" >&2
    exit 1
  }
done
