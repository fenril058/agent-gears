---
name: pull-request-description
description: >-
  Write or revise the body of a pull request (the PR description). Use when opening a PR,
  drafting, editing, or updating its body, or reviewing a body before it is posted. Keep
  the body to what the diff cannot show — purpose, design decisions, acceptance criteria,
  review context — and keep out inventory the diff, commits, test code, and CI results
  already state.
---

# Pull request description

A PR body is read alongside the diff, never instead of it.
Whatever the reviewer can confirm by opening the diff, the commits, the test code, or the CI result is not worth transcribing: it spends the reviewer's attention on what they already have, and it goes stale on the next push.
Write what the diff cannot answer.

## Write, in this priority order

1. The problem this change solves, and why it is worth solving now.
2. The approach taken, and the alternatives rejected with the reason for rejecting each.
3. Design decisions a reader would otherwise have to reverse-engineer from the diff.
4. Acceptance criteria: what must hold for the change to be correct, and how that was confirmed.
5. Context the review needs: scope boundaries, known limitations, follow-up work, risk and rollback, where to look first.

## Don't transcribe

- Counts and listings the diff already gives: commit count, changed-file count, file-by-file lists, line counts, test counts.
- A restatement of the implementation — a walkthrough of what each file or function now does.
- Version numbers, test names, and CI job status that the commit or the CI page already shows.

Such facts belong in the body only when they carry an argument: a before/after comparison, an acceptance criterion, or the basis of a decision.
"3 queries per request down to 1" is a measurement; "12 files changed" is not.

## Check before posting

For each line ask: **can the reviewer get this from the diff, the commits, the test code, or the CI result?**
If yes, delete it, unless it is a comparison, an acceptance criterion, or the reason for a decision.
If deleting leaves the body saying nothing the diff does not, the PR needs a stated reason for the change, not a longer body.
