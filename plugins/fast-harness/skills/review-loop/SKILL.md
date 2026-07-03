---
name: review-loop
description: |
  Multi-round cross-LLM review loop — send the current diff/PR to one peer
  reviewer (Codex via the codex MCP tool, or Gemini/Claude CLI), apply only the
  findings you accept, and iterate until the peer has no new findings
  (convergence), bounded by a max round count. Keeps the loop stable without
  letting it drift toward over-constraint. Use for "review loop", "peer review",
  "cross review", "让 codex review 一下", "交叉 review", before merging a PR.
---

# Cross-LLM review-loop

A convergence-driven cross-model review of the current change. It runs as many
rounds as it takes for the peer to stop finding real issues — multi-round is how
you get *stability* — while a per-round meta-goal check stops it from drifting
into over-engineering. Output: improved code + a short consensus/escalation note.

## Protocol

1. **Lock the meta-goal, with the deletion rule.** Before round 1, write — in
   one sentence — what this change is actually supposed to achieve. This is the
   yardstick for every finding. Apply the **deletion rule**: *if a modification
   can be removed without hurting the meta-goal, it should not exist.* Tell the
   peer: *prefer fewer constraints; accept correctness/security/data-loss fixes;
   reject "add more schema/checks/tests to raise rigor" unless it fixes a real
   defect.*

2. **Preflight in one shot:**
   ```bash
   HARNESS_PLUGIN_ROOT="${CODEX_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
   if [ -z "$HARNESS_PLUGIN_ROOT" ]; then
     echo "Set HARNESS_PLUGIN_ROOT to the installed fast-harness plugin root." >&2
     exit 2
   fi
   "${HARNESS_PLUGIN_ROOT}/scripts/review-context.sh" [--scope auto|diff|branch|pr]
   ```
   In Claude Code, `CLAUDE_PLUGIN_ROOT` is available. In Codex, use
   `CODEX_PLUGIN_ROOT` if the host provides it; otherwise derive the plugin root
   from this `SKILL.md` source path (two directories above this skill directory)
   and substitute that absolute path.

   One call returns scope, base, changed files, the diff, and which peer is
   available — no multi-call context gathering.

3. **Send to ONE peer.** Prefer the codex MCP tool (`mcp__codex__codex`,
   `sandbox: read-only`) when available. For any shell CLI peer, use the
   deterministic wrapper rather than hand-running `codex`, `gemini`, or
   `claude`:
   ```bash
   "${HARNESS_PLUGIN_ROOT}/scripts/harness-review-peer.sh" \
     --peer "<codex|gemini|claude>" \
     --prompt-file "<round prompt file>" \
     --timeout 600 \
     --log-dir ".review-loop/<session-id>/peer-round-01"
   ```
   The wrapper prints the peer's final review text to stdout and writes
   diagnostics under the log dir. Claude runs in `--bare` stream-json mode by
   default to avoid SessionStart hooks, MCP startup, plugin sync, auto-memory,
   and CLAUDE.md auto-discovery from consuming the review timeout. If a machine
   cannot use `--bare`, set `HARNESS_REVIEW_PEER_CLAUDE_MODE=safe-mode`; if
   debugging a no-output hang, set `HARNESS_REVIEW_PEER_INCLUDE_PARTIALS=1`.
   Ask for correctness bugs first, then simplifications — each with `file:line`
   and a severity. Pass the meta-goal from step 1.

4. **Triage — you decide, not the peer. Rejection needs evidence.** Apply only
   findings you accept. To **reject** a material finding (correctness, security,
   data-loss), attach a **Verification block** — the actual command you ran and
   its output proving the code is correct. A rejection that cites only the spec,
   a convention, or "I disagree" with **no verification output** is not a
   rejection — downgrade it to *deferred for verification* and surface it in the
   final note. (Style / "add rigor" findings can be rejected with a one-line
   reason; this evidence bar is for material findings only.)

5. **Apply accepted fixes, then re-review. Iterate to convergence.** After each
   round of fixes, run the peer again on the updated workspace. **Stop when the
   peer returns no new findings** (consensus). Multi-round is expected and good
   — it's what makes the result stable. Bound it: **default max 5 rounds**; if a
   single finding is debated **2 exchanges without resolution → escalate it**
   (don't keep arguing).

6. **Each round, re-check against the meta-goal — this is the anti-drift guard.**
   Ask: *is this round's work solving the original goal, or solving complexity I
   introduced last round?* The number of rounds is not the enemy — unchecked
   constraint-adding is. The meta-goal check is what lets you run many rounds
   safely.

7. **Before declaring done, name ≥1 command-checkable acceptance criterion** for
   any non-trivial change (e.g. `tsc --noEmit` clean, a specific test passes) and
   confirm it — don't ship on "looks right."

8. **Final note.** Either *consensus* (peer satisfied, criterion met) or an
   **Escalated Items** list: for each unresolved finding, the host position, the
   peer position, and the missing verification — for a human to decide.

## The discipline this skill enforces

Cross-LLM review loops have a structural bias: **resolving a finding almost
always means adding a constraint** (a schema field, a check, a guard, a test).
Run long enough *without a guard* and "self-consistent" drifts from "right" — a
"reduce templating" change can come out as "more templates, each stricter." The
fix is not fewer rounds; it's the per-round meta-goal check plus:

- **Rigor ≠ right.** Self-consistent is not correct-for-the-goal.
- **Down-weight "critical".** A peer's "critical" is usually an
  implementation-detail / schema contradiction; a wrong *direction* rarely gets
  flagged critical, because the peer reviews the design's consistency, not its
  premise.
- **Priority: simplicity > observability > rigor.** At MVP altitude, prefer a
  coarse mechanism whose failure is visible and revertible over a dense one whose
  failure hides inside many constraints.
- **Converge, don't grind.** Stop when the peer has no new findings; escalate a
  stalemate rather than adding constraints to "win" it.
