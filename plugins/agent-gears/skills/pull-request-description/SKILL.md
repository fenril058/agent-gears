---
name: pull-request-description
description: >-
  Write, revise, or check the body of a pull request (the PR description).
  Use whenever a task creates or opens a PR, even if the request does not mention its body.
  Also use when drafting, editing, updating, reviewing, or checking a PR body. Open with a
  concise summary, then keep the rest of the body to what the diff cannot show — purpose,
  design decisions, acceptance criteria, review context — and keep out inventory the diff,
  commits, test code, and CI results already state.
---

# Pull request description

A PR body is read alongside the diff, never instead of it.
Open with a sentence or two on what the change does, enough to orient the reviewer.
Spend the rest on what the diff cannot answer, not on re-listing what the reviewer already has in front of them and what the next push will make stale.

## Write only what applies, in this priority order

1. The problem this change solves, and why it is worth solving now.
2. The approach taken, and — when alternatives were actually weighed — why the others were rejected.
3. Design decisions a reader would otherwise have to reverse-engineer from the diff.
4. Non-obvious acceptance criteria the reviewer cannot recover from the diff or the tests.
5. Context the review needs: scope boundaries, known limitations, follow-up work, risk and rollback, where to look first.

Do not create a section merely to cover this list.
A small change may need only the opening summary and a brief reason.
Never supply an item you did not actually have — an invented alternative or an after-the-fact rationale misleads the review.

## Don't transcribe

- Counts and listings the diff already gives: commit count, changed-file count, file-by-file lists, line counts, test counts.
- A restatement of the implementation — a walkthrough of what each file or function now does.
- Version numbers, test names, and CI job status that the commit or the CI page already shows.

Such facts belong in the body only when they carry an argument: a before/after comparison, an acceptance criterion, or the basis of a decision.
"3 queries per request down to 1" is a measurement; "12 files changed" is not.

## Check before posting

For each line ask: **is this an exhaustive listing, a count, or a walkthrough of what the diff, the commits, the test code, or the CI result already shows?**
If yes, delete it, unless it is a comparison, an acceptance criterion, or the reason for a decision.
The opening summary stays; the inventory behind it does not.
If deleting leaves the body saying nothing the diff does not, the PR needs a stated reason for the change, not a longer body.
When asked only to check a body, report what violates these rules and leave the rewrite to the author unless they ask for it.
