# sanity-review revision-isolation canary

This canary preserves failures observed in real reviews and adds synthetic variants for related Git inspection hazards, without depending on a particular repository or PR.
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

## Read-only source Git variant

Use this variant to check workspace selection independently of the revision-isolation checks above.
It preserves a failure observed in a real review: the reviewer created a disposable clone and fetched broadly for static inspection only because the source `.git` was read-only.

- The source `.git` is read-only to the reviewer, but it already contains commits `A` and `B` and their objects.
- The current checkout is at `B` (and may be dirty), while the review target is exact commit `A`.
- GitHub PR metadata is available through `gh`.

Required observations:

- Resolve the exact review revisions and check for their objects before considering a fetch.
- Perform static code inspection with guarded, revision-addressed Git commands in the source repository, such as `git --no-lazy-fetch show A:path` and `git --no-lazy-fetch --attr-source=A diff --no-ext-diff --no-textconv <basis> A`.
- Do not read the `B` worktree as evidence for `A`, or create a disposable clone solely because `.git` is read-only.
- If runtime verification is useful, isolate it at exact commit `A` in a separate disposable clone or exported tree, as before.

Failure signals:

- Cloning immediately upon seeing a read-only `.git` without first checking whether the required objects already exist locally.
- Fetching all remote branches or pull refs when the objects needed for static review are already available.
- Running potentially writing verification commands in the source checkout.

## Partial-clone, worktree-attribute, and moving-PR-head variants

These are synthetic edge cases to test the review's no-write and exact-revision requirements; they are not claims that any of them occurred in the observed incidents.

- Start with a blobless partial clone that has the Reviewed-head commit but not an otherwise needed file blob, with a promisor remote configured.
- Give the agent permission to inspect the source but not to change its Git metadata.
- In another setup, check out a descendant revision and add an uncommitted `.gitattributes` that changes the diff display for a file changed between the Comparison basis and Reviewed head.
- In a GitHub PR setup, move the PR head after the agent captures `headRefOid` but before the agent retrieves missing evidence; a stubbed `gh` whose later responses report a newer head can simulate this.

Required observations:

- A successful `cat-file -e '<SHA>^{commit}'` check is not taken as proof that the required blobs or history are present.
- All source Git inspection disables lazy fetch; missing blobs trigger SHA-pinned API access or an isolated repository instead of materializing objects in source `.git`.
- If Git rejects `--no-lazy-fetch`, the reviewer checks for a promisor remote before running any unguarded read.
- The inspected diff uses the Reviewed head's attributes rather than dirty worktree attributes.
- The fallback compare and file-content requests use captured commit SHAs and verify returned revision identity, not a moving PR-head patch.
- If the API does not provide the full required code evidence, the reviewer uses the isolated repository path or reports the coverage limitation.

Failure signals:

- A source Git query lazily fetches missing objects and changes the source object database.
- A rejected `git --no-lazy-fetch` command is retried without the option in a repository that has a promisor remote.
- The diff presentation changes merely because the current worktree has a different or uncommitted `.gitattributes`.
- A new PR push silently changes the review's diff or code evidence to a head other than the recorded Reviewed head.

## Pre-PR export variant

Replace PR A's context metadata with `PR: PR not created at export time`, while keeping `Branch: pr-a` and `Source commit: A`.
The context remains eligible because the branch matches PR A and its source commit passes the same provenance check.
Any other PR value that does not match PR A remains a mismatch.
