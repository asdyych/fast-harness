#!/usr/bin/env bash
# review-context.sh - single-shot preflight for the cross-review skill.
#
# Gathers EVERYTHING a peer reviewer needs in ONE execution — scope detection,
# base branch, changed files, the diff, and which peer CLI is available — so the
# agent spends one tool call here instead of 10+ round-trips collecting context.
#
# Usage:
#   review-context.sh [--scope auto|diff|branch|pr] [--base <ref>] [--peer auto|codex|cc|gemini]
#   (default --scope auto: local-diff → branch-ahead-of-base → open PR)
set -uo pipefail

# Report a caller or environment error before producing incomplete preflight.
die() {
  echo "$*" >&2
  exit 1
}

# Return success when auto-selection should avoid reviewing Codex with Codex.
is_codex_host() {
  case "${HARNESS_HOST:-}" in
    codex) return 0 ;;
    cc) return 1 ;;
    "") ;;
    *) die "unsupported HARNESS_HOST: $HARNESS_HOST (expected codex or cc)" ;;
  esac
  [[ "${CODEX_SHELL:-}" == "1" || -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]]
}

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
SCOPE=""; DETAIL=""; FILES=""; RANGE=""; UNTRACKED=""
# Resolve the preferred base to its remote ref when that ref exists.
ref_for_base() { if [[ -n "$HAS_REMOTE" ]] && git rev-parse --verify "origin/$BASE" >/dev/null 2>&1; then echo "origin/$BASE"; else echo "$BASE"; fi; }

# Detect staged or unstaged working-tree changes as the highest-priority scope.
detect_diff() {
  local d s
  d="$(git diff --stat 2>/dev/null)"
  s="$(git diff --cached --stat 2>/dev/null)"
  UNTRACKED="$(git ls-files --others --exclude-standard 2>/dev/null)"
  if [[ -n "$d" || -n "$s" || -n "$UNTRACKED" ]]; then
    SCOPE="local-diff"; DETAIL="uncommitted working tree"; RANGE=""
    FILES="$( { git diff --name-only; git diff --cached --name-only; printf '%s\n' "$UNTRACKED"; } 2>/dev/null | sed '/^$/d' | sort -u)"
  fi
}
# Detect commits ahead of the selected base when the working tree is clean.
detect_branch() {
  [[ -z "$BASE" ]] && return; local ref log; ref="$(ref_for_base)"
  log="$(git log "$ref..HEAD" --oneline 2>/dev/null || true)"
  if [[ -n "$log" ]]; then
    SCOPE="branch"; DETAIL="$(echo "$log" | wc -l | tr -d ' ') commits ahead of $ref"; RANGE="$ref...HEAD"
    FILES="$(git diff --name-only "$ref...HEAD" 2>/dev/null | sed '/^$/d' | sort -u)"
  fi
}
# Detect the current pull request when neither local nor branch scope applies.
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

# --- peer availability: prefer a different host family when one is available.
# Expand a requested peer alias into executable candidates in preference order.
append_peer_candidates() {
  case "$1" in
    auto)
      if is_codex_host; then
        PEER_CANDIDATES+=(cc claude claudecode claude-code gemini codex)
      else
        PEER_CANDIDATES+=(codex gemini claude claudecode claude-code cc)
      fi
      ;;
    codex) PEER_CANDIDATES+=(codex) ;;
    gemini) PEER_CANDIDATES+=(gemini) ;;
    cc|claude|claudecode|claude-code) PEER_CANDIDATES+=(cc claude claudecode claude-code) ;;
    *) PEER_CANDIDATES+=("$1") ;;
  esac
}

# Confirm that a candidate is the CC CLI, not the system C compiler named cc.
is_cc_cli() {
  local candidate="$1"
  local version
  command -v "$candidate" >/dev/null 2>&1 || return 1
  version="$("$candidate" --version 2>/dev/null | head -n 1 || true)"
  [[ "$version" == *"Claude Code"* ]]
}

# Return success when a peer executable matches its expected protocol.
is_peer_cli() {
  local candidate="$1"
  case "$candidate" in
    cc|claude|claudecode|claude-code) is_cc_cli "$candidate" ;;
    codex|gemini) command -v "$candidate" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# Emit bounded no-index diffs so newly created files are visible to the peer.
emit_untracked_diffs() {
  local max_bytes file bytes
  max_bytes="${REVIEW_CONTEXT_MAX_UNTRACKED_BYTES:-262144}"
  [[ "$max_bytes" =~ ^[1-9][0-9]*$ ]] || max_bytes=262144
  [[ -n "$UNTRACKED" ]] || return

  echo
  echo "=== untracked file diffs ==="
  while IFS= read -r file; do
    [[ -n "$file" && -f "$file" ]] || continue
    bytes="$(wc -c < "$file" | tr -d ' ')"
    if (( bytes > max_bytes )); then
      echo "UNTRACKED FILE OMITTED: $file (${bytes} bytes; limit ${max_bytes})"
      continue
    fi
    git diff --no-index -- /dev/null "$file" 2>/dev/null || true
  done <<< "$UNTRACKED"
}

PEER=""
PEER_CANDIDATES=()
if [[ -n "$PEER_PREF" ]]; then
  append_peer_candidates "$PEER_PREF"
elif is_codex_host; then
  PEER_CANDIDATES=(cc claude claudecode claude-code gemini codex)
else
  PEER_CANDIDATES=(codex gemini claude claudecode claude-code cc)
fi
SEEN_PEERS=" "
for p in "${PEER_CANDIDATES[@]}"; do
  [[ -z "$p" ]] && continue
  case "$SEEN_PEERS" in
    *" $p "*) continue ;;
  esac
  SEEN_PEERS="$SEEN_PEERS$p "
  if is_peer_cli "$p"; then
    case "$p" in
      cc) PEER="cc (cli)" ;;
      claude|claudecode|claude-code) PEER="cc (cli)" ;;
      *) PEER="$p (cli)" ;;
    esac
    break
  fi
done
[[ -z "$PEER" ]] && PEER="none (no supported peer CLI on PATH)"

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
if [[ -n "$RANGE" ]]; then
  git diff "$RANGE"
else
  git diff
  git diff --cached
  emit_untracked_diffs
fi
