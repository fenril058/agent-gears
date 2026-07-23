---
name: decision-interview
description: >-
  Interview the user about a plan, decision, or idea — one question at a time, with a
  recommended answer for each — until a shared understanding is reached. Use when the
  user wants to stress-test their thinking before implementation, or says "interview
  me", "grill me", "壁打ちして", or "詰めて".
---

# Decision interview procedure

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

## Related skills

- **spec-ambiguity-audit**: audits a written spec for gaps with a cold-reading cheap
  model. The decision interview is the interactive counterpart: it resolves the open
  decisions with the user directly.
- **conversation-context-export**: once the shared understanding is reached, export it
  so the next session inherits the decisions.
