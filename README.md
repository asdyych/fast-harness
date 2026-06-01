# royde-harness

An opinionated [Claude Code](https://claude.com/claude-code) harness, published as a single installable plugin. It bundles the **reusable, secret-free** pieces of a heavily-customized setup — the parts that make sense to share, without any personal rules, settings, memory, or credentials.

The headline is the **destructive-operation guard hook**: a thin safety rail for people who run Claude Code in `bypassPermissions` mode and have therefore removed the built-in permission wall.

## What's inside

| Component | What it is |
|---|---|
| `hooks/destructive_guard.sh` | A `PreToolUse` Bash guard that blocks **only** irreversible / blast-radius commands and lets every routine command through. |
| `agents/` | A curated roster of 15 subagents (architect, code-reviewer, security-reviewer, tdd-guide, database-reviewer, e2e-runner, …). |
| `skills/kill-port/` | A small utility skill to free a port that's stuck in use. |

## The guard hook

Claude Code's permission prompt is the thing standing between a model-issued command and your shell. If you run with `defaultMode: bypassPermissions` (for speed), that wall is gone — a single mistaken destructive command goes straight to the wire. This hook re-adds a **narrow, high-signal** rail for the operations that are both *irreversible* and *never part of a routine fast loop*.

**Blocks** (each is irreversible / blast-radius):

- `gcloud secrets delete` / `versions destroy`, `gcloud {sql,clusters,redis,compute} delete`
- `az {group,aks,postgres,redis,keyvault} delete`
- `terraform` / `tofu destroy`
- `kubectl delete {namespace,pvc,pv,deployment,statefulset,secret,-f}` — even inside `az aks command invoke "…"` or `gcloud … -- kubectl …`
- `alembic downgrade`, and `DROP TABLE/DATABASE/SCHEMA` / `TRUNCATE` via a DB client
- catastrophic `rm -rf /`, `~`, `$HOME`, `/*`, `--no-preserve-root`

**Always allowed** (your fast loop, untouched): `kubectl set image|rollout|patch|exec`, `kubectl delete pod|job`, `gcloud secrets versions add`, `terraform apply|plan`, `git worktree remove`, `rm -rf node_modules`, reading/grepping commands that merely *mention* a blocked phrase needs the marker (the guard matches command text — fail-safe by design).

**Bypass** — when you genuinely intend a blocked op, append the literal marker to the command:

```bash
terraform destroy -auto-approve  #DESTRUCTIVE-OK
```

The pattern lists are grouped A–E with comments inside the hook; tune to taste. Design rule: *block only what you can't undo* — a noisy guard gets disabled, which is worse than a narrow one.

## Install

```
/plugin marketplace add ch-royde/royde-harness
/plugin install royde-harness@royde-harness
```

After install, the guard hook is active on every Bash call, the subagents are available to the `Task` tool, and `/kill-port` works.

## Subagents

`architect` · `bug-analyzer` · `build-error-resolver` · `claude-md-guardian` · `code-reviewer` · `database-reviewer` · `dev-planner` · `doc-updater` · `e2e-runner` · `planner` · `refactor-cleaner` · `security-reviewer` · `story-generator` · `tdd-guide` · `ui-sketcher`

## What's deliberately NOT here

This plugin is the *mechanical* half of a harness. It intentionally excludes the personal half, which you should configure yourself in your own `~/.claude/`:

- **`settings.json` toggles** (`model`, `bypassPermissions`, `env`) — a plugin can't and shouldn't set your model or permission mode.
- **Global rules / `CLAUDE.md` instructions** — personal working discipline; bring your own.
- **Memory, MCP definitions, session history** — personal and/or secret-bearing.

If you want the guard but run with the normal permission prompt, it still works — it's just redundant with the prompt for the few commands it covers.

## License

MIT © ch-royde
