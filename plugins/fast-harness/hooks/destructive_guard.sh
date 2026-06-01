#!/usr/bin/env bash
# destructive_guard.sh — PreToolUse hook for the Bash tool.
#
# A surgical rail for irreversible / blast-radius operations against
# production & shared infra. It is the SECOND half of a deliberately
# split guard:
#   - litellm_prod_guard.sh  → production LiteLLM proxy writes
#   - destructive_guard.sh   → cloud teardown, k8s blast-radius deletes,
#                              terraform destroy, DB schema destruction,
#                              catastrophic rm
#
# Why this exists:
#   The operator runs Claude Code with `defaultMode: bypassPermissions`
#   + `skipDangerousModePermissionPrompt: true` for speed. That removes
#   the built-in permission wall, so a single mistaken destructive
#   command (the 2026-05-25 LiteLLM key-delete incident is the canonical
#   example) goes straight to the wire. This hook re-adds a thin,
#   high-signal rail for ONLY the operations that are both irreversible
#   AND never part of a routine fast loop. Everything routine
#   (set image / rollout / patch / exec / secrets versions add /
#   worktree cleanup / git / npm) passes untouched.
#
# Design rule: block only what you can't undo. When in doubt, allow —
# a noisy guard gets disabled, which is worse than a narrow one.
#
# Hook protocol:
#   - stdin JSON: { "tool_name": "Bash", "tool_input": { "command": "..." } }
#   - exit 0 → allow
#   - exit 2 → block; stderr is surfaced to Claude
#
# Bypass (conscious operator acknowledgement): append the literal comment
#   #DESTRUCTIVE-OK
# to the command. Like the LiteLLM marker, this should be a deliberate
# decision, not autopilot.

set -euo pipefail

input=$(cat)

tool=$(echo "$input" | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('tool_name',''))
except Exception:
    print('')
" 2>/dev/null || echo "")

[[ "$tool" != "Bash" ]] && exit 0

command=$(echo "$input" | python3 -c "
import json, sys
try:
    print((json.load(sys.stdin).get('tool_input') or {}).get('command',''))
except Exception:
    print('')
" 2>/dev/null || echo "")

[[ -z "$command" ]] && exit 0

match() { echo "$command" | grep -qiE "$1"; }

reason=""
howto=""

# --- A. Cloud infra teardown (irreversible) -------------------------------
if match 'gcloud[[:space:]]+secrets[[:space:]]+(versions[[:space:]]+destroy|delete)([[:space:]]|$)'; then
  reason="gcloud Secret Manager destroy/delete"
  howto="Rollback depends on old versions — use 'gcloud secrets versions disable' instead of destroy/delete (see feedback_strip_newline_secret_write / preserve-rollback-secrets)."
elif match 'gcloud[[:space:]]+(sql[[:space:]]+instances|container[[:space:]]+clusters|redis[[:space:]]+instances|compute[[:space:]]+[a-z-]+)[[:space:]]+delete([[:space:]]|$)'; then
  reason="gcloud managed-resource delete (sql/cluster/redis/compute — irreversible infra teardown)"
elif match 'az[[:space:]]+(group|aks|postgres|redis|keyvault)[[:space:]]+delete([[:space:]]|$)'; then
  reason="az resource delete (group/aks/postgres/redis/keyvault — irreversible infra teardown)"

# --- B. IaC destroy -------------------------------------------------------
elif match '(terraform|tofu)[[:space:]]+(.*[[:space:]])?destroy([[:space:]]|$)'; then
  reason="terraform/tofu destroy"
  howto="'apply' and 'plan' are not blocked — only an explicit 'destroy'."

# --- C. kubectl blast-radius deletes --------------------------------------
# Matches kubectl ... delete {namespace|pvc|pv|deployment|statefulset|secret|-f}
# regardless of wrapper (az aks command invoke "...", gcloud ... -- kubectl ...).
# Pods/jobs/replicasets are intentionally NOT matched (reversible, routine).
elif match 'kubectl[[:space:]].*delete[[:space:]]+(-f[[:space:]]|--filename|(namespace|ns|persistentvolumeclaim|pvc|persistentvolume|pv|deployment|deploy|statefulset|sts|secret)[[:space:]/])'; then
  reason="kubectl delete of a blast-radius resource (namespace/pvc/pv/deployment/statefulset/secret or -f manifest)"
  howto="'kubectl delete pod|job', set image, rollout, patch, exec are not blocked."

# --- D. Database schema destruction ---------------------------------------
elif match 'alembic[[:space:]]+downgrade([[:space:]]|$)'; then
  reason="alembic downgrade (schema rollback — never routine on a live DB)"
  howto="'alembic upgrade head' is the routine path and is not blocked."
elif echo "$command" | grep -qiE '(psql|mysql|mariadb)' \
  && echo "$command" | grep -qiE 'drop[[:space:]]+(table|database|schema)([[:space:]]|;|$)|truncate[[:space:]]+(table[[:space:]]+)?[a-z_"]'; then
  reason="destructive SQL (DROP TABLE/DATABASE/SCHEMA or TRUNCATE) via a DB client"

# --- E. Catastrophic filesystem removal -----------------------------------
elif match 'rm[[:space:]]+([^|;&]*[[:space:]])?(-[[:alnum:]]*[rR][[:alnum:]]*[fF]|-[[:alnum:]]*[fF][[:alnum:]]*[rR]|--recursive|--force)([^|;&]*[[:space:]])?(/|/\*|~|~/|\$\{?HOME\}?)([[:space:]/*]|$)'; then
  reason="catastrophic 'rm -rf' on a root path (/, ~, \$HOME, /*)"
  howto="Removing a specific worktree (rm -rf .claude/worktrees/<name>) is not blocked."
elif match 'rm[[:space:]].*--no-preserve-root'; then
  reason="rm --no-preserve-root"
fi

[[ -z "$reason" ]] && exit 0

# --- Override marker ------------------------------------------------------
if echo "$command" | grep -q '#DESTRUCTIVE-OK'; then
  echo "[destructive-guard] override marker present — allowing: $reason" >&2
  exit 0
fi

# --- Block + explain ------------------------------------------------------
cat >&2 <<EOF
[destructive-guard] BLOCKED: this command is irreversible / blast-radius.

Category: $reason
${howto:+Note:     $howto}

This rail exists because Claude Code runs here in bypassPermissions mode —
there is no permission prompt between this command and the wire. Confirm
the target is what you think it is (right cluster? right project? right
env?), then choose:

  • If this is genuinely intended: append the literal marker and re-run:
        #DESTRUCTIVE-OK
  • If you're testing a theory: run it against a LOCAL/disposable target,
    not production or shared infra.
  • If this is a false positive (the regex over-matched a safe command):
    note this matches command TEXT — a command that only *mentions* a
    blocked phrase (an echo / grep / test payload or heredoc) trips it too.
    Add the marker, or avoid embedding the literal phrase. To retune the
    patterns, edit the destructive_guard.sh hook (groups A–E are commented).

Command that was blocked:
$command
EOF

exit 2
