---
name: subagent-consultation
description: >-
  Consult an independent agent for a second opinion. Use when the user says "consult a
  subagent", "ask a subagent", "have a subagent review this", or similar. Build a prompt
  from the current conversation, run it on whichever consultant this host can reach —
  a subagent through the Agent tool, or another vendor's CLI through an execution
  adapter — then digest the result against your own view and report a summary to the
  user.
---

# Subagent consultation procedure

## Overview

Get a second opinion from a consultant agent (a subagent) and report a digested
summary to the user. The user does not need to see the subagent's raw output. The
consulting agent chews on the subagent's answer, checks it against its own view, and
reports.

### Roles

Three parties appear in this procedure:

- **User**: the human requesting the consultation.
- **Consulting agent**: you, running this procedure. You take the user's request,
  consult the consultant, and report to the user.
- **Consultant**: the independent agent that provides the second opinion. What supplies
  it depends on the host — a subagent launched via the Agent tool, or another vendor's
  CLI run through an execution adapter ("Platform implementations" below). The rest of
  this document says "the subagent" for it, whichever mechanism supplied it.

When reporting to the user, use your own agent name in the heading (e.g. "Claude
Code's view", "Cline's view").

Which consultant is available depends on the host; see "Platform implementations"
below. The rest of the procedure is the same everywhere.

## 1. Confirm consultation depth

If the user did not state a depth ("thoroughly", "deeply", "well", "lightly", etc.),
offer these three options with the AskUserQuestion tool:

| Option | Round-trips | Consulting agent's draft view | Gap-chasing |
| --- | --- | --- | --- |
| **Consult well** (recommended) | 2 if needed | agent decides | check for gaps and report |
| **Consult fully / deeply** | 2 as a rule (skip only if clearly unneeded) | always include; push the subagent to push back | actively rebut, supplement, chase further |
| **Consult lightly** | 1 only | agent decides | organize the subagent's points and report |

If the user explicitly specified a depth, skip this and follow it.

## 2. Design the prompt

You design the prompt sent to the subagent. Follow these guidelines:

### Prompt design

- Judge "what should be consulted now" from the conversation context.
- If the user named a topic explicitly, follow it.
- If not, pick an appropriate topic from the immediately preceding discussion or work.

### Prompt examples by context

- **Review uncommitted changes**: "Review the uncommitted changes in this
  repository. Point out code quality, design soundness, potential bugs, and
  improvements."
- **Consult on a design**: "Give me your opinion on the following design. [design
  summary]. Suggest alternatives and trade-offs if any."
- **Consult on an implementation approach**: "I want to implement [task summary].
  Given this repository's codebase, propose the best implementation approach."

### Prompt structure

1. Project background (briefly).
2. The specific question to consult on.
3. The consulting agent's current draft view (include when useful; always include in
   "fully" mode).
4. A request to explore broadly beyond the stated angles (always include).

#### Template when including the consulting agent's draft view

```
For reference, the consulting agent ([your agent name]) currently thinks:
- [draft view]

Review broadly, including gaps or errors in this view.
If anything beyond the stated angles concerns you, report it proactively.
```

#### Broad-exploration request (always include in the prompt)

The stated angles are a starting point, not a constraint. Always include a request
that the subagent explore the repo itself and proactively report anything that
concerns it.

## 3. Choose the consultant and run it

### Choosing the consultant

A second opinion is worth having only to the extent that the consultant's priors are
independent of yours. Prefer, in this order:

1. **A different model family.** Independent training, so independent priors. The
   strongest second opinion, and the one to pick when you may be systematically wrong
   rather than merely under-informed: correctness, security, "is this explanation
   actually true".
2. **The same family on a strong model, in a fresh session.** Independent context,
   shared priors. Enough when the job is reading the repository — conventions, naming,
   where something is implemented — rather than judging whether it is right.
3. **Whatever subagent/task mechanism the host has**, when neither of the above exists.

A consultation is judgment work: use a model capable of that judgment.

A cross-family consultant costs more to use. It cannot see this conversation, its tool
access and permissions differ, and a round-trip is slower. Write the prompt to stand
completely on its own (section 2 already requires this).

If whoever invoked this skill stated which kind of consultant the task needs, follow
that. See "Platform implementations" below for what actually exists on this host.

### Launching

