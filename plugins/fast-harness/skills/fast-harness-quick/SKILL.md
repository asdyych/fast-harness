---
name: fast-harness-quick
description: |
  Run the quick recoverable harness implementation route. Use when invoked as
  /fast-harness-quick or when the user asks for that exact entry point. Delegates
  to harness-workflow quick mode: direct implement, code-review, mandatory
  cross-review, verification, and checkpoint commit/push without spec or tickets.
---

# Fast harness quick

Use the sibling `harness-workflow` skill in **quick mode**. Treat the remaining
user text as the implementation goal, not as routing arguments. Do not let words
such as `full` inside the goal change the selected mode.

The command invocation confirms the route and authorizes the workflow's ordinary
checkpoint pushes. Follow every preflight, persistence, review, and completion
gate in `harness-workflow` without omission.
