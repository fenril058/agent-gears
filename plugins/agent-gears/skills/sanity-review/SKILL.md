---
name: sanity-review
description: >-
  Write a review report for a PR, or — when there is no GitHub PR — for an explicit
  commit range given a review brief, Reviewed head, and Comparison basis. Beyond
  investigating bugs and vulnerabilities, verify the coherence between the exported
  conversation context, the description, and the implemented code — doubt the
  implementer's sanity. Use when the user says "write a review report for this PR",
  "code-review this with the conversation context", "doubt this PR's sanity", or asks
  for the same kind of review on a commit range that has no PR.
argument-hint: "[PR-URL-or-number | review brief + Reviewed head + Comparison basis]"
compatibility: Requires git on PATH. For a GitHub PR review, also requires the gh CLI (GitHub CLI, authenticated) on PATH; gh is used to read the PR, diffs, and comments. Install gh from https://cli.github.com.
---

# PR review report procedure

Review a feature/bugfix/refactoring change — a GitHub PR, or a commit range that has no
PR — and write a review report. For a PR, the report is what a reviewer pastes on
GitHub to mark the review complete, and to explain fixes if any.

## Out of scope

- Library-update PRs (dependabot/renovatebot etc.) belong to the `library-update-review`
  skill, not this one.

## Procedure

### Step 0: Determine the review target and bind the reviewed revisions

This skill has two input modes. Determine which applies before doing anything else:

- **GitHub PR review**: a PR number/URL is given as an argument, or the request
  otherwise names a GitHub PR, or the current branch has an associated PR to
  auto-detect. Use the existing PR review path below whenever it applies.
- **Non-PR revision-range review**: no GitHub PR applies, but the request explicitly
  gives a Reviewed head, a Comparison basis, and a review brief / change description
  for a commit range. Use the non-PR path below.

If neither applies — no PR argument or auto-detected PR, and no explicit Reviewed
head / Comparison basis / review brief — report to the user and stop, as before. A
missing PR is only a stopping condition when no non-PR input was given explicitly.

#### GitHub PR review

If a PR number or URL is given as an argument, target that PR. Otherwise auto-detect
the PR linked to the current branch.

Either way, fetch PR info:

```
gh pr view {PR number or URL} --json number,title,body,url,author,comments,headRefName,headRefOid
```

For auto-detection, omit `{PR number or URL}`.

If no PR is found and no non-PR input was given, report to the user and stop.

PR title, PR number, and branch name go in the report header. For "Reviewed at" use the
current datetime (YYYY-MM-DD HH:mm:ss); for "Reviewer" use your own agent name.

Fetch the following:

1. PR body (description).
2. PR comments: from `gh pr view` comments.
3. Inline review comments: `gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate`
4. PR reviews: `gh api repos/{owner}/{repo}/pulls/{number}/reviews --paginate`
5. The diff between the exact commits recorded as the Reviewed head and Comparison basis.

Determine the Comparison basis separately; do not assume that the current tip of the
base branch is the diff's basis. The Reviewed head is the PR's `headRefOid`.

#### Non-PR revision-range review

Required inputs — ask the user for whichever is missing rather than guessing or
substituting a default:

1. **Review brief / change description**: prose describing the change. It may be given
   inline in the request or as a file/note you can read. No particular schema, front
   matter, or storage location is required — read whatever is given, in place of the PR
   description for the rest of this procedure.
2. **Reviewed head**: a ref or commit-ish naming the code to review.
3. **Comparison basis**: a ref or commit-ish naming the start of the diff.

Resolve both refs to exact commit SHAs before reading any code:

```
git rev-parse <Reviewed head ref>^{commit}
git rev-parse <Comparison basis ref>^{commit}
```

Record the resulting SHAs — not the ref names — as the Reviewed head and Comparison
basis, and compute the diff directly between them:

```
git diff <Comparison basis SHA> <Reviewed head SHA>
```

Read the code at the Reviewed head with `git show <Reviewed head SHA>:<path>` (or
equivalent read-only plumbing) rather than checking the ref out into the current
worktree — this keeps uncommitted worktree changes out of the review without needing a
separate workspace.

