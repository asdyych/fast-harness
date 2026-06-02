# Design: review-loop shell peer + per-session ledger + summary

Status: **draft for review** · 2026-06-01

## Goal

Bring three capabilities into fast-harness's lean review-loop, without recreating stone16's ~580-line script machinery:

1. **Shell-CLI peer path** — invoke the peer reviewer via the `codex` / `gemini` / `claude` CLI, in addition to the existing agent-driven codex MCP path. Both are first-class; the agent picks per situation.
2. **Per-session ledger** — a gitignored `.review-loop/<session>/` that records each round's findings + verdicts, so the loop's own process is recorded and reviewable. **Not committed** — it's a local process trace for retrospection.
3. **Summary artifact** — a human-readable `summary.md` written at loop end (the traceable record, aligning with the "leave traceable docs / audit matters" rule).

Stays lean: the agent still orchestrates the loop; the scripts do mechanics (peer invocation, dir/gitignore/summary). No codex session-resume / CODEX_HOME isolation, no strict JSON schema validation, no fire-and-forget autonomy.

## Components

### 1. `scripts/harness-review-peer.sh` — shell peer invocation

```
harness-review-peer.sh --peer codex|gemini|claude --prompt-file <f> [--timeout N]
```

- **codex** (verified CLI shape from stone16): `codex exec` reading the prompt from stdin, capturing the final message — run **read-only** (review = analysis, no writes). Exact sandbox/output flags confirmed against `codex exec --help` at implementation time (e.g. `--output-last-message <out>`, a read-only sandbox flag). Install hint on miss: `npm i -g @openai/codex`.
- **gemini**: `gemini -p "$(cat <prompt>)"`.
- **claude**: `claude -p` (headless print) reading the prompt.
- Auto-fallback codex→gemini→claude if the requested CLI is absent; clear error if none. Wraps with a timeout when `timeout`/`gtimeout` exists. Prints the peer's review text to stdout.

This is the "shell-call codex" path the agent can use when it wants a scriptable/repeatable invocation, or in a host without the codex MCP tool. The codex **MCP tool** remains the preferred path inside Claude Code (in-process, no extra auth).

### 2. `scripts/harness-review-session.sh` — ledger + summary mechanics

```
harness-review-session.sh init   [--peer X] [--scope S] [--base B] [--head H]   # → prints SESSION_DIR
harness-review-session.sh summary --session <dir>                               # → writes summary.md
harness-review-session.sh path                                                  # → prints .review-loop/latest
```

- `init`: create `.review-loop/<YYYY-MM-DD-HHMMSS-scope>/`, write `meta.json` (session id, peer, scope, base, head, started_at, status=in_progress), ensure `.review-loop/` is in the repo's `.gitignore` (fail loudly if it can't be — must never be committed), and point `.review-loop/latest` at it.
- **Rounds** are written by the **agent** as `round-NN.json` files in the session dir (the agent is the verifier/recorder — MVP tooling, the script doesn't over-model the schema). Each round file: `{ round, peer_findings:[{title,severity,file,line}], host_actions:[{finding, decision: accept|reject|deferred, verification?}], new_findings }`.
- `summary`: read `meta.json` + all `round-*.json`, render `summary.md` — scope/peer/base→head, a per-round table of findings + verdicts, escalated items, and the final status (consensus / max-rounds / escalated). Flip `meta.json` status to done.

### 3. `skills/review-loop/SKILL.md` — document the two peer modes + ledger + summary

- **Peer invocation, two modes:** (a) **codex MCP tool** — preferred in Claude Code, in-process; (b) **shell CLI** via `harness-review-peer.sh` — scriptable/repeatable, or for hosts without the MCP tool. Either satisfies the "send to one peer" step.
- **At loop start:** `harness-review-session.sh init` → get the session dir.
- **Each round:** after triaging the peer's findings, write `round-NN.json` to the session dir (findings + accept/reject/deferred verdicts, with the Verification block for rejects).
- **At loop end:** `harness-review-session.sh summary` → `summary.md`. Report its path. The `.review-loop/<session>/` dir is the gitignored process trace for later retrospection.

### 4. `commands/review-loop.md`

Mention the ledger + summary in one line.

## File-system layout (in the consuming repo, gitignored)

```
.review-loop/
├── latest -> 2026-06-01-143012-local-diff
└── 2026-06-01-143012-local-diff/
    ├── meta.json
    ├── round-01.json
    ├── round-02.json
    └── summary.md
```

## Security / cleanliness

`.review-loop/` is gitignored (enforced by `init`, fail-loud on inability) — process traces never get committed. No credentials involved. Both new scripts are POSIX-bash, cross-platform (timeout via `timeout`/`gtimeout` optional; no macOS-only assumptions).

## Deliberately NOT in scope

- codex session resume / `CODEX_HOME` isolation / API-key juggling (stone16's complexity).
- Strict JSON-schema validation of round files (the agent writes them; keep it forgiving).
- Autonomous fire-and-forget loops — the agent stays in the loop and reports inline as today; the ledger/summary are additive.
- Committing the ledger (it's a local trace, gitignored by design).

## Resolved decisions

| Question | Decision |
|---|---|
| Shell peer | Add `harness-review-peer.sh` (codex/gemini/claude CLI); MCP tool stays preferred in Claude Code |
| Ledger | `.review-loop/<session>/` gitignored; round-NN.json written by the agent; **not committed** |
| Summary | `summary.md` rendered by `harness-review-session.sh summary` at loop end |
| Leanness | scripts do mechanics; agent orchestrates; no stone16 session/CODEX_HOME machinery |
