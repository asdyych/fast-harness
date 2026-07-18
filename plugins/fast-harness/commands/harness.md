---
description: Run the full or quick Matt-based harness implementation workflow
---

Use the `harness-workflow` skill with `$ARGUMENTS`.

Choose full mode by default or when the arguments contain `full` or `完整`;
choose quick mode when they contain `quick`, `快速`, or `快速实现`. Full mode
runs Matt's `to-spec`, `to-tickets`, and per-ticket `implement`. Quick mode
starts at `implement`. Both modes require normal `code-review`, `cross-review`,
project verification, and automatic checkpoint commit plus ordinary push.
