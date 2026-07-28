---
name: navigating
description: Navigate the user through reading code stop by stop to pay down understanding debt left by AI tooling. Use only when the user explicitly invokes navigating or asks for a guided code-reading tour in which they read and explain the code themselves.
disable-model-invocation: true
argument-hint: "[scope: path | PR | feature | topic] (defaults to this session's latest implementation)"
---

# Navigating procedure

Navigate the user through the scope until they can find their own way around it.
If no scope is given, use the latest implementation in the session.
Let the user do the reading; never explain code they have not read yet.

First investigate the scope.
Read a small scope, such as a recent diff or plan, directly.
For broad semantic exploration across a large or unfamiliar codebase, use `fast-search`.
For large Markdown documents, use `markdown-context`.
Use the appropriate browsing tools for external documentation.

Chart a route and show the itinerary up front:

- Give a brief overview of how the pieces fit together.
- List ordered stops, each with a file and line range plus a one-line purpose.
- Put entry points and core data structures before the flows that use them.
- Put main flows before edge cases and details.
- Mark stops that include a safe test, CLI command, or small probe.

Keep the overview as a map rather than the tour.
At each stop, give the range and one focus question about a behavior, state, or decision.
Wait for the user to read it and answer in their own words.

Grade each answer directly:

- Confirm what is right.
- Correct what is wrong.
- Fill what is missing.
- Decompose a dense construct only after the user has attempted to explain it.

For an executable stop, ask the user to predict the outcome first.
Then have them run it and reconcile the result with the prediction.

If an answer is shaky, do not advance.
Narrow the range, ask a sharper question, and have the user reread it.
Explain only if they are still stuck after the reread.
Split a stop when needed and keep the itinerary current.

Finish when the route is complete and the user's answers hold up.
Close with compact nested bullets containing:

- One bullet per stop, with at most one deeper level.
- The reading pattern that transfers to similar code.
- The stops where the user struggled.
- A ready-to-paste invocation of `quizzing` scoped to those stops.
