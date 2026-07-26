---
name: grilling
description: >-
  Grill the user about a plan, decision, or idea — one question at a time, with a
  recommended answer for each — until a shared understanding is reached. Use when the
  user wants to stress-test their thinking before implementation, or says "grill me",
  "interview me", or "要件を詰めて".
---

# Grilling procedure

Interview the user thoroughly about every aspect of the plan, decision, or idea until
you reach a shared understanding. Walk down each branch of the decision tree, resolving
dependencies between decisions one by one.

Rules:

- Ask the questions **one at a time**, waiting for feedback on each question before
  continuing. Asking multiple questions at once is bewildering.
- For each question, provide your **recommended answer**.
- If a **fact** can be found by exploring the environment (filesystem, tools, git
  history, etc.), look it up yourself rather than asking. The **decisions**, though,
  are the user's — put each one to them and wait for their answer.
- Do not act on the plan until the user confirms you have reached a shared
  understanding.

## Record what settles, as it settles

A grilling that leaves no trace evaporates when the session ends. So while the interview
runs, write down the two things that outlive it — via `domain-modeling`, which owns both:

- **A term, the moment it is pinned down** → the `CONTEXT.md` glossary.
- **A decision that is hard to reverse, surprising without context, and the result of a
  real trade-off** → an ADR. All three, or skip it; most sessions produce few or none.

Write these inline, not batched at the end. The end is exactly where a long interview
runs out of room.

Everything else the session produced — the approach, the alternatives you turned down,
what is left to do — goes to `conversation-context-export` when you finish.

## Related skills

- **domain-modeling**: the record tier. Owns the glossary and the ADRs this skill feeds.
- **spec-ambiguity-audit**: audits a written spec for gaps with a cold-reading cheap
  model. Grilling is the interactive counterpart: it resolves the open
  decisions with the user directly.
- **conversation-context-export**: once the shared understanding is reached, export it
  so the next session inherits the decisions.
