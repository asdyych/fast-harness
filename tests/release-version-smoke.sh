#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:?usage: release-version-smoke.sh <repo-root>}"

python3 - "$REPO_ROOT" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])

with (root / ".claude-plugin/marketplace.json").open(encoding="utf-8") as handle:
    marketplace = json.load(handle)
with (root / "plugins/fast-harness/.claude-plugin/plugin.json").open(encoding="utf-8") as handle:
    claude_manifest = json.load(handle)
with (root / "plugins/fast-harness/.codex-plugin/plugin.json").open(encoding="utf-8") as handle:
    codex_manifest = json.load(handle)

marketplace_plugin = next(
    plugin for plugin in marketplace["plugins"] if plugin["name"] == "fast-harness"
)
base_version = claude_manifest["version"]
versions = {
    "marketplace metadata": marketplace["metadata"]["version"],
    "marketplace plugin": marketplace_plugin["version"],
    "Claude manifest": base_version,
    "Codex manifest base": codex_manifest["version"].split("+", 1)[0],
}

if len(set(versions.values())) != 1:
    raise SystemExit(f"release version mismatch: {versions}")

if not re.fullmatch(rf"{re.escape(base_version)}\+codex\.\d{{14}}", codex_manifest["version"]):
    raise SystemExit(f"invalid Codex cachebuster version: {codex_manifest['version']}")
PY
