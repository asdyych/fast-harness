---
description: Propose the next loop action without executing it
---

Use the `loop` skill. Inspect the current SDD session and propose the next
smallest action tied to one checkpoint acceptance criterion.

Read:

- `docs/specs/<change-id>/spec.md`
- `docs/specs/<change-id>/design.md`
- `docs/specs/<change-id>/tasks.md`
- `.harness/<change-id>/manifest.json`
- `.harness/<change-id>/state.md`
- `.harness/<change-id>/checkpoints.md`
- recent files under `.harness/<change-id>/evidence/`

Return the proposed next action, expected evidence, and stop/escalation risks.
Do not modify files or execute the action until the user confirms.
