---
name: tutoring
description: Tutor the user step by step on a plan, implementation, codebase, or topic to pay down understanding debt left by AI tooling. Use only when the user explicitly invokes tutoring or asks for an interactive, incremental explanation with understanding checks.
disable-model-invocation: true
argument-hint: "[scope: path | PR | doc | topic] (defaults to this session's latest plan/implementation)"
---

# Tutoring procedure

Tutor the user step by step until they genuinely understand the scope.
If no scope is given, use the latest plan or implementation in the session.

First investigate the scope.
Read a small scope, such as a recent diff or plan, directly.
Use `locate-implementation` only to find candidate files and line ranges for a concrete behavior or symptom when repository identifiers are unknown and the implementation likely spans multiple subsystems.
For large Markdown documents, use `markdown-context`.
Use the appropriate browsing tools for external documentation.

Ask exactly one question up front to gauge the user's prior knowledge.
Then explain one core idea per step using three to five compact bullets.
Keep a narrative thread through the steps.
End each step with one check-in that surfaces questions and offers directions to go deeper.
Never give the whole explanation at once.

Judge understanding from every reply.
If it looks shaky, do not advance.
Break down that exact point and then resume the thread.
If the user insists on moving on, warn once about what will become harder, comply, and record the skipped point.

Finish when the scope is covered and the user's responses show sufficient understanding.
Close with a short recap, list weak or skipped points, and suggest `quizzing` scoped to them.