Launch the consultant with the mechanism its tier uses on this host ("Platform
implementations" below). For an Agent-tool consultant:

- `prompt`: the prompt designed in section 2.
- `description`: a 3-5 word summary of the consultation.

### Consultation failure vs. execution degradation

A consultation ends in one of two ways, and they call for opposite responses.

A **consultation failure** is the absence of an answer: the consultant's CLI is not
installed, the run hit its time bound, the process exited non-zero, or the output says
only that it could not proceed. There is nothing to digest, and the fallback is yours,
not the adapter's — an execution adapter reports the failure and stops there. Move down
the preference order to the next available consultant and run the same consultation
there. If none is left, say so and give your own view alone. Either way, state in the
report which consultant answered, and which one failed and how.

A **usable result with execution degradation** is a real answer from a run where some
command failed — a fetch, a test, a build, a diagnostic. Do not fall back on that one.
Use the answer, and handle the gap as section 4's "If you detect a subagent execution
failure" describes.

### Deciding on a second round-trip

In **fully** mode, after the first round, do a second round as a rule. Skip only when
no further depth is clearly needed (the first round already covered things
thoroughly).

In **well** mode, after the first round, do a second round if any of these hold:

- The subagent's points contain an important thread worth digging into.
- The consulting agent wants to rebut or supplement the subagent's points.
- The consulting agent judges some area was under-explored.

Before deciding on a second round, check the first round's output for signs of
execution failure (error messages, "could not fetch", "failed", "permission denied",
"not found"). If you detect a failure, the consulting agent first fetches/corrects the
right information, then decides whether a second round is needed (see section 4, "If you
detect a subagent execution failure").

Second-round prompt structure.

**Continue the same consultant instead of launching a new one.**
When the host can continue the same consultant with its context intact, send only the delta:

1. The consulting agent's rebuttals / supplements / follow-up questions.
2. Angles to dig into further.

Only when the consultant cannot be continued, restate everything from scratch: the original consultation (background / goal / constraints / evaluation angles, structured, nothing dropped), a summary of the first-round answer, and then the two items above.

Round-trips are 2 at most as a rule. For a third or more, confirm with the user first.

## 4. Summarize and report

Read the subagent's output and report to the user in this structure:

### Report structure

#### What was consulted

Explain the prompt sent to the subagent in 1-2 sentences.

#### Subagent's answer summary

Summarize the subagent's main points and proposals as a bullet list.

#### [Your agent name]'s view

- Points you agree with.
- Points you disagree with (with reasons).
- Points you think the subagent missed.
- If you did a second round, why, and what it revealed.

**Stance:**

- Do not accept the subagent's points uncritically. Try to verify as the consulting
  agent before reporting.
- Deliberately look for areas the subagent may not have explored.
- When your view and the subagent's diverge, surface the divergence as valuable
  information.

#### Suggested next actions

Show what to discuss with the user, or the recommended next step.

### Reporting style

- Keep it concise. Avoid verbose quoting.
- When views differ, explain both sides' reasons so the user can decide.
- Make clear what the user should do next.

### If you detect a subagent execution failure

When reading the subagent's output, check carefully for signs of failure. Examples:
error messages, "could not fetch", "failed", "permission denied", "not found".

If you detect a failure:

1. First, the consulting agent fetches the correct information itself. Run the command
   the subagent failed on (e.g. `gh pr view`) with the Bash tool and check the result.
2. Then correct the subagent's analysis with the fetched information. Identify points
   that went off-target from missing info and re-evaluate them in correct context.
3. Finally, state the missing info explicitly in the view section of the report.
   Describe the missing info and which points it affected.

## 5. Improvement suggestions

If you recognize a pattern where the subagent failed, suggest improvements for next
time to the user.

## Platform implementations

### Claude Code

The two tiers are reached by different mechanisms:

- **Different family**: the Codex CLI, through the `codex-consultation` skill (Skill
  tool), when that skill is installed and `codex` is on PATH. This skill owns prompt
  design and synthesis; `codex-consultation` is only the Codex-specific execution
  adapter. Supply it with the complete prompt, the target worktree's absolute path,
  whether tests/builds/diagnostics may be required, and whether remote information is
  required. It runs Codex in the foreground and returns a usable answer or a consultation
  failure within that one call; it never hands back a job to collect later.
- **Same family**: the `Agent` tool with `subagent_type: general-purpose`,
  `model: opus` (or `fable`). A fresh session with no memory of this conversation.

Do not consult the `search` agent: it is a task delegate for bounded work, not a consultant responsible for an independent judgment.

For a same-family consultant, address `SendMessage` to the consultant's ID or name
for the second round. A fresh `Agent` call starts cold.

Codex cannot be continued. `codex exec` is single-shot and `codex-consultation` keeps
no thread, so a second Codex round is a fresh call carrying the full restatement
described in section 3 ("Only when the consultant cannot be continued...").

### Codex

Codex has no single tool named `Agent`, but it may expose the subagent workflow through separate operations: spawn a thread, send follow-up work and start a turn, wait for it, list the running threads, and stop one when supported.
Agent threads run separately, and the parent thread waits for their results and integrates them.
Builds may also expose agent inspection through `/agent` and definitions through the `agents_dir` config (`$CODEX_HOME/agents/*.toml`).

**Read the tool names off the Codex you are actually running, not off this file.**
They differ between builds, and similar-looking operations may have different semantics.
For example, in some builds `followup_task` starts a turn for an idle agent while `send_message` only delivers a message and does not start one.
Select by the tool description, not by the name.

Spawn the consultant on a strong model.
For the second round, use the operation that starts or resumes a turn for the same agent.
Merely delivering a message to an idle agent is not enough.
If another vendor's CLI is installed, that is the different-family consultant (tier 1).
A Codex agent thread with no project context loaded is tier 2.
