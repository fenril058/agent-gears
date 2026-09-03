---
name: sanity-review
description: >-
  Review a change and write a review report bound to the reviewed code revision. Beyond
  investigating bugs and vulnerabilities, cross-check three separate pieces of evidence —
  the implementer's change declaration, the handed-off conversation context, and the
  implemented code — against each other, and doubt the implementer's sanity. Prefer
  running it from a session that did not implement the change. Use when the user says
  "write a review report for this PR", "code-review this with the conversation context",
  or "doubt this PR's sanity".
argument-hint: "[PR-URL-or-number | revision-range]"
compatibility: Requires git on PATH. The GitHub adapter additionally requires the gh CLI (GitHub CLI, authenticated) to read the PR, its diff, and its comments; install gh from https://cli.github.com. Without GitHub, the invoker supplies the change declaration and the context handoff directly.
---

# Sanity review protocol

Review a feature/bugfix/refactoring change and write a review report.
The report is what a reviewer hands on to mark the review complete and to explain the fixes it asks for — pasted onto a PR where there is one, handed over however this host shares work where there is not.

**Invoking this skill is not the same as running a full review.**
A full review is a workflow: an implementation session declares its change and hands off its context, a *separate* review session runs this protocol, and the resulting report goes back to whoever fixes the code.
This skill is the reviewer's step in that workflow.
When the surrounding steps are missing the review still runs — but it runs degraded, and the report has to say so.

## Where this skill sits

```text
Implementation session
  |   change declaration + context handoff + code revision
  v
Review session  (this skill)   <-->   independent consultant
  |   review report, bound to the reviewed revision
  v
Fix session / human
```

## Review modes

Establish the mode before anything else; the whole report is read against it.

### Full independent review (recommended)

This session did not implement the change and does not hold the implementation conversation.
Everything it knows about the change arrives as explicit input (see "Review inputs").

The point of a separate session is not the ceremony of opening one.
It is that an implementation conversation carries implicit premises, self-justifications, and standing hypotheses, and a reviewer who inherits them cannot see the error those premises hide.
A fresh session forces the change declaration, the context, and the code to be re-read as evidence rather than remembered as conclusions.

### Self-review (degraded)

This session implemented the change, or holds the conversation in which it was implemented.

Self-review is not forbidden — it is cheap, immediate, and it catches real defects.
It is simply not a full independent review, and the report must not read like one.
Record it as the review mode, and work knowing that your own prior reasoning is the last thing you will think to doubt.

Nothing in this skill can detect from the inside which session it is running in, so the honesty is yours to supply.
If you produced the change under review, say so in the report.

## Review inputs

A review request is three kinds of evidence, whatever carries them.
Identify all three before reviewing, and record which ones you actually got.

### 1. Change declaration

What the implementer claims about this change: why it was made, what was changed, what they claim was *not* changed, the invariants they claim still hold, and the non-goals or scope boundary they declare.

On the GitHub adapter this is the PR body, plus the implementer's own PR comments and review bodies.
Elsewhere it is whatever statement of the change the invoker supplies.
If there is none, step 2 has nothing to assess: record its absence rather than reconstructing it from the diff — a declaration you wrote yourself cannot contradict the code.

### 2. Context handoff

What the code cannot show: design intent and its grounds, rejected alternatives and why they were rejected, discovered constraints, verified facts, and the areas that were difficult.

`conversation-context-export` is the usual producer.
On the GitHub adapter its output arrives as a PR comment, as a file under `.dev/contexts/`, or both.

**Handoff context is evidence, not authority.**
The design decisions, constraints, rejection reasons, and intentional non-goals recorded there are the implementer's claims, and they are part of what you review.
Do not adopt them as premises just because they are written down.
Check them against the repository, the code, and outside evidence wherever you can; step 6 is where this is done deliberately.
The same holds for the change declaration.

### 3. Code revision / diff reference

What you actually reviewed, in a form that can be identified afterwards: the repository or worktree, the reviewed head revision, and the comparison basis (base revision or diff range).

This is what binds the report to a state of the code.
Without it the report is an opinion about an unnamed thing, and nobody can tell later whether it still applies.

### Transport is not part of this contract

