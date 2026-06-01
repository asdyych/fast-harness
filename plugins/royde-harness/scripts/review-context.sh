#!/usr/bin/env bash
# review-context.sh — single-shot preflight for the review-loop skill.
#
# Gathers EVERYTHING a peer reviewer needs in ONE execution — scope detection,
# base branch, changed files, the diff, and which peer CLI is available — so the
# agent spends one tool call here instead of 10+ round-trips collecting context.
#
# Usage:
#   review-context.sh [--scope auto|diff|branch|pr] [--base <ref>] [--peer codex|gemini|claude]
#   (default --scope auto: local-diff → branch-ahead-of-base → open PR)
set -uo pipefail

SCOPE_PREF="auto"; BASE=""; PEER_PREF=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE_PREF="${2:-auto}"; shift 2;;
    --base)  BASE="${2:-}"; shift 2;;
    --peer)  PEER_PREF="${2:-}"; shift 2;;
    *) shift;;   # tolerate stray args (e.g. an empty $ARGUMENTS)
  esac
done

# --- base branch detection: origin/HEAD → main/master/develop (remote or local)
if [[ -z "$BASE" ]]; then
  BASE="$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's|origin/||')"
  [[ "$BASE" == "HEAD" ]] && BASE=""
  if [[ -z "$BASE" ]]; then
    for b in main master develop; do
      if git rev-parse --verify "origin/$b" >/dev/null 2>&1 || git rev-parse --verify "$b" >/dev/null 2>&1; then BASE="$b"; break; fi
    done
  fi
fi
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
HAS_REMOTE="$(git remote 2>/dev/null | head -1)"

# --- scope detection: sets SCOPE / DETAIL / FILES / RANGE
SCOPE=""; DETAIL=""; FILES=""; RANGE=""
ref_for_base() { if [[ -n "$HAS_REMOTE" ]] && git rev-parse --verify "origin/$BASE" >/dev/null 2>&1; then echo "origin/$BASE"; else echo "$BASE"; fi; }

detect_diff() {
  local d s; d="$(git diff --stat 2>/dev/null)"; s="$(git diff --cached --stat 2>/dev/null)"
  if [[ -n "$d" || -n "$s" ]]; then
    SCOPE="local-diff"; DETAIL="uncommitted working tree"; RANGE=""
    FILES="$( { git diff --name-only; git diff --cached --name-only; } 2>/dev/null | sed '/^$/d' | sort -u)"
  fi
}
detect_branch() {
  [[ -z "$BASE" ]] && return; local ref log; ref="$(ref_for_base)"
  log="$(git log "$ref..HEAD" --oneline 2>/dev/null || true)"
  if [[ -n "$log" ]]; then
    SCOPE="branch"; DETAIL="$(echo "$log" | wc -l | tr -d ' ') commits ahead of $ref"; RANGE="$ref...HEAD"
    FILES="$(git diff --name-only "$ref...HEAD" 2>/dev/null | sed '/^$/d' | sort -u)"
  fi
}
detect_pr() {
  command -v gh >/dev/null 2>&1 || return
  local j n t ref; j="$(gh pr view --json number,title 2>/dev/null || true)"; [[ -z "$j" ]] && return
  n="$(echo "$j" | grep -o '"number":[0-9]*' | grep -o '[0-9]*')"
  t="$(echo "$j" | sed -n 's/.*"title":"\([^"]*\)".*/\1/p')"
  ref="$(ref_for_base)"
  SCOPE="pr-$n"; DETAIL="PR #$n: $t"; RANGE="$ref...HEAD"
  FILES="$(git diff --name-only "$ref...HEAD" 2>/dev/null | sed '/^$/d' | sort -u)"
}

case "$SCOPE_PREF" in
  diff)   detect_diff;;
  branch) detect_branch;;
  pr)     detect_pr;;
  *)      detect_diff; [[ -z "$SCOPE" ]] && detect_branch; [[ -z "$SCOPE" ]] && detect_pr;;
esac

# --- peer availability: prefer requested, else first CLI on PATH; codex is also reachable as an MCP tool
PEER=""
for p in ${PEER_PREF:-} codex gemini claude; do
  [[ -z "$p" ]] && continue
  command -v "$p" >/dev/null 2>&1 && { PEER="$p (cli)"; break; }
done
[[ -z "$PEER" ]] && PEER="codex (mcp tool — no peer CLI on PATH)"

# --- emit single structured block
echo "=== review preflight | scope=${SCOPE:-none}  base=${BASE:-?}  head=$HEAD_SHA  peer=$PEER ==="
if [[ -z "$SCOPE" ]]; then echo "NO CHANGES DETECTED — nothing to review."; exit 0; fi
echo "DETAIL: $DETAIL"
echo
echo "=== changed files ==="
echo "${FILES:-(none auto-detected — inspect the working tree using the scope above)}"
echo
echo "=== status (working tree) ==="
git status --short
echo
echo "=== diff ==="
if [[ -n "$RANGE" ]]; then git diff "$RANGE"; else git diff; git diff --cached; fi
