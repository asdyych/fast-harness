#!/usr/bin/env bash
set -euo pipefail

SCRIPT="${1:?usage: review-context-smoke.sh <review-context.sh>}"
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
for cli in codex cc; do
  cat > "$tmp/bin/$cli" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$(basename "$0")" == "cc" ]]; then
  printf '%s\n' '2.1.207 (Claude Code)'
else
  printf '%s stub\n' "$(basename "$0")"
fi
SH
  chmod +x "$tmp/bin/$cli"
done

cd "$tmp"
git init -q
printf '# tmp\n' > README.md
git add README.md
git commit -qm init
printf 'changed\n' >> README.md
printf 'new review surface\n' > new-file.md

PATH="$tmp/bin:$PATH" HARNESS_HOST=codex "$SCRIPT" > preflight.out
grep -q 'peer=cc (cli)' preflight.out
grep -q '^new-file.md$' preflight.out
grep -q '^+new review surface$' preflight.out

PATH="$tmp/bin:$PATH" HARNESS_HOST=cc "$SCRIPT" > cc-host.out
grep -q 'peer=codex (cli)' cc-host.out

PATH="$tmp/bin:$PATH" "$SCRIPT" --peer codex > requested.out
grep -q 'peer=codex (cli)' requested.out

PATH="$tmp/bin:$PATH" "$SCRIPT" --peer cc > requested-cc.out
grep -q 'peer=cc (cli)' requested-cc.out
