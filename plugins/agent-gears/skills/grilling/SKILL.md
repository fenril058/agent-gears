---
name: grilling
description: >-
  Grill the user about a plan, decision, or idea — one question at a time, with a recommended answer for each — until a shared understanding is reached.
  Use when the user wants to stress-test their thinking before implementation, or says "grill me", "interview me", or "要件を詰めて".
---

# Grilling procedure

Interview the user thoroughly about every aspect of the plan, decision, or idea until you reach a shared understanding.
Explore every relevant aspect, resolving dependencies between decisions one by one.

Rules:

- Ask questions **one at a time**, waiting for feedback before continuing.
- For each question, provide your **recommended answer**.
- Look up **facts** available in the environment (files, tools, Git history) yourself.
  Put **decisions** to the user and wait for their answer.
- Before asking about a decision, resolve every decision it depends on.
  Do not ask a question whose answer depends on an unresolved prerequisite decision.
- When unresolved decisions are independent, do not invent dependencies between them or make one wait on the other's answer.
- Before asking the user to confirm the shared understanding, check that no unresolved decision or silently assumed decision remains.
  If any remains, surface and resolve it one question at a time.
- Do not implement the plan until the user confirms the shared understanding.
  If implementation was already requested, proceed after that confirmation without asking for a separate start approval.
  Confirmation alone does not turn a consultation into an implementation request.

## Record what settles, as it settles

Determine whether recording is part of the task from the request, conversation, and project instructions.
A consultation alone does not require file changes or a question about recording; ask only when missing information affects the requested work.
Honor instructions to leave files unchanged.

When recording is entrusted to you, use `domain-modeling` to save agreed terms and qualifying decisions as they settle, without waiting for agreement on the whole plan or asking for the same recording permission per item.
Keep tentative names and options under discussion distinct from agreed terms and adopted decisions.
Recording permission does not authorize implementation, commit, push, or external posting; follow the scope already established for each action.

## Finish within the requested scope

Summarize the shared understanding, rejected alternatives, and remaining work in the conversation.
Use `conversation-context-export` when the request or established handoff intent calls for saving that context.
Apply its local-save default and sharing rules: local-only stays local, and a PR's existence does not authorize sharing.
Do not ask again for saving or sharing already authorized for this export.

## Related skills

- **domain-modeling**: owns the glossary and ADRs when recording is part of the task.
- **spec-ambiguity-audit**: audits a written spec for gaps with a cold-reading cheap model.
  Grilling resolves the open decisions with the user directly.
- **conversation-context-export**: save context for handoff when called for by the task.
