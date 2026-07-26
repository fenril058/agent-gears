---
name: domain-modeling
description: >-
  Build and sharpen this project's domain model, and record what gets settled — the
  vocabulary into a CONTEXT.md glossary, the hard-to-reverse decisions into ADRs. Use when
  pinning down terminology or a ubiquitous language, when an architectural decision needs
  recording, or when another skill (grilling, to name the usual one) needs the model
  maintained as it works. Triggers: "write this up as an ADR", "record this decision",
  "pin down the terminology", "what do we call this".
---

# Domain modeling procedure

Actively build and sharpen the project's domain model as you design, and write down what
crystallises the moment it does.

This is the **active** discipline. Reading `CONTEXT.md` to borrow its vocabulary is a
one-line habit any skill can do; this skill is for when you are *changing* the model —
coining a canonical term, catching a contradiction between the code and what was just
said, recording a decision that will be hard to reverse.

## Which tier is this

This is the **record tier**: artifacts committed alongside the code they describe, and
immutable once written. Two sibling tiers exist, and the distinction is the **update
model**, not the location.

| Tier | Sink | Update model |
| --- | --- | --- |
| Ephemeral (`conversation-context-export`) | `.dev/contexts/` + PR comment | regenerated per branch, never committed |
| **Record (this skill)** | `CONTEXT.md`, ADR directory | **append and supersede; never rewritten** |
| Durable (`durable-knowledge-export`) | GitHub wiki or knowledge repo | living page, always current |

What belongs here and nowhere else: **this codebase's vocabulary**, and **decisions whose
reversal you would want a record of**. A decision stored in a living page loses the fact
that it was ever decided differently — that loss is the whole reason this tier exists.

Route out, don't absorb:

- Rationale for *this* change, remaining work, one-off debugging → ephemeral tier.
- Measurements, tool evaluations, cross-cutting gotchas about the system → durable tier.

## During the session

### Challenge against the glossary

When a term conflicts with the existing language in `CONTEXT.md`, call it out immediately.
"Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When a term is vague or overloaded, propose a precise canonical term. "You're saying
'account' — do you mean the Customer or the User? Those are different things."

This is the project-internal counterpart to `no-neologism`, and the two pull in opposite
directions on purpose. `no-neologism` governs **terms of art**: use the field's
established word, don't coin your own. This skill governs **the ubiquitous language**:
within one project, pick one canonical word for one concept and be opinionated about it.
When a field-standard term exists, it wins and becomes the canonical one; the opinionated
choice only applies among words the field leaves equally open.

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios
that probe edge cases and force precision about the boundaries between concepts.

### Cross-reference with code

When someone states how something works, check whether the code agrees. If you find a
contradiction, surface it: "Your code cancels entire Orders, but you just said partial
cancellation is possible — which is right?"

### Write inline, not batched

When a term resolves, update `CONTEXT.md` right then. When a decision meets the bar
below, write the ADR right then. Batching to the end of the session is how the record
gets lost — the session ends, or context runs out, and what was settled evaporates.

## The glossary

`CONTEXT.md` is a glossary and nothing else. No implementation details, no spec, no
scratch pad. Format and single-vs-multi-context layout: [CONTEXT-FORMAT.md](CONTEXT-FORMAT.md).

Create it lazily — the first resolved term creates the file.

## ADRs

Offer one only when **all three** hold:

1. **Hard to reverse** — the cost of changing your mind later is meaningful.
2. **Surprising without context** — a future reader will wonder "why did they do it this
   way?"
3. **The result of a real trade-off** — there were genuine alternatives and one was picked
   for specific reasons.

If any is missing, skip it. Easy to reverse → you'll just reverse it. Not surprising →
nobody will wonder. No real alternative → there is nothing to record beyond "we did the
obvious thing."

Most sessions produce a sharper glossary and few or no ADRs. That is the intended shape.

Numbering, superseding, and the template: [ADR-FORMAT.md](ADR-FORMAT.md).

### Resolve the ADR directory

**Do not assume `docs/adr/`.** An existing repo usually already has a convention, and
writing to the wrong place splits the record in two. Resolve it in this order:

1. **An existing ADR directory.** Look for `docs/adr/`, `doc/adr/`, `docs/decisions/`,
   `docs/architecture/decisions/`, `adr/`. If one holds ADRs, use it — and read a couple
   of existing files to match their numbering, front matter, and heading style rather than
   imposing the template.
2. **A tool's configuration.** `.adr-dir` (adr-tools) holds the directory path;
   `.log4brains.yml` (Log4brains) names it under its project settings.
3. **Neither** → default to `docs/adr/`, create it, and tell the user you did and why.

State the resolved directory before writing the first ADR.

## Related skills

- **grilling**: the interview that produces most of what gets recorded here. It settles
  the decisions with the user; this skill writes them down as they settle.
- **conversation-context-export**: the ephemeral tier. When a decision is recorded as an
  ADR, that skill keeps a summary and a link rather than duplicating the reasoning — a
  reviewer reads the context first and follows the link.
- **durable-knowledge-export**: the durable tier, outside the repo. Cross-cutting
  knowledge about the system goes there, not into an ADR.
- **no-neologism**: field-standard terminology. See "sharpen fuzzy language" above for how
  the two divide.
