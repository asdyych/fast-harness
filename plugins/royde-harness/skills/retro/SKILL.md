---
name: retro
description: |
  Lightweight retrospective to improve THIS harness plugin itself. When friction
  shows up using the harness (a guard false-positive, a worktree-dev gap, a
  review-loop rule that misfired, a missing skill), reflect on the pattern and
  draft a ready-to-paste edit to the plugin's own files. Use when the user asks
  to "retro", "复盘一下", "优化 harness/plugin", or proactively suggest it after
  the SAME friction shows up 3+ times. No state machine, no per-task files —
  guidance + concrete proposals only.
---

# Retro — improve the harness itself

This is a self-improvement loop for the `royde-harness` plugin. Its job is not to
review project code; it is to notice where the harness *itself* helped or got in
the way, and turn that into concrete edits to the plugin's files.

## When to run it

- The user invokes `/retro`, or
- You notice the **same friction 3+ times** — a `destructive_guard` false
  positive on a safe command, a `worktree-dev` step that always needs manual
  fixup, a `review-loop` rule that misfired, a recurring task with no skill for
  it. One incident is an observation; **3+ is a pattern worth acting on**.

Don't run it for one-off annoyances or to manufacture work.

## Protocol

1. **Gather the evidence.** What harness component was involved? What happened,
   concretely (command, expected vs actual)? How many times has this pattern
   shown up — this session or across recent ones?

2. **Attribute the pattern.** Classify each:
   - **Plugin defect** → a guard regex over/under-matches, a script bug, a skill
     instruction that's wrong or missing. Fix lives in the plugin.
   - **Usage gap** → a workflow done repeatedly by hand that deserves a skill /
     script / command.
   - **Out of scope** → personal config (rules/settings/memory) that belongs in
     the user's own `~/.claude`, not the shareable plugin. Note and move on.

3. **Draft a ready-to-paste proposal** per actionable pattern:
   ```
   ### Proposal: <title>
   - Component: <hooks/destructive_guard.sh | skills/<x> | scripts/<y> | new skill>
   - Pattern: <one line; how many times observed>
   - Severity: high | medium | low
   - Change: <exact edit — the regex line to add, the skill section to insert,
     the script flag to support>  (ready to apply, not "consider improving X")
   ```

4. **Confirm before editing.** Show the proposals; let the user approve which to
   apply. Apply only approved ones, then verify (e.g. re-run the guard test
   matrix if a guard pattern changed). Surface anything classified *out of scope*
   so the user can decide whether to add it to their own config.

## Boundaries

- **Will:** find harness-usage patterns, draft exact plugin edits, apply on
  approval, verify the change.
- **Will not:** invent a state machine or per-task ledger; edit the user's
  personal `~/.claude` rules/settings/memory; manufacture findings to look busy.
  Patterns over incidents — if there isn't a real 3+ pattern, say so and stop.
