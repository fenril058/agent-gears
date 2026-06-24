---
name: sanity-review
description: >-
  Write a PR review report. Beyond investigating bugs and vulnerabilities, verify the
  coherence between the exported conversation context, the PR description, and the
  implemented code — doubt the implementer's sanity. Use when the user says "write a
  review report for this PR", "code-review this with the conversation context", or
  "doubt this PR's sanity".
argument-hint: "[PR-URL-or-number]"
---

# PR review report procedure

Review a feature/bugfix/refactoring PR and write a review report. The report is what a
reviewer pastes on GitHub to mark the review complete, and to explain fixes if any.

## Out of scope

- Library-update PRs (dependabot/renovatebot etc.) belong to the `library-update-review`
  skill, not this one.

## Procedure

### Step 0: Fetch PR info

If a PR number or URL is given as an argument, target that PR. Otherwise auto-detect
the PR linked to the current branch.

Either way, fetch PR info:

```
gh pr view {PR number or URL} --json number,title,body,url,author,comments,headRefName
```

For auto-detection, omit `{PR number or URL}`.

If no PR is found, report to the user and stop.

PR title, PR number, and branch name go in the report header. For "Reviewed at" use the
current datetime (YYYY-MM-DD HH:mm:ss); for "Reviewer" use your own agent name.

Fetch the following:

1. PR body (description).
2. PR comments: from `gh pr view` comments.
3. Inline review comments: `gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate`
4. PR reviews: `gh api repos/{owner}/{repo}/pulls/{number}/reviews --paginate`
5. Diff: `gh pr diff {number}`

### Step 1: Load the conversation context

Look for the conversation context in this order:

#### 1-1. Check PR comments

Check whether any PR comment has a title containing "対話コンテキスト" (conversation
context). If found, use its content as the conversation context.

#### 1-2. Check .dev/contexts/

Sanitize the branch name (replace `/ \ : * ? " < > |` with `-`) and look for
`.dev/contexts/{sanitized branch name}.md`. If found, read it with the Read tool.

#### 1-3. If neither is found

Ask with the AskUserQuestion tool:

- **Continue without conversation context**: skip step 6 (omission check).
- **Abort**: ask the user to prepare the conversation context.

### Step 2: Assess PR description quality

**Do this before reading the code.** It prevents being pulled toward code-coherence
and missing structural problems in the description.

The implementer may not be sane. They may have written the description without really
understanding it, or had an AI generate it and pasted it as-is. In this step, read
only the description and assess whether a reviewer can "judge the validity of the
change" from it.

#### PR description checklist

Assess **all four** items and note the results. Finish all before the next step:

1. **Is the prior behavior / problem explained?** A reviewer needs to know the prior
   state to judge validity. "What was done" alone leaves the doubt "maybe the prior
   behavior was actually correct".
2. **Is it written as problem→solution or current→fix pairs?** For new features,
   purpose/motivation is acceptable. A one-way "what I did" explanation is insufficient.
3. **Is the scope of change clear?** Is it clear what changed and what did not?
4. **Is the implementer's own understanding visible?** Not just AI-generated text
   pasted in — does it convey what the implementer was thinking?

### External agent consultation — common policy

