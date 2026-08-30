---
name: empirical-prompt-tuning
description: Methodology for improving agent-facing instructions (skills / slash commands / CLAUDE.md / code-gen prompts). Starts from a static description/body consistency audit, prefers each host's first-party tooling, and states what a candidate-vs-baseline comparison must establish before it is worth running at all. Meta-skill, invoke ONLY when the user explicitly asks for an empirical evaluation of a prompt or skill, or for the description / body consistency check. Do NOT auto-invoke after every skill edit; this is operator-triggered by name.
---

# Empirical Prompt Tuning

The author of a prompt cannot judge its quality.
The clearer the writer thinks something is, the more likely another agent will stumble on it.

That does not make every doubt worth measuring.
A comparison between "with the instruction" and "without it" is only evidence if the arm that is supposed to be without it genuinely cannot reach it — and establishing that is harder than writing the instruction was.
So work in order: audit statically, use what the host already gives you, and build a measurement only when a specific unresolved behaviour survives both.

## Suitable explicit requests

This skill runs only when an operator asks for it by name. The situations below are the ones worth asking about — they are not triggers, and none of them makes this skill start on its own.

- An operator wants a skill / slash command / task prompt checked after it was created or substantially revised
- An operator wants an agent's unexpected behaviour attributed to ambiguity on the instruction side
- An operator wants a high-importance instruction hardened (a frequently used skill, an automation-core prompt)

Not worth asking about for one-off throwaway prompts, or for encoding the writer's subjective preferences.

## 1. Static consistency audit

Always first, and often enough on its own. No dispatch, no execution.

- Read the triggers and use cases claimed by the frontmatter `description`.
- Read the scope the body actually covers.
- Reconcile the two before anything else.

A gap here poisons everything downstream: an executor reinterprets the body to match the description, and the instruction scores well without meeting its requirements.

Also read the instruction against what the host now injects on its own — system instructions, tool descriptions, and neighbouring always-on rules.
An instruction that duplicates or contradicts them is a defect visible without running anything.

## 2. First-party tooling

Before building anything, use what the host provides for running, tracing, and evaluating its own instructions.
It is maintained by the people who change the runtime, and it costs nothing to keep working.

Calibrate it before trusting a result. Establish what the tool actually measures, what its unit of comparison is, which evidence it captures, and when it stops.
Being first-party does not by itself establish reachability-level baseline isolation — the conditions in step 3 still have to be met before a result reads as a candidate's causal effect.

## 3. Custom measurement

Reach this step only when a specific unresolved behaviour survives steps 1 and 2. Settle all of the following **before** running anything. If any cannot be settled, do not run.

### Name the decision the result will change

Write down which placement decision moves on which outcome — keep, narrow, make explicit-only, restrict to one host, delete.
A measurement that leaves the decision unchanged either way is not worth its cost.

### Fix the requirements in advance, and never show them to the executor

Enumerate what the deliverable must satisfy before the run, and do not move it afterwards.
Never put the requirements into the execution prompt.
An arm that is handed the checklist can implement it directly, which collapses the difference the comparison exists to detect.
Score afterwards, from the deliverable and the observable evidence you captured.

### Score on observable evidence

A claim in the output that the executor "checked the repository" is not evidence that it did.
Prefer tool calls, file state, and the trace over the executor's own account of its behaviour.
State per requirement what would count as evidence, and mark a requirement unevaluated when that evidence was not captured — unevaluated is not a failure, and it is not a pass.

### Establish the isolation the comparison requires

This is the condition most often assumed and least often met. All four must hold:

- **The candidate is unreachable to the arm that is meant to be without it.** Unreachable, not merely unloaded. Disabling the host's customisations stops it from being loaded; an executor that goes looking still finds it. Close every path: the copy installed under the host's own configuration, a copy another arm is using or left behind, the copy inside the checkout the scenario places the executor in, and copies still reachable through Git history, refs, or a remote after the file is gone from the tip.
- **The evaluation criteria are withheld from every arm.**
- **The target's name does not leak from anywhere except the candidate itself.** An arm handed the candidate can read its name out of its own front matter; that is the treatment, not a breach. What must not happen is the name arriving by another route: the working directory and its siblings' names, process arguments, the inherited environment, Git metadata, the descriptions of unrelated instructions installed beside it, or documentation inside the world the scenario asks the executor to read.
- **Everything else the executor can observe is equivalent across arms.** Including anything the candidate delegates to: a dependency the candidate calls is a property of the environment, and every arm gets it equally.

### Set a time box and a stopping condition

Both before the first run. "Until the numbers look good" is not a stopping condition.

### If isolation cannot be established, report that

Do not run a comparison you cannot isolate and present its numbers with a caveat.
Report the inconclusive result: the question, the path that could not be closed, and what would have to change to answer it.
A number produced under a broken baseline is worse than no number, because it gets quoted later without the caveat.

## Reading results

- Compare per requirement, not by an aggregate score. An aggregate hides which requirement moved, and one non-critical item changing reads as an overall win.
- Do not average across hosts or models. The same fix can improve one model and regress another; the average erases the regression. The unit of comparison is one case on one host on one model.
- Record the host and model with every result. If the model cannot be determined, say so, and do not use that result for comparison.

## Related

- `agent-instructions-refine`: rewriting the instruction once this has found what is wrong with it.
- `spec-ambiguity-audit`: a cold read of a document by a cheap model, when the question is what a from-scratch implementer would trip on.