This skill consumes whatever the invocation makes available.
It does not define where these artifacts are stored or how they travel between sessions.
On GitHub a PR happens to carry all three at once; elsewhere the invoker supplies the declaration and the handoff, and git supplies the revision.
When an input cannot be obtained, that is a degradation to record — not a reason to invent a transport for it.

## Out of scope

- Library-update PRs (dependabot/renovatebot etc.) belong to the `library-update-review`
  skill, not this one.

## Procedure

### Step 0: Establish the review frame

#### 0-1. Determine the review mode

Full independent review, or self-review (see "Review modes").
Write it down now; it goes in the report header and it colours how much weight your own agreement with the implementer is worth.

#### 0-2. Collect the review inputs

**GitHub adapter.** If a PR number or URL is given as an argument, target that PR. Otherwise auto-detect the PR linked to the current branch.

```
gh pr view {PR number or URL} --json number,title,body,url,author,comments,headRefName,headRefOid,baseRefName,baseRefOid
```

For auto-detection, omit `{PR number or URL}`.

Fetch the following:

1. PR body — the core of the change declaration; the implementer's own comments and
   review bodies (items 2-4) extend it.
2. PR comments: from `gh pr view` comments.
3. Inline review comments: `gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate`
4. PR reviews: `gh api repos/{owner}/{repo}/pulls/{number}/reviews --paginate`
5. Diff: `gh pr diff {number}`

**No PR.** Do not stop merely because there is no PR — a PR is one adapter, not the review input itself.
Take the change declaration and the target from the invocation: a revision range in the argument, a statement of the change from the user, or both.
If neither the argument nor the conversation names a target, ask with the AskUserQuestion tool which revision range to review and where the change declaration is.
If the user has no change declaration to give, you may still review the diff — record the missing declaration as a degradation and mark the step-2 checklist as unassessable.

#### 0-3. Bind the review to a revision

Record what you are reviewing, from the worktree that holds it:

```
git -C {worktree} rev-parse HEAD &&
git -C {worktree} status --porcelain &&
git -C {worktree} log --oneline {comparison basis}..HEAD
```

- **Reviewed revision**: the head commit under review — `headRefOid` on the GitHub adapter, `HEAD` otherwise.
- **Comparison basis**: the commit or range the change is read against. `gh pr diff` shows the diff from the merge base, so on the GitHub adapter record `git merge-base {baseRefOid} {headRefOid}` — `baseRefOid` alone is the base branch's current tip and moves as that branch advances. Otherwise: the explicit range given, or the merge base with the integration branch.
- **Uncommitted changes**: if `git status --porcelain` is non-empty and those changes are part of what you review, say so. The report is then bound to a state that cannot be recovered from the revision alone, which is itself worth reporting.

Check both ends before you trust them.
Confirm each revision exists locally with `git -C {worktree} rev-parse --verify {SHA}^{commit}` — a fresh checkout often lacks the base branch's objects, and `git merge-base` then fails rather than returning a usable basis; fetch that ref before continuing.
Confirm the worktree's `HEAD` is the revision you are about to report: when the PR's head is not checked out here, report the revision you actually read, not the one you were asked about.

The change title, the PR number if any, and the branch name go in the report header.
For "Reviewed at" use the current datetime (YYYY-MM-DD HH:mm:ss); for "Reviewer" use your own agent name.

### Step 1: Load the context handoff

Look for the context handoff in the order below.
If the invocation already supplied one — pasted into the request, or pointed at by a path — use that and skip the search.

#### 1-1. Check PR comments

Check whether any PR comment has a title containing "対話コンテキスト" (conversation
context). If found, use its content as the conversation context.

#### 1-2. Check .dev/contexts/

Sanitize the branch name (replace `/ \ : * ? " < > |` with `-`) and look for
`.dev/contexts/{sanitized branch name}.md`. If found, read it with the Read tool.

1-1 and 1-2 are where `conversation-context-export` currently puts its output.
They are the adapter, not the definition: a handoff that arrives another way is the same evidence and is used the same way.

#### 1-3. If none is found

Ask with the AskUserQuestion tool:

- **Continue without the context handoff**: skip step 6 (omission check) and record the
  degradation.
- **Abort**: ask the user to prepare the context handoff.

#### 1-4. Follow the ADRs the context links to