Steps 3, 4, and 5 seek a second opinion from an external agent (except the "long-term
naming/design reflection" subsection of step 4). Step 6 consults only if something is
suspicious. Follow this fallback order and **do not judge by guessing — actually call
and try**:

1. Call `subagent-consultation` via the Skill tool. If it fails, go to 2.
2. The main agent does the work alone.

When you invoke `subagent-consultation`, convey the **depth** ("Consult well") and the
**concrete question** in the same turn — that is what the per-step `Args:` lines below
contain. Stating the depth up front stops the consultation skill from asking the user
back and interrupting the review. "If it fails" means the skill is unavailable or errors
on its single attempt; do not retry — fall back to 2.

If a fallback occurred or the external agent was unavailable, note it in the report's
"Problems encountered during review" section.

**When falling back to 2 (main agent alone)**, the core of this skill — the chain of
critical thinking (a protocol where the two sides examine and rebut each other to
improve accuracy and coverage) — is not functioning. A review without the back-and-
forth verification lacks its intended precision, so put the following at the top of the
"Problems encountered during review" section, verbatim, as a bold paragraph:

**⚠ Warning: the chain of critical thinking is not functioning. Suspect that the
execution environment is not sane.**

Each step states the Args to pass to the external agent and how to handle the result.

### Step 3: Coherence between the implementer's explanation and the implementation

The goal is a **doc–code read-through**: verifying that the explanations in the
description/comments match the actual code.

#### Important: pick up only the implementer's statements

Match the PR description author and each comment's author, and treat **only the
implementer's own statements** as the implementation explanation. Cheering comments,
hopeful comments, and questions written by others are not implementation explanations.
Confusing these with the explanation leads to wrong coherence judgments.

#### Checks

1. Does the PR description match the actual diff?
2. Do the implementer's explanations in inline review comments match the code?
3. Does the implementer's explanation in the PR review body (top-level review comment)
   match the implementation?
4. Does the conversation context match the implementation (if present)?

Record any discrepancy concretely.

#### Coherence check by an external agent

In addition to your own check, have an external agent verify coherence between the diff
and the description. Reading the code from another angle may surface discrepancies you
missed.

Per the common policy, call with these Args:

```
Args: Consult well. For PR #{number}, check whether the description and the actual diff have any discrepancy. {description summary and check points}
```

When you get the external agent's points, compare with your own results and check for
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

#### Check by an external agent

In addition to your own check, have an external agent verify naming/design-pattern
consistency.

Per the common policy, call with these Args:

```
Args: Consult well. For PR #{number}, check whether the added/changed naming and design patterns match the existing codebase's conventions. {change summary}
```

When you get the external agent's points, compare and check for oversights.

#### Long-term naming/design reflection

Reflect on whether the current naming/design could become a liability when the
codebase is later extended. Unlike consistency with existing code (a factual judgment),
this provides food for discussion to spark human imagination.

If something concerns you, write it out in a self-questioning form covering "concern /
counter-argument / conclusion or hold". This is your own view, so write it as normal
prose. 2-3 paragraphs per point is enough. You need not force a conclusion. If nothing
concerns you, write "None". This reflection is **not** delegated to the external agent;
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

Per the common policy, ask the external agent for a code review. Include the PR's change
summary, a diff summary, and the points to check.

**Include the depth in the Args.** Consultation skills ask the user back when depth is
unspecified, which interrupts the review flow:

```
Args: Consult well. Please code-review PR #{number}. {change summary and check points}
```

#### Verifying the result

Do not take the external agent's points at face value:

- Verify each point the external agent raised by reading the code yourself.
- Deliberately look for areas the external agent may have missed.
- When your view and the external agent's diverge, record both sides' reasons.

### Step 6: Re-read the conversation context — omission check

Skip this step if there is no conversation context.

**Code review is not a double-check of the work result. Review the process, not the
result.**

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

If anything is suspicious, also consult an external agent per the common policy. Include
"Consult well" in the Args.

### Step 7: Write the review report

Read [TEMPLATE.md](TEMPLATE.md) in the same directory as this SKILL.md and write the
report in that structure.

**Output the report to the conversation** (do not save to a file). The reviewer copies
and pastes it to GitHub themselves.

The template headings are in Japanese; write the report in the user's working language.

#### Report-writing guidelines

- **PR description > Summary**: quote/excerpt the implementer's explanation and organize
  it before-after. Do not fill gaps with imagination. If the explanation is insufficient,
  say so plainly.
- **PR description > Quality assessment**: fill in the step-2 checklist results as
  OK/NG/N-A. For NG, state concretely what is missing.
- **Problems encountered during review section**: if a step was skipped, distinguish
  whether it was an external cause (a tool was unavailable, etc.) or the agent's
  judgment. If there were no problems, write "None".
- **Conclusion section**: state the overall judgment and recommended action.
- Throughout, focus on giving the reviewer the material to judge "is this change valid".

## Related skills

- **subagent-consultation**: consult a subagent (the Agent tool). Used as the external
  agent in steps 3/4/5/6.
- **conversation-context-import**: load the conversation context. Background for step 1.
- **conversation-context-export**: write out the conversation context. Background on the
  conversation-context format.
- **library-update-review**: review skill for library-update PRs — the kind of PR out of
  scope for this skill.
