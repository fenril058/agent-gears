---
name: quizzing
description: Quiz the user on a plan, implementation, or codebase to pay down understanding debt left by AI tooling. Use only when the user explicitly invokes quizzing or asks to have their understanding tested one question at a time.
disable-model-invocation: true
argument-hint: "[scope: path | PR | doc | topic] (defaults to this session's latest plan/implementation)"
---

# Quizzing procedure

Quiz the user on the scope until they can explain it in their own words.
If no scope is given, use the latest plan or implementation in the session.

First investigate the scope.
Read a small scope, such as a recent diff or plan, directly.
For broad semantic exploration across a large or unfamiliar codebase, use `fast-search`.
For large Markdown documents, use `markdown-context`.
Use the appropriate browsing tools for external documentation.

Ask one open-ended question at a time.
Mix three angles:

- Why: design decisions and rejected alternatives.
- How: behavior, data flow, and structure.
- What if: change impact and edge cases.

Favor why for plans and how or what-if for code.
Never reveal the answer before the user attempts one.

After each answer:

- Confirm what is right.
- Correct what is wrong.
- Fill what is missing.
- Drill deeper where the answer is weak.
- Advance where the answer holds up.

Finish when the scope is covered and the user's answers hold up.
Summarize the remaining weak spots for later review.