The conversation context keeps only a summary of a decision recorded as an ADR; the
grounds live in the ADR itself (see `conversation-context-export`). Read every ADR the
context links to — without them you are reviewing against a summary and will read a
deliberate, recorded decision as an unexplained choice.

If the diff touches the ADR directory or `CONTEXT.md`, read those changes here too.
A change that rewrites a decision or a definition is making a claim about the whole
codebase, not just about its own diff.

Reading an ADR is not deferring to it. It tells you what was decided and why, which is
what step 6 re-evaluates.

### Step 2: Assess the change declaration

**Do this before reading the code.** It prevents being pulled toward code-coherence
and missing structural problems in the declaration.

The implementer may not be sane. They may have written the declaration without really
understanding it, or had an AI generate it and pasted it as-is. In this step, read
only the declaration and assess whether a reviewer can "judge the validity of the
change" from it.

#### Change declaration checklist

Assess **all four** items and note the results. Finish all before the next step:

1. **Is the prior behavior / problem explained?** A reviewer needs to know the prior
   state to judge validity. "What was done" alone leaves the doubt "maybe the prior
   behavior was actually correct".
2. **Is it written as problem→solution or current→fix pairs?** For new features,
   purpose/motivation is acceptable. A one-way "what I did" explanation is insufficient.
3. **Is the scope of change clear?** Is it clear what changed and what did not — and
   which non-goals are claimed deliberately?
4. **Is the implementer's own understanding visible?** Not just AI-generated text
   pasted in — does it convey what the implementer was thinking?

If there is no change declaration at all (step 0-2), record all four as unassessable and
say so in the conclusion; a change nobody explained is a review finding in itself.

### Independent consultation — common policy

Steps 3, 4, and 5 seek a second opinion from an independent consultant (except the
"long-term naming/design reflection" subsection of step 4). Step 6 consults only if
something is suspicious. Follow this fallback order and **do not judge by guessing —
actually call and try**:

1. Call `subagent-consultation` via the Skill tool. If it fails, go to 2.
2. The main agent does the work alone.

When you invoke `subagent-consultation`, convey the **depth** ("Consult well") and the
**concrete question** in the same turn — that is what the per-step `Args:` lines below
contain. Stating the depth up front stops the consultation skill from asking the user
back and interrupting the review. "If it fails" means the skill is unavailable or errors
on its single attempt; do not retry — fall back to 2.

#### What makes a consultant independent

Independence is not "a different model family". That is a heuristic for one of its axes.
The axes that matter here:

- **Session / conversation-context independence** — the consultant inherits neither the
  implementation conversation nor yours.
- **Model / prior diversity** — different training, so different blind spots.
- **Independent inspection** — the consultant reads the repository and verifies claims
  for itself, instead of grading your summary of them.
- **Tool / execution environment** — a consultant that can run different checks fails
  differently, and finds what your environment hides.
- **An explicit adversarial role** — the consultant is asked to rebut, not to confirm.

These stack on two separate layers, and neither substitutes for the other:

- **Implementation → reviewer**: the mode recorded in step 0-1. A cross-family consultant
  does not turn a self-review into an independent review.
- **Reviewer → consultant**: this section. A fresh review session does not remove the
  need for a second opinion.

**Which consultant.** `subagent-consultation` picks the consultant itself, but tell it
what this step needs, because the steps differ. Steps 3, 5, and 6 ask whether the code
and the implementer's claims are *right*, so they are worth the extra cost of a
consultant whose priors are independent of yours — in practice, a different model family
(on Claude Code, Codex). Step 4 is a read of the existing codebase rather than a
judgment call, so a same-family subagent is enough. The per-step `Args:` lines below
carry this preference; if the host has no cross-family consultant, the consultation
skill falls back on its own and the review continues.

The preference order

```text
different model family > same-family fresh consultant > reviewer alone
```

is a heuristic for prior diversity, not the definition of independence. A cross-family
consultant handed a prompt that states the implementer's conclusions as settled facts is
barely independent at all; a same-family consultant that reads the repository cold and is
asked to argue the other side is a real second opinion. Write prompts that hand over the
question and the evidence, not the verdict.

