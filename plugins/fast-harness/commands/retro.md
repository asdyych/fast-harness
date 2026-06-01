---
description: Retrospective on this harness plugin — find 3+ friction patterns, open a tracking GitHub issue per finding, draft ready-to-paste plugin edits
---

Use the `retro` skill to improve the `fast-harness` plugin itself, on the record.

Look at where the harness helped or got in the way recently. For each real
pattern (a guard false-positive, a worktree-dev gap, a review-loop rule that
misfired, a repeated manual workflow with no skill), classify it (plugin defect /
usage gap / out-of-scope personal config), **open a GitHub issue** (prefix
`retro:`, label `retro`, on `${HARNESS_RETRO_REPO:-ch-royde/fast-harness}`) with
a ready-to-paste fix in the body, then apply on approval and let the merge close
it. Search existing `retro`-labelled issues first to avoid duplicates. If there's
no real 3+ pattern and this wasn't user-invoked, say so and stop — don't
manufacture findings or file noise.

$ARGUMENTS
