---
name: conversation-context-export
description: >-
  Export conversation context for handoff: save the goal, intent, design decisions,
  and constraints to `.dev/contexts/`, and share via a PR comment when requested or
  already authorized for this export.
  Use when the user says "export the context",
  "write out the conversation context", or "save what we discussed to .dev".
compatibility: >-
  Requires git on PATH.
  GitHub PR lookup and sharing additionally require the authenticated gh CLI (https://cli.github.com).
  Local-only export does not require gh or GitHub access.
---

# Conversation context export

Save context for the next session or reviewer at `.dev/contexts/{sanitized branch name}.md` in the selected worktree.
Use [TEMPLATE.md](TEMPLATE.md) for the record structure.

## Requested scope

A general request to "export the context" or "save to .dev" defaults to local saving.
Share via a PR comment when the user requests it or has already authorized that sharing for this export in the conversation; do not ask for the same permission again.
An explicit local-only instruction limits the export to local saving.
The existence or creation of a PR alone does not authorize posting conversation context.
Ask only when information needed to identify the destination or sharing scope is missing.

`.dev/contexts/` is an uncommitted working-tree scratch area for per-branch context, the **ephemeral tier**.
Do not `git add` `.dev/`.
If the user wants it ignored, use their global gitignore rather than changing the repository's ignore policy for this artifact.
PR comments are the sharing channel when sharing is authorized; a local save alone remains available in that worktree.
Route findings that need to survive the branch per "Related skills" below.

## Select the worktree and metadata

Honor an explicitly requested destination, including another worktree, within the host's filesystem permissions.
Otherwise use the Git worktree containing the host-provided session workspace root, rather than a shell's incidental current directory.
Resolve the selected path to its Git root and use that `{worktree root}` for all file paths and Git/gh operations:

```bash
git -C "{selected path}" rev-parse --show-toplevel
git -C "{worktree root}" branch --show-current
git -C "{worktree root}" rev-parse HEAD
```

For an explicit file destination, resolve its containing worktree from an existing parent directory.
Do not silently choose a sibling worktree, switch branches, or change Git state to make a destination fit.
If the destination is not in a Git worktree or the branch cannot be identified, resolve the missing target information with the user.
Use the selected worktree as the subject of the record: check relevant local files before describing implementation facts, and do not relabel facts from another branch as facts about this one.
If the conversation and destination appear to refer to different work, clarify the intended subject.
A different worktree alone is no reason to require a different session; obtain any host-required write approval through the normal permission mechanism.

Use the selected branch in the heading and `Branch`, its HEAD in `Source commit`, and the current datetime (`YYYY-MM-DD HH:mm:ss`) in `Updated at`.
Check the selected worktree's status and identify uncommitted work under remaining work, including its implementation and verification status, so `Source commit` is not presented as containing it.
Keep branch and HEAD consistent through saving and posting; if they change, recheck the target and refresh the record before proceeding.

### Filename convention

Replace each of these characters in the branch name with `-`, matching `conversation-context-import`:

```
/ \ : * ? " < > |
```

Example: `dependabot/npm_and_yarn/feed-5.2.0` → `dependabot-npm_and_yarn-feed-5.2.0`

Use `{worktree root}/.dev/contexts/{sanitized branch name}.md` by default.
If the user explicitly chooses a different filename, honor it and report that local discovery by `conversation-context-import` and `sanity-review` uses the conventional filename; supply the chosen file explicitly when using it with either skill.
Before updating an existing file, verify its heading and branch metadata refer to the intended branch; sanitization can map different branch names to the same filename.
Do not overwrite another branch's record on a filename collision; resolve a distinct destination.

### PR metadata and lookup failures

For local-only saving, do not require PR detection or GitHub authentication.
If the target PR is already reliably known from the conversation, record it after checking that it belongs to the selected target.
Otherwise use `PR not checked at export time`; do not infer that no PR exists.

When sharing or a request for PR metadata requires lookup, run `gh` from `{worktree root}`.
For example, `gh pr view --json number,url,headRefName,headRefOid,headRepository,headRepositoryOwner` supplies the PR identity and head information.
Verify the repository and head branch match the selected worktree and that `Source commit` is the PR head or an ancestor of it before posting.
If local commits are not included in the PR, save locally and report the mismatch; do not push commits as part of export.

Distinguish these PR field values:

- `#{number}`: the target PR was identified and checked.
- `PR not created at export time`: absence of a matching PR was confirmed.
- `PR not checked at export time`: no lookup was needed or performed.
- `PR unverified at export time`: lookup failed and PR existence or identity remains unknown.

An error from `gh pr view` alone does not establish PR absence.
Use an explicit no-match response or a successful query with no matching PR to establish absence.
For connection, authentication, permission, or other retrieval failures, report the observed reason without declaring credentials invalid from the error alone.
Retry through a permitted execution path when an environment restriction may explain the failure, without changing credentials or configuration.
If lookup remains unavailable, complete independent local saving and leave requested sharing pending.
Record the failure reason and incomplete sharing under remaining work, and report them to the user.
Do not create a PR merely to make export possible.

## Save the context

Read any existing destination file before writing it.
Apply the existing-record rules below, then write using the template and create the parent directory if necessary.
Include suggested skills with a one-line reason when useful for the next worker; otherwise omit that section.

Keep goals, decisions, rejected alternatives and their reasons, constraints, and remaining work that the next worker cannot recover from the code alone.
Distinguish verified implementation behavior from assumptions and unverified work.
Avoid repeating code inventories or process anecdotes.
Do not include secrets or personal information, even in a local-only record.

For a local-only export, report the saved path and state that PR comments were not updated and any previously shared context may now be stale.
Point to the saved file as explicit input when the latest context is needed for review.
This notice does not require checking whether a PR or an earlier comment exists.

### Existing-record rules

- For a record created in this conversation, regenerate from the full conversation and current understanding.
- For another session's record, preserve prior findings and append new information.
  Correct or delete a finding only after verifying that it is wrong; inference alone is insufficient.
  Misclassified content may move between sections without being lost.
  Ask only about unresolved changes in intent, approach, or scope; an explicit user decision need not be reconfirmed.
- Keep the resulting record current, without strikethroughs or a running change log.
  `.dev/` is not committed, so do not rely on Git history to recover overwritten findings.

### Decisions recorded in ADRs

Preserve the existing division of recording responsibilities.
When a decision has been recorded in an ADR (`domain-modeling`), retain a one-line summary and a link to that ADR in this context.
Keep the grounds and alternatives that explain that architectural decision in the ADR; other rejected alternatives remain here.
If ADR recording is also entrusted to you, use `domain-modeling` within that scope; an export request alone does not require creating ADRs or glossary entries.
The link lets the reviewer follow the design intent beyond the ephemeral record.

## Share via a PR comment

Run this section only when sharing is requested or already authorized and the target PR is verified.
If the PR is confirmed absent, keep the local save and report that sharing could not be completed because no matching PR exists.
If the PR is unverified, report the lookup failure and pending sharing separately from confirmed absence.

Read the saved file and check for secrets or personal information before posting.
Resolve the repository and authenticated GitHub user from the selected worktree, then inspect the target PR's comments (including all pages).
Match the complete first heading line `# {branch name} 対話コンテキスト`, using the unsanitized branch name, rather than a substring elsewhere in the body.

Prefer the latest matching comment by the authenticated user.
Read its body and apply the same existing-record rules as for a local file, preserving another session's findings before an update.
If this requires merging additional findings, update the local record too so the posted content matches it.
Do not edit another user's comment or an unrelated comment.
If there is no matching comment of your own, create a separate comment within the authorized sharing scope without asking for the same sharing permission again.
If the request specifically requires updating a comment you cannot edit, clarify that limitation instead of silently substituting a new post.

Use file-based bodies to avoid shell escaping problems:

```bash
# Run from {worktree root}; {context file} is the resolved local destination.
gh pr comment {PR number} --repo {owner}/{repo} --body-file "{context file}"
# To update a verified matching comment owned by the authenticated user:
gh api repos/{owner}/{repo}/issues/comments/{comment ID} --method PATCH -F "body=@{context file}"
```

If posting fails, retain the local record, note the failure and pending sharing under remaining work, and report sharing as incomplete.
Report the saved path and, if shared successfully, the PR comment URL.
Distinguish local-only completion, confirmed PR absence, and failed or unverified sharing; do not report a post as complete without a successful result.

## Related skills

- **conversation-context-import**: load saved context to continue development or review.
- **sanity-review**: use conversation context and linked ADRs to review implementation intent.
- **durable-knowledge-export**: save or update knowledge beyond the branch when that recording is entrusted; routing does not add permission for another destination or publication.
- **domain-modeling**: this codebase's glossary and architectural decisions, committed with the code; link to its ADRs from this ephemeral record.
