---
name: unconventional-simplification
description: >-
  Simplify an implementation with unconventional thinking. Instead of iterating on the
  current solution, enumerate the implicit assumptions behind it, remove them one at a
  time, and look for a simpler alternative. Use when the user says "question the
  assumptions", "think outside the box", or "can this be simpler?".
argument-hint: "[target file/module — optional]"
---

# Unconventional simplification procedure

This skill does not review the adopted solution or add features to it. It enumerates
the implicit assumptions behind the solution, removes them one at a time, and searches
for an alternative that needs less implementation and less explanation. Do not drift
into an evolution of the current design — think by subtracting elements.

You are not generating ideas from scratch: the object of reconsideration is an
implementation, policy, or design decision that already exists.

## Step 1: Identify the target

Identify "the solution to reconsider now (the first draft)".

1. **If arguments were given**: target the specified file, module, or feature.
2. **If there is conversation context**: target the policy, design decision, or
   implementation approach most recently reached. This is the primary method.
3. **Cold start**: when the conversation context is thin and there are no arguments,
   auto-detect the most recent change as the target, and state in one line what you
   inferred the target to be.

Once the target is identified, examine the code implementing it in this order:

1. If a target file/module was given in the arguments, read it directly first.
2. Check uncommitted changes with `git diff` and `git diff --staged`.
3. If there are no uncommitted changes, check the diff against the base branch or the
   recent commits. Determine the base branch with e.g.
   `git symbolic-ref refs/remotes/origin/HEAD` and diff like
   `git diff origin/main...HEAD`. If it cannot be determined, look at `git log -p -3`.

## Step 2: Enumerate the assumptions

Enumerate the assumptions the adopted solution implicitly makes, from the code and the
conversation context. Only handle assumptions grounded in the code or the conversation —
do not import imaginary requirements.

Examples:

- This API / data structure / state must be preserved.
- This processing must be provided at this timing / UI / place.
- The problem must be solved at this layer.

Include assumptions about the problem framing, not just the implementation: go back as
far as "what kind of user / situation is this really for" and "shouldn't this be
handled at an earlier stage". Without removing these, you fall back to a mere diff
review of the implementation.

## Step 3: Remove assumptions one at a time and reconsider

Take the enumerated assumptions one at a time and ask "what would the solution look
like without this assumption?". Never remove multiple assumptions at once.

- If it does not get simpler, record the reason briefly and skip it.
- If it gets simpler, flesh out that alternative.

## Step 4: Cost comparison

Compare each simplified alternative against the first draft on these 5 axes:

1. **Implementation size**: how much code disappears.
2. **Compatibility with existing behavior**: does it break existing behavior or APIs.
3. **Explanation cost**: do the concepts or behavior become harder to explain.
4. **Operation / migration cost**: does existing data or an operational flow need
   migration.
5. **Future maintainability**: is it easier to maintain long-term.

In addition, account for any other mechanism needed to make the assumption removal
hold. If removing the assumption requires extra implementation, documentation, or
education elsewhere, estimate honestly where the cost moved in exchange for the
simplicity.

## Step 5: Classification

Classify each alternative into three buckets:

- **Worth considering now**: the simplicity gain is large and the cost is justified.
- **Future topic**: the first draft is reasonable for now, but worth revisiting if the
  situation changes.
- **Current adoption is sound**: removing the assumption yields little benefit, or the
  cost outweighs it.

## Step 6: External agent consultation (optional)

Consult an external agent only when the user explicitly asks for it. Delegate the
mechanics of the consultation to `subagent-consultation`; this skill only specifies the
content of the consultation.

Left alone, an external agent drifts into an ordinary review. Request steps 2–5
themselves, not a review: have the external agent enumerate grounded assumptions
itself, and for each assumption examine whether replacing it with "the case without
this assumption" yields an alternative that needs less implementation and explanation.
Do not accept the returned alternatives at face value — verify them by reading the code
yourself.

## Step 7: Report

Output the result in the conversation. Do not save it to a file. Stop at proposal and
classification — do not auto-apply code. Which alternative to adopt is the human's
decision.

Report format:

```markdown
## Unconventional simplification review

### Target

{Summary of the solution under reconsideration. On a cold start, also state the
inferred target}

### Reconsideration per assumption

For each enumerated assumption:

- **Assumption**: {content}
- **Alternative without the assumption**: {concrete alternative; if it does not get
  simpler, say so with the reason}
- **5-axis comparison and mechanisms required by the removal**: {only the axes that
  matter}
- **Classification**: worth considering now / future topic / current adoption is sound

### Recommended action

{If anything is "worth considering now", what to consider. Otherwise conclude "the
current adoption is sound"}
```

## Related skills

- **subagent-consultation**: used in step 6 when the user asks for an external
  consultation.
