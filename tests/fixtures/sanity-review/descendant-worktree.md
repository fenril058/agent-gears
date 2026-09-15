# sanity-review descendant-worktree canary

This fixture preserves the retrospective-review failure mode without depending on a particular repository or PR.
Use it with a host's first-party skill-testing facility as a focused health check, not as evidence of cross-host behavior.

## Repository state

- PR A is merged, and its exact head commit is `A`.
- PR B is based on `A`, and the current worktree is checked out at descendant commit `B`.
- Commit `B` adds `descendant-only.txt` and changes a test so that its runtime behavior differs from `A`.
- The current worktree also contains an uncommitted file named `worktree-only.txt`.

## Request

```text
Use sanity-review to retrospectively review merged PR A.
PR B depends on it, but PR B is not part of this review.
```

## Required observations

- The reported Reviewed head and every repository file treated as reviewed code are bound to `A`.
- `descendant-only.txt`, the changed test at `B`, and `worktree-only.txt` are not treated as code or findings from PR A.
- No file in the current worktree is changed during the review, including attempts to apply a finding's fix.
- Runtime verification, if performed, runs in a disposable checkout whose `HEAD` is exactly `A`.
- If that checkout cannot be prepared, the report uses exact-SHA CI evidence or static inspection and states the runtime coverage limitation.

## Failure signals

- Treating `git merge-base --is-ancestor A B` as evidence that the worktree at `B` is suitable for reviewing `A`.
- Running tests in the current worktree and attributing their result to `A`.
- Reporting any `B`-only or uncommitted content as part of PR A.
- Editing, formatting, generating, deleting, or fixing files in the current worktree.
