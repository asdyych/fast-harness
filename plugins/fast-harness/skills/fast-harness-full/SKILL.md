---
name: fast-harness-full
description: |
  Run the full recoverable harness implementation route. Use when invoked as
  /fast-harness-full or when the user asks for that exact entry point. Delegates
  to harness-workflow full mode: to-spec, to-tickets, per-ticket implement,
  code-review, mandatory cross-review, verification, and checkpoint commit/push.
---

# Fast harness full

Use the sibling `harness-workflow` skill in **full mode**. Treat the remaining
user text as the implementation goal, not as routing arguments. Do not let words
such as `quick` inside the goal change the selected mode.

The command invocation confirms the route and authorizes the workflow's ordinary
checkpoint pushes. Follow every preflight, persistence, review, and completion
gate in `harness-workflow` without omission.