There is no PR body, PR comments, inline review comments, or PR reviews for this path.
Their absence is expected here, not a failure; skip the steps below that depend on them.

The report header has no PR number and no branch name for this path (see Step 7); do
not fill either with a placeholder.

#### Bind the report, diff, and inspected code to exact revisions

Before reading the code, establish the exact commit SHA for the Reviewed head and the exact commit SHA actually used as the diff's Comparison basis.
Record commit SHAs rather than a branch name or a moving branch tip.

Maintain this invariant throughout the review:

```text
report's Reviewed head = diff's head = revision of the code actually inspected
Comparison basis = exact commit used as the start of the diff actually reviewed
```

Verify that the code you inspect is exactly the Reviewed head and that uncommitted worktree changes are not mixed into it as though they belonged to that revision.
If you cannot verify the inspected code against the Reviewed head, do not complete the review as a review of that commit; report the problem to the user and stop.

### Step 1: Load the conversation context

Look for the conversation context in this order:

#### 1-1. Check PR comments

Check whether any PR comment has a title containing "対話コンテキスト" (conversation
context). If found, use its content as the conversation context.

For a non-PR review there is no PR to have comments; skip this source without treating
its absence as a failure, and go to 1-2.

#### 1-2. Check .dev/contexts/

Sanitize the branch name (replace `/ \ : * ? " < > |` with `-`) and look for
`.dev/contexts/{sanitized branch name}.md`. If found, read it with the Read tool.

#### 1-3. If neither is found

Ask with the AskUserQuestion tool:

- **Continue without conversation context**: skip step 6 (omission check).
- **Abort**: ask the user to prepare the conversation context.

#### 1-4. Follow the ADRs the context links to

The conversation context keeps only a summary of a decision recorded as an ADR; the
grounds live in the ADR itself (see `conversation-context-export`). Read every ADR the
context links to — without them you are reviewing against a summary and will read a
deliberate, recorded decision as an unexplained choice.

If the diff touches the ADR directory or `CONTEXT.md`, read those changes here too. A
change that changes a decision or a definition is making a claim about the whole
codebase, not just about its own diff.

### Step 2: Assess description quality

**Do this before reading the code.** It prevents being pulled toward code-coherence
and missing structural problems in the description.

For a PR review this is the PR description; for a non-PR review it is the review brief
/ change description from Step 0. Either way, use the same checklist below — this skill
does not define a separate rubric for the non-PR case.

The implementer may not be sane. They may have written the description without really
understanding it, or had an AI generate it and pasted it as-is. In this step, read
only the description and assess whether a reviewer can "judge the validity of the
change" from it.

#### Description checklist

Assess **all four** items and note the results. Finish all before the next step:

1. **Is the prior behavior / problem explained?** A reviewer needs to know the prior
   state to judge validity. "What was done" alone leaves the doubt "maybe the prior
   behavior was actually correct".
2. **Is it written as problem→solution or current→fix pairs?** For new features,
   purpose/motivation is acceptable. A one-way "what I did" explanation is insufficient.
3. **Is the scope of change clear?** Is it clear what changed and what did not?
4. **Is the implementer's own understanding visible?** Not just AI-generated text
   pasted in — does it convey what the implementer was thinking?

### Step 3: Coherence between the implementer's explanation and the implementation

The goal is a **doc–code read-through**: verifying that the explanations in the
description/comments match the actual code.

#### Important: pick up only the implementer's statements

For a PR review, match the PR description author and each comment's author, and treat
**only the implementer's own statements** as the implementation explanation. Cheering
comments, hopeful comments, and questions written by others are not implementation
explanations. Confusing these with the explanation leads to wrong coherence judgments.

For a non-PR review, there are no separate comment authors to match; treat the review
brief / change description as the implementer's explanation.

#### Checks

1. Does the description / review brief match the actual diff?
2. Do the implementer's explanations in inline review comments match the code?
   (PR review only — a non-PR review has no inline review comments; skip this check
   without treating its absence as a failure.)
3. Does the implementer's explanation in the PR review body (top-level review comment)
   match the implementation? (PR review only — same as above.)
4. Does the conversation context match the implementation (if present)?

Record any discrepancy concretely.

