---
name: subagent-consultation
description: >-
  Consult a subagent (the Agent tool) for a second opinion. Use when the user says
  "consult a subagent", "ask a subagent", "have a subagent review this", or similar.
  Send the subagent a prompt built from the current conversation, then digest the
  result against your own view and report a summary to the user.
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
  consult the subagent, and report to the user.
- **Consultant (subagent)**: a subagent launched via the Agent tool. It provides the
  second opinion.

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

A consultation is judgment work: run the consultant on a strong model, not a cheap
one (the cheap-model delegation criteria in the model-routing skill are for
mechanical work and do not apply to second opinions).

A cross-family consultant costs more to use. It cannot see this conversation, its tool
access and permissions differ, and it may run asynchronously. Write the prompt to stand
completely on its own (section 2 already requires this) and expect a slower round-trip.

If whoever invoked this skill stated which kind of consultant the task needs, follow
that. See "Platform implementations" below for what actually exists on this host.

### Launching

Launch the consultant via the Agent tool:

- `prompt`: the prompt designed in section 2.
- `description`: a 3-5 word summary of the consultation.

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

Second-round prompt structure:

**Note: the Agent tool is single-shot, so the second-round subagent has no memory of
the first round. Include all context from scratch.**

1. Restate the original consultation (background / goal / constraints / evaluation
   angles, structured, nothing dropped).
2. Summary of the first-round answer.
3. The consulting agent's rebuttals / supplements / follow-up questions.
4. Angles to dig into further.

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

Every consultant is reached through the `Agent` tool, by `subagent_type`:

- **Different family**: `subagent_type: codex:codex-rescue` (Codex / GPT), when the
  Codex plugin is installed. Give the target worktree's absolute path as `--cwd` in the
  request text, and read the result back with `/codex:status` and `/codex:result` from
  that same cwd — a job created with `task --cwd <path>` lives in that workspace's
  state and cannot be found from another cwd. Do not assume the session's cwd is the
  target worktree.
- **Same family**: `subagent_type: general-purpose`, `model: opus` (or `fable`). A
  fresh session with no memory of this conversation.

Do not consult the `bulk-edit` or `search` agents: they are cheap-tier delegates for
mechanical work, which is the one thing a second opinion must not be.

### Codex

Codex has no Agent tool; use its own subagent/session mechanism. If another vendor's
CLI is installed, that is the different-family consultant. Otherwise run the
consultation in a fresh session with no project context loaded — independent context,
shared priors, i.e. tier 2 above.
