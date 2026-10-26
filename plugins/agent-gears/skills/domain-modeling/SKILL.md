---
name: domain-modeling
description: >-
  Clarify this project's domain language and architectural decisions; record agreed vocabulary in CONTEXT.md and qualifying decisions in ADRs when recording is part of the task.
  Use when pinning down this project's terminology or ubiquitous language, for "write this up as an ADR" or "record this decision", or for recording delegated by another skill such as grilling.
  Discussing a term alone does not authorize file edits.
---

# Domain modeling procedure

Clarify the project's concepts and record agreed terms and decisions within the requested scope.
Merely reading `CONTEXT.md` to use its existing vocabulary does not require this skill.

## Requested scope

Determine whether file recording is entrusted to you from the request, conversation, and project instructions, including when another skill calls this one.
A terminology discussion alone does not require file edits or routinely asking for recording permission; clarify only missing information needed for the requested work.
Honor instructions to leave files unchanged.

When recording is entrusted to you, save agreed items as they settle without asking for the same permission per item or waiting for agreement on the whole plan.
A direct request to record a settled decision does not require a grilling interview or whole-plan confirmation.
Do not record tentative names or unresolved or withdrawn options as canonical terms or adopted decisions.
Recording permission does not authorize implementation, commit, push, or external posting; follow the scope already established for each action.

## Which tier is this

This is the **record tier**: artifacts that belong in the same version history as the code they describe, preserved by appending and superseding.
The distinction from the two sibling tiers is the **update model**, not the location.

| Tier | Sink | Update model |
| --- | --- | --- |
| Ephemeral (`conversation-context-export`) | `.dev/contexts/`; PR comment when sharing is requested or authorized | regenerated per branch, never committed |
| **Record (this skill)** | `CONTEXT.md`, ADR directory | **append and supersede; never rewritten** |
| Durable (`durable-knowledge-export`) | GitHub wiki or knowledge repo | living page, always current |

This tier holds **this codebase's vocabulary** and **decisions whose reversal you would want a record of**.
A decision stored in a living page loses the fact that it was ever decided differently.

Route out, don't absorb:

- Rationale for *this* change, remaining work, one-off debugging → ephemeral tier.
- Measurements, tool evaluations, cross-cutting gotchas about the system → durable tier.

## During the session

Surface conflicts with existing glossary definitions and clarify vague or overloaded terms.
Use established terms of art; choose a canonical word for each project concept only among alternatives the field leaves open.
Check domain boundaries with concrete scenarios and compare claims about current behavior with the code; surface contradictions.

When recording is within scope, write settled terms and qualifying decisions inline rather than batching them at the end, so a long discussion does not lose them.

## The glossary

`CONTEXT.md` is a glossary, without implementation details, specifications, or scratch notes.
Format, layout, and protection of existing definitions: [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md).

Create it only when recording is within scope and the first agreed term needs saving.

## ADRs

Propose an ADR only when **all three** hold:

1. **Hard to reverse** — the cost of changing your mind later is meaningful.
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and one was picked for specific reasons.

If any is missing, do not propose an ADR yourself.
For an explicit ADR request that appears not to meet these conditions, explain which condition is missing and clarify the intended record only if needed; do not silently drop the request or reconfirm an informed choice already made.
Most sessions need few or no ADRs.

Numbering, superseding, and the template: [ADR-FORMAT.md](ADR-FORMAT.md).

### Resolve the ADR directory

**Do not assume `docs/adr/`.**
Writing to the wrong place splits the record in two.
When writing an ADR is within scope, resolve the directory in this order:

1. **An existing ADR directory.**
   Look for `docs/adr/`, `doc/adr/`, `docs/decisions/`, `docs/architecture/decisions/`, `adr/`.
   If one holds ADRs, use it and read a couple of existing files to match their numbering, front matter, and heading style rather than imposing the template.
2. **A tool's configuration.**
   `.adr-dir` (adr-tools) holds the directory path; `.log4brains.yml` (Log4brains) names it under its project settings.
3. **Neither** → default to `docs/adr/`, create it, and tell the user you did and why.

State the resolved directory before writing the first ADR.

## Related skills

- **grilling**: an interview that may delegate recording of agreed items within its task scope.
- **conversation-context-export**: saves ephemeral context when called for by the task, keeping a summary and link to recorded ADRs rather than duplicating their reasoning.
- **durable-knowledge-export**: save or update living knowledge pages when that recording is entrusted; follow its destination rules within the existing authorization scope.