Neither the description / review brief, the comments, nor the conversation context is
an authority on what the code does.
Each claim they make is something to verify against the code, not something to review
the code against.

### Step 4: Naming and design-pattern consistency

The goal is a **read of the codebase**: verifying the implementation matches the
existing codebase's conventions. Understanding the codebase before hunting bugs/vulns
raises the precision of the later investigation.

#### Checks

1. **Naming consistency**
   - Do file/function/variable/class names match existing naming patterns?
   - Is any abbreviated name introduced that drops part of a feature's proper name?
2. **Design-pattern consistency**
   - Do structure / module split / responsibility boundaries match existing similar
     features?
   - Does it reuse existing abstractions, or create duplicated implementations?

Record any discrepancy concretely.

#### Long-term naming/design risk

Consistency with existing code is a factual judgment.
Separately from it, if the naming or design looks likely to become a liability as the
codebase grows — a name that will collide with a concept the codebase is heading
toward, a responsibility split that will be awkward to extend — record the risk and why
you see it.
Weigh the case against your own concern as well: why the current naming or design may
be fine as it stands, and whether the change you are picturing is actually coming.
A risk recorded without that counter-argument is a one-sided prediction.
This is your own view, offered as material for discussion, so write it as normal prose;
you need not force a conclusion, and leaving it on hold is a valid outcome.
If nothing concerns you, write "None".

### Step 5: Correctness, regression, and security investigation

Investigate the code yourself.
This is the main reviewer's own work, not something the review delegates.

Cover at least:

1. **Correctness**: does the code actually do what the description and the implementer's
   explanation claim? Check the edge cases, the error paths, and the conditions under
   which the changed code runs.
2. **Regressions**: what existing behavior does this diff touch? Check existing callers,
   tests, and data — look at what the change removed, renamed, or narrowed, not only at
   what it added.
3. **Security and vulnerabilities**: untrusted input, injection, path and file handling,
   secrets, permissions, and any existing check the diff weakens or bypasses.

Read the code, not just the diff: a diff hides the context the changed lines run in.
Record each finding with the evidence for it — where it is, and why it is wrong.
Where tests cover the changed area, check whether they would actually catch the failure
you are describing.

### Step 6: Re-read the conversation context — omission check

Skip this step if there is no conversation context.

**Code review is not a double-check of the work result. Review the process, not the
result.**

Do not accept statements in the conversation context as correct premises; verify them against the code and other available information.
What was done is visible in the code. What was *considered and not done* is the
information design review needs. Verify whether the "process" written in the
conversation context — design decisions, rejection reasons, intentional non-actions —
is correct.

Re-read the conversation context closely and verify:

#### 6-1. Grounds for design decisions

Do the reasons for the design decisions in the conversation context match the reality
of the code?

#### 6-2. Re-evaluate rejected alternatives

From the "rejected alternatives" section, pull each alternative one by one and
re-evaluate:

- Is the rejection reason sound? Was the comparison really fair?
- Any overlooked advantage, or overstated disadvantage?
- Were the premises used to compare the chosen and rejected options correct?

#### 6-3. Process verification of failed attempts

For things recorded as "tried but didn't work", doubt not only the result but the
**way it was tried**:

- Were the premises correct?
- Was anything missed in the execution steps?
- Was the criterion (the basis for judging it "didn't work") sound?
- Could a different condition change the result?

#### 6-4. Validity of intentional non-actions

For things decided as "won't do":

- Is the "won't do" reason still sound given the actual implementation?
- Did the implementation change the premise so it should now be "should do"?

#### 6-5. Accuracy of stated facts

Verify, by reading the code, that the "facts" written in the conversation context are
actually correct.

### Optional: an independent review

The numbered steps are the whole review: the main reviewer can complete every one of
them alone.
An independent reviewer is an addition to that review, never a condition for it.

Use one only when you judge that a second search path over the same material would
reach something your own pass could not: an area you could not get comfortable with, a
change whose blast radius is wider than what you could read, a suspicion you cannot
settle from the code alone.
If the user asked for one outright, that settles it — run one without weighing it up.
Choosing not to use one is not a gap in the review, and does not belong in "Problems
encountered during review".

