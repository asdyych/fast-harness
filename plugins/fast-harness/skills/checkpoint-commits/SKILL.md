---
name: checkpoint-commits
description: |
  Keep implementation work recoverable with small, verified local commits.
  Use whenever writing code or fixing bugs across multiple meaningful steps,
  including work driven by Matt Pocock's implement or TDD skills.
---

# Checkpoint commits

Create local commits throughout implementation so completed work is easy to
recover, review, bisect, and revert. This policy refines Matt Pocock's
`implement` instruction to commit the work: do not wait until the entire task is
finished when an earlier coherent milestone is already verified.

## Authorization boundary

- Coding and bug-fix tasks authorize local commits on the current branch by
  default. Do not stop after every milestone to ask again.
- A user instruction or repository rule that says not to commit takes
  precedence. Do not commit in a repository that explicitly requires a clean
  uncommitted handoff.
- During an active `harness-workflow`, the main agent ordinary-pushes every
  reviewed checkpoint. A delegated subagent may commit only in its
  coordinator-granted serialized commit window and never pushes.
- Outside `harness-workflow`, never push or open a pull request without explicit
  user authorization.
- Never amend, rebase, squash, reset, force-push, or otherwise rewrite history
  without explicit user authorization.

## Checkpoint protocol

1. Before editing, inspect `git status` and preserve all pre-existing changes as
   user-owned work.
2. Choose the smallest coherent behavior slice that can be understood and
   reverted independently. A test plus its implementation is usually one
   slice; unrelated cleanup is another.
3. Implement the slice and run the narrowest relevant test, typecheck, lint, or
   build command. A checkpoint must be buildable and must not knowingly leave
   the verified surface failing.
4. Inspect `git status` and the diff again. Stage only files or hunks belonging
   to the current slice. Never absorb, revert, or overwrite unrelated changes.
   If task changes and user changes are inseparable, stop and ask rather than
   claiming ownership of both.
5. Commit with a message that describes the behavior or invariant established.
   Do not use `WIP`, `checkpoint`, or vague progress messages.
6. During `harness-workflow`, the main agent immediately ordinary-pushes each
   reviewed checkpoint. A delegated subagent stops after returning its commit
   SHA and evidence. If the branch has no upstream and `origin` exists, use
   `git push -u origin <current-branch>`. A failed push does not erase the local
   commit: record it as pending, continue only work that remains safe, and never
   resolve rejection with force-push or automatic history rewriting.
7. Repeat before switching subsystems, starting a risky refactor or migration,
   or allowing another large independently useful diff to accumulate.

A genuinely small, single-step task may use one final commit. A large task
should normally produce several commits, but commit boundaries follow verified
behavior rather than line counts or elapsed time.

## Completion

Run the task's directly relevant final verification after the final slice.
Report the local commits created, checks run, remaining uncommitted changes,
and the push state of each commit.
