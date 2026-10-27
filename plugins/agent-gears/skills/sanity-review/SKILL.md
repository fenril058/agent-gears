---
name: sanity-review
description: >-
  Review a PR or explicit commit range against its explanation and available
  conversation context, including the grounds for decisions and omissions.
  Use when asked for a sanity-review, a PR review report, or a review connecting
  implementation with conversation context and prior decisions.
argument-hint: "[PR-URL-or-number | review brief + Reviewed head + Comparison basis]"
compatibility: >-
  Requires git for local inspection; Git options vary by build (see below).
  GitHub PR reviews need authenticated GitHub read access through available tools
  or the gh CLI (https://cli.github.com).
---

# Sanity review

Use the change explanation and available implementation context to find unsupported premises, missed consequences, and defects in the actual change.
An exported context can expose rejected alternatives, failed attempts, and intentional non-actions that the diff does not show.
Treat these records as claims to investigate, not authority on what the code does or proof that a decision was sound.
Do not infer the implementer's understanding or authorship from the quality or apparent AI origin of prose.

An explicit invocation applies to dependency updates too.
Ordinary dependency-update reviews do not automatically require this skill or a particular built-in review command.

## Target and operation boundary

- Honor an explicitly named PR first.
  For an explicit non-PR range, require a review brief/change description, Reviewed head, and Comparison basis; resolve only missing inputs with the user before reviewing code.
  Do not replace an incomplete range request with the current branch's unrelated PR.
  With neither target specified, a PR associated with the current branch may supply the target; if none can be identified, ask for the target.
- **Reviewed head** is the exact commit whose code is reviewed.
  **Comparison basis** is the exact commit used as the start of the diff actually inspected.
  Resolve refs once and record both SHAs before inspecting code.
  For a PR, capture its head and base SHAs; determine the diff basis separately, usually their merge base, rather than assuming the base branch tip is the basis.
  If shallow history prevents this, use verified SHA-pinned comparison metadata or an isolated repository.
- Keep the source checkout and remote read-only: no fixes, formatting, generated files, index updates, branch switches, ref/history changes, fetching into source Git metadata, or external posts.
  Report recommended fixes in the conversation; saving or posting a report requires the user's instruction or existing authorization.
  Read-only source Git metadata does not itself require a clone.

## Evidence at the reviewed revision

The report's Reviewed head, diff head, reviewed repository files, and any runtime environment's source commit must agree.
A descendant containing that commit is a different revision.
Use guarded, revision-addressed source Git reads for static inspection when the required objects are available, even if the worktree is dirty or checked out elsewhere.
Use worktree files only after verifying its HEAD equals Reviewed head and there are no tracked or untracked changes.
Avoid optional index refresh during status checks, for example with `git --no-optional-locks status` on supporting builds.
Label older code as comparison evidence, not Reviewed-head code.
If revision identity cannot be established, report that blocker; do not present the work as a completed review of that commit.

Apply these guards before reading source Git objects (see the [Git options](https://git-scm.com/docs/git) and [partial-clone documentation](https://git-scm.com/docs/partial-clone)):

- Disable implicit lazy fetch on every source object/history read with `git --no-lazy-fetch`, including resolution, `show`, `diff`, `log`, and `merge-base`.
  A successful commit-object check does not establish that its trees/blobs or ancestry are present.
  Check `git --no-lazy-fetch rev-parse --is-shallow-repository` before relying on history; successful `log` output can still be incomplete.
- If the build rejects `--no-lazy-fetch`, do not retry unguarded until `git config --get-regexp '^(remote\..*\.promisor|extensions\.partialclone)$'` establishes that no promisor/partial-clone configuration is present.
  Distinguish the no-match exit status from an actual query failure.
  Otherwise use the fallback below.
  Do not substitute `GIT_NO_LAZY_FETCH=1` without verifying build support: unsupported builds may silently ignore it.
- For patches from `diff`, `show <commit>`, or `log -p`, select Reviewed-head attributes and disable external diff drivers and textconv.
  For example, on a supporting Git build:

  ```bash
  git --no-lazy-fetch --attr-source=<head-SHA> diff --no-ext-diff --no-textconv <basis-SHA> <head-SHA>
  git --no-lazy-fetch show <head-SHA>:<path>
  ```

  These are examples, not commands guaranteed on every build.
  If attribute selection is unsupported, use a SHA-pinned API or isolated repository instead of allowing another worktree's attributes to change the diff.
- Missing objects/history call for SHA-pinned API evidence or a separate disposable Git repository, fetching only what is needed there.
  For GitHub, a compare request using captured base/head SHAs can supply `merge_base_commit`; full files can be requested with a captured head SHA as `ref`.
  Verify response identity and that the comparison starts at the recorded basis; a three-dot API comparison may use a merge base instead of an explicitly supplied range basis.
  Paginate where supported and check coverage: changed-file lists have limits, and patches may be absent or truncated (see [GitHub comparison limits](https://docs.github.com/en/rest/commits/commits#compare-two-commits)).
  Do not treat missing API data as absent code or use a moving `gh pr diff` after pinning the head.
  If evidence remains incomplete, state what cannot be reviewed.
  The disposable repository may borrow source objects read-only through alternates, but all fetched objects and metadata writes must stay outside the source.

Runtime verification is optional.
Run potentially writing tests, builds, formatters, or generators only in a separate disposable clone or exported tree materialized from exact Reviewed head; verify that revision before execution.
Do not copy the current worktree, use a descendant's results, or use `git worktree add`, which writes source Git metadata.
Discard generated changes there.
If isolation is unavailable, use CI evidence explicitly tied to Reviewed head or static inspection and disclose the runtime coverage limit.

## Select conversation evidence

Use context explicitly supplied for this review first, including a named file; report an unavailable specified source without silently substituting another.
If supplied material is supplemental or partial, seek additional context only as needed to assess the requested decisions; supplying a status report does not itself exclude an exported context.
Honor an explicit restriction to particular sources, and do not search every source merely to claim completeness.
When no context is supplied, check relevant PR conversation-context comments and the conventional local `.dev/contexts/{sanitized target branch}.md` if available before concluding that context is absent.
Use these same sources for any needed additional discovery.
Comments shared by [conversation-context-export](../conversation-context-export/SKILL.md) use the first heading `# {branch name} 対話コンテキスト`; use that as a discovery cue, then validate provenance.
Sanitization replaces each of `/ \ : * ? " < > |` with `-`.
For a non-PR range, discover a local file only when a branch is actually associated with that target, not merely because the current checkout has a branch.

For supplied and discovered candidates alike, check available heading, PR/repository, Branch, Source commit, update time, and stated scope.
Supplied notes need not follow the export schema, but their priority does not establish their provenance:

- A discovered context should identify this target (PR if recorded, and branch) and have a resolvable source commit at or before Reviewed head in its ancestry.
  Export placeholders `PR not created at export time`, `PR not checked at export time`, and `PR unverified at export time` can be accepted with matching branch and source provenance; the latter two do not prove PR absence.
  Missing/mismatching metadata needs clarification before automatic use.
- Source commit dates the evidence; it need not equal Reviewed head.
  Earlier context may omit later decisions, and `.dev/contexts/` is uncommitted handoff evidence, not code at that revision.
  For explicitly supplied material too, check source timing using available metadata or provenance established by the user.
  If its provenance relative to Reviewed head remains unverified or Source commit is a descendant of or unrelated to Reviewed head, use it only as labeled supplemental or retrospective evidence, not as that head's implementation record.
  Do not infer a code defect merely because a later record describes something absent at Reviewed head.
  Clarify its intended role if this prevents meeting an explicit requirement for implementation context.
- Multiple comments and local files can differ.
  Compare provenance, target, time, and content; neither the newest comment nor a newer local timestamp alone establishes which is authoritative.
  A local-only export does not update a previously shared comment.
  State which sources you used and any relevant staleness or conflicts; ask only if an unresolved choice materially affects the review.

If no usable context is available, normally continue and state that prior deliberations could not be verified.
Ask when the user made that context a prerequisite or a material source ambiguity cannot be resolved; honor an existing instruction to continue without it.
Do not invent missing deliberations, regenerate context, or require sharing to proceed.

## Investigate the claims and change

Read the PR explanation and relevant discussion (including review comments and review bodies), or the supplied non-PR brief, alongside the diff and surrounding code.
Keep attribution clear: another reviewer's suggestion is not an implementer's claim, and a supplied brief does not establish its author's identity or approval.
Follow linked ADRs or history when they bear on a decision under review; do not read every ADR or reopen every past choice by default.
Read repository documents at Reviewed head, labeling other revisions separately.

For decisions relevant to the change, test whether the stated premises hold in the code, whether rejected options were compared fairly, whether a failed attempt's setup supports its conclusion, and whether intentional non-actions still make sense.
Check the resulting behavior, regressions, and relevant security consequences yourself; process review does not replace code investigation.
Keep exploration proportional to the requested change and evidence of impact.

Check established code conventions where the change interacts with them.
When documents conflict with existing code, do not declare the implementation wrong merely because the document uses imperative language.
Distinguish stale guidance from requested requirements and evidence of current specifications or intentional constraints; follow applicable repository instructions and report material discrepancies.
Raise naming/design concerns when grounded in the actual change and plausible consequences, considering counterevidence; no mandatory long-term speculation or checklist grading is needed.
A missing explanation is an evidence gap, not proof of a code defect or the implementer's lack of understanding.

## Consultation and report

A second agent is not required.
When requested or useful within the authorized review scope, use [subagent-consultation](../subagent-consultation/SKILL.md).
For an independent review, provide target materials and operation limits, withhold your hypotheses and draft findings, and check the host's actual conversation inheritance; use fresh context when available.
Critique of a supplied proposal is a different mode and needs that proposal.
Verify returned candidates yourself; disclose an unmet requested review mode or material missing coverage without treating an unavailable consultant as invalidating your own evidence.

Report in the user's working language, normally in the conversation:

- Identify the target, exact Reviewed head and Comparison basis, and context sources/roles used.
- Lead with actionable findings: location, observed behavior or supported contradiction, conditions and consequences, and evidence.
  Distinguish verified defects from open questions and missing evidence.
- State verification performed and material limits, including unavailable context or runtime checks, then the resulting judgment and recommended action.
  If there are no findings, say so without implying exhaustive correctness.

Scale the format to the findings and user request.
Do not repeat the PR summary, print every check, or fill empty sections merely to show completion.
