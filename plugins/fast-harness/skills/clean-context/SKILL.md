---
name: clean-context
description: |
  Keep the main agent's context clean by dispatching independent units of work to
  FRESH sub-agents — exploration, broad searches, large file reads, a self-
  contained subtask, or a review pass. The sub-agent does the work in its own
  context and returns only the conclusion. Use when a task would otherwise dump a
  lot of intermediate material into the main thread, when work is independent and
  parallelizable, or when you catch yourself about to read many files just to
  extract one answer.
---

# Clean context via fresh sub-agents

A long-running main agent accumulates noise: file dumps, dead-end searches,
verbose tool output. That noise crowds out the reasoning that matters and drifts
behavior. The fix is **context hygiene**: push self-contained work into a fresh
sub-agent whose context starts clean, and keep only its conclusion in the main
thread.

## When to spin a fresh sub-agent

- **Fan-out search / exploration** — "where is X handled", "which files match
  this pattern". You want the conclusion, not the file-by-file trail.
- **Large reads to extract a small answer** — reading several big files to learn
  one fact. The sub-agent reads; you keep the fact.
- **An independent subtask** — a self-contained unit with clear inputs and a
  clear deliverable, no shared mutable state with the main thread.
- **A review / verification pass** — let a fresh agent (clean of the
  implementation context that might bias it) judge the result.
- **Parallelizable work** — 2+ independent units; dispatch them together.

## When NOT to

- The work is small and its output is the point (don't add a round-trip to save
  nothing).
- The work needs the main thread's accumulated context to make sense — a sub-
  agent starting clean would lack what it needs.
- It mutates shared state that another in-flight unit also touches.

## How

- Use the `Agent` tool with a focused prompt and, when it fits, a specific
  `subagent_type` (e.g. `Explore` for searches, `code-reviewer` for review).
- Give it everything it needs up front (it has no memory of this conversation)
  and tell it to return **only the conclusion / structured result**, not the
  trail.
- For independent units, dispatch them in one batch so they run concurrently.
- Treat the sub-agent's final message as data: extract what matters into the main
  thread; don't paste the whole transcript back.

Fresh context per unit of work is the same anti-drift principle behind chaptering
a session — reset the eigenbehavior before it accumulates noise.