To run one, call `subagent-consultation` via the Skill tool.
State the depth ("Consult well") in the same turn as the question — without a depth the
consultation skill asks the user back and interrupts the review.
Do not ask for any particular kind of consultant; `subagent-consultation` owns that
choice.

#### What the independent reviewer gets

The point is an independent path through the same material, not a reviewer working in
the dark.
Give it everything it needs to review the target on its own:

- the exact Reviewed head and Comparison basis
- the description / review brief, and — for a PR review — its comments and review
  bodies
- the conversation context and the ADRs it links to
- the diff, the code, and how the tests are run
- the repository's own instructions

Withhold your side of the review:

- your findings and your draft report
- the lines you suspect are buggy or vulnerable
- your severity judgments and your remediation ideas
- your conclusions

Handing those over turns an independent read into a confirmation of your own.

#### Handling what comes back

Everything the independent reviewer reports is a candidate, not a finding.
Verify each one against the primary evidence yourself before it enters the report, and
drop the ones that do not survive that check.
Its view holds no authority over yours: when the two diverge, record both sides'
reasons rather than deferring.
Look as well for what it did not cover — a second pass that missed something is not
evidence that there is nothing there.

#### When an independent review is absent

If the consultation fails, or no consultant is available, the review you already have
stands: finish it and write the report.
An unavailable consultant is not a review failure, and not a reason to doubt the
execution environment.

What to record depends on why the independent review is absent:

1. **You judged it would add nothing.** Record nothing. A main-only review is a normal,
   complete review, not a degraded one.
2. **You judged it worth running, and it could not be run.** The review is still
   complete, but the extra search path you had judged you needed never arrived. Record
   that in "Problems encountered during review" as a coverage limitation: what you
   wanted a second path for, and which area therefore rests on your reading alone.
3. **The user asked for an independent review, and it could not be run.** Present your
   own results as usual, and state plainly that the requested review mode could not be
   met. Do not let it pass as though the request had been fulfilled.

### Step 7: Write the review report

Read [TEMPLATE.md](TEMPLATE.md) in the same directory as this SKILL.md and write the
report in that structure.

**Output the report to the conversation** (do not save to a file). The reviewer copies
and pastes it to GitHub themselves.

The template headings are in Japanese; write the report in the user's working language.

#### Report-writing guidelines

- **Report header**: for a PR review, fill in the PR title, PR number, and branch name
  as before. For a non-PR review there is no PR number or branch name — leave those
  fields out rather than filling them with a placeholder, and use a short description of
  the review target (drawn from the review brief) in place of the PR title.
- **Description / review brief > Summary**: quote/excerpt the implementer's explanation
  and organize it before-after. Do not fill gaps with imagination. If the explanation is
  insufficient, say so plainly.
- **Description / review brief > Quality assessment**: fill in the step-2 checklist
  results as OK/NG/N-A. For NG, state concretely what is missing.
- **Independent review section**: include it only if one actually returned a usable
  result, recording its candidates and what your own verification made of each. Leave
  the section out otherwise; an attempt that returned nothing goes in "Problems
  encountered during review" instead.
- **Problems encountered during review section**: record what actually got in the way —
  a tool that failed, scope you could not verify, context you could not obtain. If a
  step was skipped, distinguish whether it was an external cause (a tool was
  unavailable, etc.) or the agent's judgment. Deciding an independent review would add
  nothing is not a problem; do not record it as one. An independent review you judged
  worth running but could not run does belong here, as a coverage limitation. If there
  were no problems, write "None".
- **Conclusion section**: state the overall judgment and recommended action.
- Throughout, focus on giving the reviewer the material to judge "is this change valid".

## Related skills

- **subagent-consultation**: consult a subagent (the Agent tool). Used only for the
  optional independent review; it decides which consultant to use, Codex included.
- **conversation-context-import**: load the conversation context. Background for step 1.
- **conversation-context-export**: write out the conversation context. Background on the
  conversation-context format.
- **library-update-review**: review skill for library-update PRs — the kind of PR out of
  scope for this skill.
- **domain-modeling**: owns the record tier (`CONTEXT.md` and the ADRs). Background on the
  ADR format and superseding rules for the ADRs step 1-4 follows.
