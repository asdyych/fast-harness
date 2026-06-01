#!/usr/bin/env bash
# harness-test-accounts.sh — manage a LOCAL, gitignored store of test accounts.
#
# Store: <repo-root>/.harness/test-accounts.json  (chmod 600, .harness/ gitignored).
# Holds plaintext credentials for E2E logins — it is NEVER committed and passwords
# are never printed by `list` (only by `get`, which the agent uses at login time).
#
# Subcommands:
#   list                                  labels + url + username + role (password masked)
#   get <label> [--field f]               emit the full record, or one field
#   add --label L --username U [--url U --password P --role R --login HINT --notes N]
#   path                                  print the store path
#
# Record shape is generic (no auth-provider assumption):
#   { label, app_url, username, password, role, login, notes }
#   `login` is a free hint for the agent's login flow (e.g. logto|basic|oauth|custom).
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STORE="$ROOT/.harness/test-accounts.json"

ensure_store(){
  mkdir -p "$ROOT/.harness"
  [[ -f "$STORE" ]] || { printf '{\n  "accounts": []\n}\n' > "$STORE"; }
  # Safety invariants — fail loudly rather than leave creds exposed/committable.
  chmod 600 "$STORE" || { echo "FATAL: cannot chmod 600 $STORE — refusing (would leave credentials readable)" >&2; exit 1; }
  if ! grep -qxF '.harness/' "$ROOT/.gitignore" 2>/dev/null; then
    printf '\n.harness/\n' >> "$ROOT/.gitignore" || { echo "FATAL: cannot add .harness/ to $ROOT/.gitignore — refusing (credentials could be committed)" >&2; exit 1; }
  fi
}

CMD="${1:-}"; [[ -n "$CMD" ]] && shift || true
case "$CMD" in
  list)
    ensure_store
    python3 - "$STORE" <<'PY'
import json,sys
acc=json.load(open(sys.argv[1])).get("accounts",[])
if not acc: print("(no accounts recorded — use: harness-test-accounts.sh add --label L --username U ...)"); sys.exit(0)
for a in acc:
    print(f"  {a.get('label','?'):14} {a.get('role',''):8} {a.get('username','')}  @ {a.get('app_url','')}  [pwd:{'set' if a.get('password') else 'MISSING'}]  login={a.get('login','')}")
PY
    ;;
  get)
    ensure_store
    label="${1:?usage: get <label> [--field f]}"; shift || true
    field=""; [[ "${1:-}" == "--field" ]] && field="${2:?}"
    python3 - "$STORE" "$label" "$field" <<'PY'
import json,sys
store,label,field=sys.argv[1],sys.argv[2],sys.argv[3]
m=[a for a in json.load(open(store)).get("accounts",[]) if a.get("label")==label]
if not m: print(f"no account labelled '{label}'",file=sys.stderr); sys.exit(1)
a=m[0]
if field: print(a.get(field,""))
else:
    for k in ("label","app_url","username","password","role","login","notes"):
        if a.get(k) not in (None,""): print(f"{k}: {a.get(k)}")
PY
    ;;
  add)
    ensure_store
    label=""; url=""; user=""; pw=""; role=""; login=""; notes=""
    while [[ $# -gt 0 ]]; do case "$1" in
      --label) label="${2:?}"; shift 2;;  --url) url="${2:?}"; shift 2;;
      --username) user="${2:?}"; shift 2;; --password) pw="${2:?}"; shift 2;;
      --password-stdin) IFS= read -r pw || true; shift;;   # preferred: keeps the password out of argv/ps
      --role) role="${2:?}"; shift 2;;     --login) login="${2:?}"; shift 2;;
      --notes) notes="${2:?}"; shift 2;;   *) echo "unknown: $1" >&2; exit 2;;
    esac; done
    [[ -n "$label" && -n "$user" ]] || { echo "need at least --label and --username" >&2; exit 2; }
    python3 - "$STORE" "$label" "$url" "$user" "$pw" "$role" "$login" "$notes" <<'PY'
import json,sys,os,tempfile
store,label,url,user,pw,role,login,notes=sys.argv[1:9]
d=json.load(open(store)); acc=d.setdefault("accounts",[])
acc[:]=[a for a in acc if a.get("label")!=label]   # replace same-label
acc.append({"label":label,"app_url":url,"username":user,"password":pw,"role":role,"login":login,"notes":notes})
# atomic write with 600 perms so a mid-write crash can't corrupt or expose the store
fd,tmp=tempfile.mkstemp(dir=os.path.dirname(store))
os.fchmod(fd,0o600)
try:
    with os.fdopen(fd,"w") as f: json.dump(d,f,indent=2,ensure_ascii=False)
    os.replace(tmp,store)
except Exception:
    os.path.exists(tmp) and os.unlink(tmp); raise
print(f"saved account '{label}' ({len(acc)} total) — stored locally (chmod 600), gitignored")
PY
    ;;
  path) ensure_store; echo "$STORE";;
  *) echo "usage: harness-test-accounts.sh <list|get <label>|add ...|path>" >&2; exit 2;;
esac
