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

Want only the guard + agents? Run the first two lines and stop. After install, the guard hook is active on every Bash call, the subagents are available to the `Task` tool, and the `worktree-dev` / `review-loop` / `verify` / `e2e-browser` / `clean-context` / `retro` / `kill-port` skills and their slash commands (`/wt-start`, `/wt-stop`, `/wt-status`, `/verify`, `/e2e`, `/chrome-cdp`, `/review-loop`, `/retro`) are usable.

## What's inside

| Component | What it is |
|---|---|
| `hooks/destructive_guard.sh` | A `PreToolUse` Bash guard that blocks **only** irreversible / blast-radius commands and lets every routine command through. |
| `skills/worktree-dev/` | Profile-driven manager for a per-worktree dev environment — copy env both ends, symlink deps, launch the service trio, health-check, tear down. Commands: `/wt-start`, `/wt-stop`, `/wt-status`. |
| `skills/verify/` | Code-level green gate — frontend `tsc --noEmit` + `vitest` coverage + optional backend tests, project-agnostic via `.harness-dev.conf`. Command: `/verify`. |
| `skills/e2e-browser/` | Agent-driven **real-browser** E2E — an isolated CDP Chrome window (never touches your main Chrome), login with a recorded test account, drive the actual business flow, capture evidence. Commands: `/e2e`, `/chrome-cdp`. |
| `skills/review-loop/` | A multi-round cross-LLM review loop (codex/gemini peer, single-shot preflight, iterate to convergence, evidence-based rejects) with a built-in "rigor ≠ right" anti-drift discipline. Command: `/review-loop`. |
| `skills/clean-context/` | When to dispatch independent work (search, large reads, subtasks, review) to a **fresh sub-agent** to keep the main context clean. |
| `skills/retro/` | A lightweight retrospective that turns recurring harness friction (3+ occurrences) into a **tracked GitHub issue** + ready-to-paste edits **to this plugin itself**. Command: `/retro` (repo via `HARNESS_RETRO_REPO`). |
| `agents/` | A curated roster of 15 subagents (architect, code-reviewer, security-reviewer, tdd-guide, database-reviewer, e2e-runner, …). |
| `skills/kill-port/` | A small utility skill to free a port that's stuck in use. |

These skills are the bespoke core — a worktree-per-task dev ritual, a two-layer testing story, a cross-model review discipline, context hygiene, and a self-improvement loop distilled from heavy daily use, rather than a wrapped generic framework. The review-loop and clean-context patterns absorb the best ideas from heavier harnesses (convergence-driven iteration, evidence-based rejection, fresh-context-per-unit) without their orchestration weight.

## Testing (two layers)

Project-agnostic — the harness supplies the mechanism; each repo supplies its app URL, login flow, accounts, and test commands via `.harness-dev.conf` + a gitignored account store.

- **Code level — `/verify`:** `npx tsc --noEmit` + `npx vitest run --coverage` (and an optional backend test command). Fast, deterministic; necessary but not sufficient.
- **E2E — `/e2e`:** opens a fresh **isolated** Chrome window with CDP enabled (`/chrome-cdp`; never relaunches or kills your main Chrome — separate persistent profile, stopped by SIGTERM to its own PID), logs in with a recorded test account, and drives the real business flow. The agent picks the browser tool per task — Chrome MCP for exploratory, Playwright `connectOverCDP` for repeatable — and the login is whatever the project actually uses (not hardcoded to any provider). Real browser only; a green backend `/healthz` is not proof the user can log in.

Test accounts live in a **gitignored, `chmod 600`** `.harness/test-accounts.json` per repo (`scripts/harness-test-accounts.sh`). The `e2e-browser` skill proactively asks you to record a batch the first time, then reuses them. Plaintext credentials never leave your machine and are never committed.

Typical chain: `/wt-start` → `/verify` → `/e2e` → `/review-loop`.

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

A convergence-driven cross-model review of the current diff — the discipline of a heavy harness without its orchestration weight. `/review-loop` collects everything in one shot via `scripts/review-context.sh` (scope auto-detection: local-diff → branch → PR, plus peer availability — no multi-call context gathering), sends it to one peer (codex MCP or `gemini`/`claude` CLI), applies only the findings you accept, and **iterates until the peer has no new findings** (multi-round for stability; default max 5, escalate a finding debated 2 rounds). Rejecting a material finding requires a **Verification block** (command + output) — authority-only rejections are downgraded to "deferred." The anti-drift guard is a per-round re-check against the meta-goal, not a low round cap: review loops bias toward *adding constraints*, so the number of rounds isn't the enemy — unchecked rigor-creep is. **Rigor ≠ right.**

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
