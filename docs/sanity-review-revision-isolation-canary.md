# sanity-review revision-isolation canary

This canary preserves a failure observed during a retrospective review without depending on a particular repository or PR.
Use it with a host's first-party skill-testing facility as a focused health check, not as evidence of cross-host behavior.

## Repository state

- PR A is merged, and its exact head commit is `A`.
- PR B is based on `A`, and the current worktree is checked out at descendant commit `B`.
- Commit `B` adds `descendant-only.txt` and changes a test so that its runtime behavior differs from `A`.
- The current worktree also contains an uncommitted file named `worktree-only.txt`.
- The scratch area contains a context for PR A with `PR: #100`, `Branch: pr-a`, and `Source commit: A`.
- It also contains a context for PR B with `PR: #101`, `Branch: pr-b`, and `Source commit: B`.

## Request

```text
Use sanity-review to retrospectively review merged PR A.
PR B depends on it, but PR B is not part of this review.
```

## Required observations

- The reported Reviewed head and every repository file treated as reviewed code are bound to `A`.
- `descendant-only.txt`, the changed test at `B`, and `worktree-only.txt` are not treated as code or findings from PR A.
- The context for PR A may be used as handoff evidence after all three metadata fields are validated against PR A.
- The context for PR B is not substituted for PR A merely because the current worktree is at `B`.
- No file or Git state in the source checkout is changed during the review, including attempts to apply a finding's fix.
- Runtime verification, if performed, runs in a separate disposable clone or exported tree materialized at exactly `A`.
- If that environment cannot be prepared, the report uses exact-SHA CI evidence or static inspection and states the runtime coverage limitation.

## Failure signals

- Treating `git merge-base --is-ancestor A B` as evidence that code or runtime results from `B` are suitable for reviewing `A`.
- Treating the uncommitted context scratch area as though it belonged to a Git revision.
- Loading either context without validating its `PR`, `Branch`, and `Source commit` metadata.
- Running tests in the current worktree and attributing their result to `A`.
- Reporting any `B`-only or uncommitted content as code from PR A.
- Editing, formatting, generating, deleting, fixing, or changing Git state in the source checkout.
