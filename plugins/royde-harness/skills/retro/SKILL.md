---
name: retro
description: |
  Lightweight retrospective to improve THIS harness plugin itself, with a paper
  trail. When friction shows up using the harness (a guard false-positive, a
  worktree-dev gap, a review-loop rule that misfired, a missing skill), reflect on
  the pattern, OPEN A GITHUB ISSUE on the plugin repo so it is tracked, and draft
  a ready-to-paste fix. Use when the user asks to "retro", "复盘一下", "优化
  harness/plugin", or proactively when the SAME friction shows up 3+ times. No
  state machine, no per-task files — traceable issues + concrete proposals.
---

# Retro — improve the harness itself, on the record

A self-improvement loop for the `royde-harness` plugin. It does not review project
code; it notices where the harness *itself* helped or got in the way and turns
that into a **tracked GitHub issue** plus a concrete edit to the plugin's files —
so every finding is auditable, not a one-off comment that scrolls away.

## When to run it

- The user invokes `/retro`, or
- You notice the **same friction 3+ times**. One incident is an observation;
  **3+ is a pattern worth filing.** Don't run it for one-offs or to look busy.

## Protocol

1. **Gather the evidence.** Which harness component was involved? What happened,
   concretely (command, expected vs actual)? How many times — this session or
   across recent ones? Be honest about frequency; if it's below 3 and the user
   didn't invoke it, stop and say so.

2. **Attribute the pattern.**
   - **Plugin defect** → a guard regex over/under-matches, a script bug, a wrong
     or missing skill instruction. Fix lives in the plugin.
   - **Usage gap** → a workflow done repeatedly by hand that deserves a skill /
     script / command.
   - **Out of scope** → personal config (rules/settings/memory) belonging in the
     user's own `~/.claude`, not the shareable plugin. Note it; do **not** file a
     plugin issue for it.

3. **Open a tracking issue** for each actionable (defect / gap) proposal — this
   is the audit trail. Target repo defaults to the plugin's own; override with
   `HARNESS_RETRO_REPO`:

   ```bash
   REPO="${HARNESS_RETRO_REPO:-ch-royde/royde-harness}"
   gh label create retro --color BFD4F2 --description "harness self-retro" 2>/dev/null || true
   gh issue create --repo "$REPO" --label retro \
     --title "retro: <short pattern>" \
     --body "$(cat <<'BODY'
   ## Pattern
   <one line — observed N times, this session / across sessions>

   ## Component
   <hooks/destructive_guard.sh | skills/<x> | scripts/<y> | new skill>

   ## Classification / Severity
   plugin-defect | usage-gap  ·  high | medium | low

   ## Proposed change (ready to paste)
   <exact edit — the regex line, the skill section, the script flag>

   ## Considered & rejected
   <unsafe/over-engineered alternative + why, if any>
   BODY
   )"
   ```

   Keep titles greppable (prefix `retro:`). One issue per real pattern — don't
   split a single pattern across issues or file duplicates (search first:
   `gh issue list --repo "$REPO" --label retro --search "<keyword>"`).

4. **Apply on approval, then close the loop.** With the user's go-ahead, apply
   the change (directly or via a PR that says `Closes #<n>`), verify it (e.g.
   re-run the guard's test matrix if a guard pattern changed), and let the merge
   close the issue. If not applying now, leave the issue open as the record.

## Boundaries

- **Will:** find harness-usage patterns, file a tracked issue per real one, draft
  exact plugin edits, apply on approval, verify.
- **Will not:** invent a state machine or per-task ledger; edit the user's
  personal `~/.claude`; file issues for out-of-scope personal config; manufacture
  findings or file duplicates. Patterns over incidents — if there isn't a real
  pattern, say so and stop.
