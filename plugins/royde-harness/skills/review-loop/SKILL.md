---
name: review-loop
description: |
  Lean cross-LLM review loop — send the current diff/PR to one peer reviewer
  (Codex via the codex MCP tool, or Gemini CLI), apply only the findings you
  accept, re-review once if you changed something substantive, stop. No
  Planner/Generator/Evaluator ceremony. Use for "review loop", "peer review",
  "cross review", "让 codex review 一下", "交叉 review", before merging a PR.
---

# Lean review-loop

A two-round-max cross-model review of the current change. The output is improved
code plus a short consensus note — not a framework run.

## Protocol

1. **Lock the meta-goal first.** Before round 1, write down — in one sentence —
   what the change is actually supposed to achieve. This is the yardstick every
   finding is measured against. Tell the reviewer: *"prefer fewer constraints;
   accept correctness bug fixes; reject 'add more schema/checks/tests to raise
   rigor' findings unless they fix a real defect."* Give the peer a bias toward
   simplicity.

2. **Gather context:**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/review-context.sh" [base-ref]
   ```

3. **Send to ONE peer reviewer.** Prefer the codex MCP tool
   (`mcp__codex__codex`, `sandbox: read-only`); use the `gemini` CLI as the
   alternate. Ask for: correctness bugs first, then simplifications — each with
   `file:line` and a severity. Pass the meta-goal from step 1.

4. **Triage — you decide, not the reviewer.** Apply only findings you accept.
   For each finding ask: *is this solving the user's original goal, or solving
   complexity I introduced last round?* If the latter shows up twice, stop.

5. **Re-review once, only if you made substantive changes.** Max 2 rounds.

6. **Final re-check against the ORIGINAL goal**, not against self-consistency.
   Ask the peer: *"does the current diff actually solve <meta-goal>?"* — not
   *"is it internally consistent?"*

## The discipline this skill exists to enforce

Cross-LLM review loops have a structural bias: **resolving a finding almost
always means adding a constraint** (a schema field, a check, a guard, a test).
Run the loop long enough and the spec gets more "self-consistent" while drifting
away from the original intent — a "reduce templating" change can come out the
other end as "more templates, each stricter." Guard against it:

- **Rigor ≠ right.** Self-consistent is not the same as correct-for-the-goal.
- **Down-weight "critical".** A peer's "critical" is usually an
  implementation-detail / schema contradiction; a genuinely wrong *direction*
  rarely gets flagged critical, because the peer reviews the existing design's
  consistency, not its premise.
- **Priority: simplicity > observability > rigor.** At MVP altitude, prefer a
  coarse mechanism that might not work (failure is visible, easy to revert) over
  a dense one whose failure hides inside many constraints.
- **Cap at 2 rounds.** If round 3 would only add constraints with no behavior
  impact, you're done — stop and ship.