Two different fallbacks can happen here, and they are recorded differently.
A **tier fallback** — the step asked for a cross-family consultant and a same-family
fresh one answered instead — still produced an independent consultation: record which
tier answered in the header, and note the fallback in the report's "Problems encountered
during review" section. Only when **no consultant answered at all** (step 2 above) does
the header say the review carried no independent consultation.

**When falling back to 2 (main agent alone)**, the core of this skill — the chain of
critical thinking (a protocol where the two sides examine and rebut each other to
improve accuracy and coverage) — is not functioning. A review without the back-and-
forth verification lacks its intended precision, so put the following at the top of the
"Problems encountered during review" section, verbatim, as a bold paragraph:

**⚠ Warning: the chain of critical thinking is not functioning. Suspect that the
execution environment is not sane.**

Each step states the Args to pass to the consultant and how to handle the result.

### Step 3: Coherence between the implementer's explanation and the implementation

The goal is a **doc–code read-through**: verifying that the explanations in the change
declaration and comments match the actual code.

If there is no change declaration (step 0-2), checks 1 and 3 below are not applicable:
run check 4 against the context handoff if there is one, and do not reconstruct a
declaration from the diff so that something exists to compare against.

#### Important: pick up only the implementer's statements

Match the change declaration's author and each comment's author, and treat **only the
implementer's own statements** as the implementation explanation. Cheering comments,
hopeful comments, and questions written by others are not implementation explanations.
Confusing these with the explanation leads to wrong coherence judgments.

#### Checks

1. Does the change declaration match the actual diff?
2. Do the implementer's explanations in inline review comments match the code?
3. Does the implementer's explanation in the PR review body (top-level review comment)
   match the implementation?
4. Does the context handoff match the implementation (if present)?

Record any discrepancy concretely.

#### Coherence check by an independent consultant

In addition to your own check, have a consultant verify coherence between the diff
and the declaration. Reading the code from another angle may surface discrepancies you
missed.

Per the common policy, call with these Args:

```
Args: Consult well. Prefer a consultant from a different model family. For {PR #number or revision range}, check whether the implementer's stated change and the actual diff have any discrepancy. {declaration summary and check points}
```

When you get the consultant's points, compare with your own results and check for
oversights.

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

#### Check by an independent consultant

In addition to your own check, have a consultant verify naming/design-pattern
consistency.

Per the common policy, call with these Args:

```
Args: Consult well. A same-family subagent is fine. For {PR #number or revision range}, check whether the added/changed naming and design patterns match the existing codebase's conventions. {change summary}
```

When you get the consultant's points, compare and check for oversights.

#### Long-term naming/design reflection

Reflect on whether the current naming/design could become a liability when the
codebase is later extended. Unlike consistency with existing code (a factual judgment),
this provides food for discussion to spark human imagination.

If something concerns you, write it out in a self-questioning form covering "concern /
counter-argument / conclusion or hold". This is your own view, so write it as normal
prose. 2-3 paragraphs per point is enough. You need not force a conclusion. If nothing
concerns you, write "None". This reflection is **not** delegated to the consultant;
the skill's own agent thinks it through.

Example output:

```markdown
The name "access-token" is fine for now, since it only refers to the token between user
and service. But if a token for connecting to an external service appears later, a
concept clash could occur.

If so, the subject may need to be in the name, like `user-access-token`. That said,
there is currently no visible plan to add external-service integration soon, so it is
not a problem to fix now.
```

### Step 5: Bug and vulnerability investigation

Per the common policy, ask the consultant for a code review. Include the change
summary, a diff summary, and the points to check.

**Include the depth in the Args.** Consultation skills ask the user back when depth is
unspecified, which interrupts the review flow:

```
Args: Consult well. Prefer a consultant from a different model family. Please code-review {PR #number or revision range}. {change summary and check points}
```

#### Verifying the result

Do not take the consultant's points at face value:

- Verify each point the consultant raised by reading the code yourself.
- Deliberately look for areas the consultant may have missed.
- When your view and the consultant's diverge, record both sides' reasons.

### Step 6: Re-read the context handoff — omission check

Skip this step if there is no context handoff.

**Code review is not a double-check of the work result. Review the process, not the
result.**

What was done is visible in the code. What was *considered and not done* is the
information design review needs. Verify whether the "process" written in the context
handoff — design decisions, rejection reasons, intentional non-actions — is correct.
This is the step where the handoff stops being a briefing and becomes the object of
review.

