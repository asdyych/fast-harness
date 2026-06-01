# royde-harness

An opinionated [Claude Code](https://claude.com/claude-code) harness, published as a single installable plugin. It bundles the **reusable, secret-free** pieces of a heavily-customized setup — the parts that make sense to share, without any personal rules, settings, memory, or credentials.

The headline is the **destructive-operation guard hook**: a thin safety rail for people who run Claude Code in `bypassPermissions` mode and have therefore removed the built-in permission wall.

## Quick start

Add the marketplace once, then install the whole harness — this plugin plus the two upstream companions it pairs with — in one go:

```
/plugin marketplace add ch-royde/royde-harness
/plugin install royde-harness@royde-harness                 # this plugin: guard hook + 15 agents + kill-port
/plugin install superpowers@royde-harness                   # obra/superpowers (referenced upstream)
/plugin install harness-engineering-skills@royde-harness    # stone16/harness-engineering-skills (referenced upstream)
```

Want only the guard + agents? Run the first two lines and stop. After install, the guard hook is active on every Bash call, the subagents are available to the `Task` tool, the `worktree-dev` / `review-loop` / `kill-port` skills and their slash commands (`/wt-start`, `/wt-stop`, `/wt-status`, `/review-loop`) are usable.

## What's inside

| Component | What it is |
|---|---|
| `hooks/destructive_guard.sh` | A `PreToolUse` Bash guard that blocks **only** irreversible / blast-radius commands and lets every routine command through. |
| `skills/worktree-dev/` | Profile-driven manager for a per-worktree dev environment — copy env both ends, symlink deps, launch the service trio, health-check, tear down. Commands: `/wt-start`, `/wt-stop`, `/wt-status`. |
| `skills/review-loop/` | A lean cross-LLM review loop (codex/gemini peer, apply accepted fixes, max 2 rounds) with a built-in "rigor ≠ right" discipline. Command: `/review-loop`. |
| `agents/` | A curated roster of 15 subagents (architect, code-reviewer, security-reviewer, tdd-guide, database-reviewer, e2e-runner, …). |
| `skills/kill-port/` | A small utility skill to free a port that's stuck in use. |

These two skills are the bespoke core — they encode a worktree-per-task dev ritual and a cross-model review discipline distilled from heavy daily use, rather than wrapping a generic framework.

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

## worktree-dev

A worktree-per-task workflow repeats the same setup ritual every time. `scripts/harness-worktree-dev.sh` drives it from a per-repo profile (`.harness-dev.conf`):

```bash
/wt-start    # copy env (both ends) + symlink .venv/node_modules + free ports + start services + health-check
/wt-status   # which services are running, which ports are up
/wt-stop     # kill service PIDs + free ports — worktree left intact (no implicit removal)
```

The profile declares `MAIN_CHECKOUT`, `ENV_FILES`, `SYMLINKS`, `SERVICES` (`name|port|subdir|command`), and `HEALTH` — see `skills/worktree-dev/example.harness-dev.conf`. The skill carries the judgment the script can't: copy *all* env files (a missing frontend `VITE_*` is silently `undefined`), restart Vite after env edits (it snapshots env at startup), and never treat a green backend `/healthz` as proof the frontend can log in.

## review-loop

A lean, two-round-max cross-model review of the current diff — the opposite of a heavyweight orchestrator. `/review-loop` gathers context via `scripts/review-context.sh`, sends it to one peer (codex MCP or `gemini` CLI), and applies only the findings you accept. Its built-in discipline guards against the failure mode of review loops: they bias toward *adding constraints*, so "self-consistent" drifts away from "right." Lock the meta-goal, down-weight "critical" implementation-detail findings, cap at two rounds, and re-check against the original goal — **rigor ≠ right**.

## Companion plugins (referenced, not vendored)

The last two install lines in [Quick start](#quick-start) pull in third-party plugins this harness is designed to pair with. They are **referenced from their upstream repos** — never copied into this one — so they always track their own maintainers and stay current:

- **superpowers** ([obra/superpowers](https://github.com/obra/superpowers)) — TDD, brainstorming, systematic debugging, and collaboration skills.
- **harness-engineering-skills** ([stone16/harness-engineering-skills](https://github.com/stone16/harness-engineering-skills)) — cross-LLM `review-loop` and the cybernetics `harness` orchestrator.

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