Re-read the context handoff closely and verify:

#### 6-1. Grounds for design decisions

Do the reasons for the design decisions in the context handoff match the reality
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

For things decided as "won't do" — including the non-goals the change declaration
claims:

- Is the "won't do" reason still sound given the actual implementation?
- Did the implementation change the premise so it should now be "should do"?
- Does the code actually stay inside the declared scope boundary?

#### 6-5. Accuracy of stated facts

Verify, by reading the code, that the "facts" written in the context handoff are
actually correct.

If anything is suspicious, also consult independently per the common policy. Include
"Consult well" and the preference for a different model family in the Args.

### Step 7: Write the review report

Read [TEMPLATE.md](TEMPLATE.md) in the same directory as this SKILL.md and write the
report in that structure.

**Output the report to the conversation** (do not save to a file). The reviewer hands it
on themselves — pasting it onto the PR, or however this host shares work.

The template headings are in Japanese; write the report in the user's working language.

#### The report contract

Whatever the wording, the finished report must let a later reader identify:

- what was reviewed: the change's title, the review target (the PR number, or the
  repository and the range), and the branch;
- the reviewed revision and the comparison basis, including whether uncommitted
  working-tree changes were part of it;
- which change declaration and which context handoff were used, and where they came from;
- the findings, each with a disposition (must fix / should fix / question to the
  implementer / accepted as is);
- the questions the review could not resolve;
- the reviewer and the review datetime;
- whether an independent consultation actually happened, and with what kind of
  consultant;
- the review mode, plus any other degradation (missing declaration, missing handoff,
  consultant unavailable, diff too large to cover).

This list is the minimum meaning a report must carry; TEMPLATE.md is one concrete shape
of it, and its header is where most of these land.

#### Report-writing guidelines

The template's headings are Japanese, so each guideline below names the heading it
applies to.

- **Change declaration > Summary** (`change declaration(変更の宣言)` > `サマリー`):
  quote/excerpt the implementer's explanation and organize it before-after. Do not fill
  gaps with imagination. If the explanation is insufficient, say so plainly.
- **Change declaration > Quality assessment** (`品質評価`): fill in the step-2 checklist
  results as OK/NG/N-A/unassessable. For NG, state concretely what is missing.
- **Findings and disposition** (`指摘事項と扱い`): collect the points raised in the
  sections above into one place, each with the disposition you assign it. A finding whose
  disposition is left implicit gives the fixer nothing to act on.
- **Unresolved questions** (`未解決の問い`): the questions the review could not settle —
  for lack of information, of a way to verify, or because only the implementer can answer.
- **Problems encountered during review** (`レビュー作業において発生した問題`): if a step
  was skipped, distinguish whether it was an external cause (a tool was unavailable, etc.)
  or the agent's judgment. If there were no problems, write "None".
- **Conclusion** (`結論`): state the overall judgment and recommended action.
- Throughout, focus on giving the reviewer the material to judge "is this change valid".

#### The report is bound to one revision

The report describes the revision recorded in step 0-3 and nothing else.
Once the code moves — new commits, a rebase, a force-push, an amended fix for one of the
findings — the report is about the old revision and may be stale.

Say what it is bound to, so the next reader can check for themselves whether it still
applies. When asked to review again after the code has moved, re-derive the revision
binding and re-check the findings against the new revision rather than carrying the old
report's dispositions forward.

## Related skills

- **subagent-consultation**: consult an independent agent (the Agent tool, or another
  vendor's CLI through an execution adapter). Used as the consultant in steps 3/4/5/6;
  it also decides which consultant to use, Codex included.
- **conversation-context-import**: load a conversation context. Background for step 1.
- **conversation-context-export**: write out the conversation context. The usual producer
  of the context handoff, and background on its format.
- **library-update-review**: review skill for library-update PRs — the kind of change out
  of scope for this skill.
- **domain-modeling**: owns the record tier (`CONTEXT.md` and the ADRs). Background on the
  ADR format and superseding rules for the ADRs step 1-4 follows.

The human-facing side of this workflow — which session to run what from, and how the
report gets handed on — is in the `code-review` plugin's README.
