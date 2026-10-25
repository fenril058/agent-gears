---
name: agent-instructions-refine
description: Review or simplify persistent agent instruction files such as AGENTS.md or CLAUDE.md. Favor concise, project-specific rules over codebase summaries while preserving non-obvious constraints and the user's intended behavior.
---

# Refine Agent Instructions

Prefer instructions that change a project decision over descriptions of how the code works.
Preserve the user's intended behavior and conventions; shortening the file is secondary.

## Decide what belongs

Read the target file and the imports, local conventions, and decisions relevant to the proposed edits.
Check sources where they affect a keep, cut, or rewrite decision; an editing task does not require an exhaustive repository audit.

- Keep project-specific constraints, departures from tool defaults, ownership boundaries, and prerequisites that affect how work should proceed.
  Keep easy-to-miss follow-up edits and compatibility conditions even when they can be reconstructed from code.
  Derivability alone is not a reason to delete a useful reminder.
- Remove generic advice, duplicate explanations, and codebase inventories that add no decision guidance.
  Link to maintained documentation for detail, keeping the rule and any rationale needed to apply it correctly.
- Check a suspected stale rule against its source before deleting it.
  A mismatch with current code can mean an implementation defect or an intentional constraint; it does not by itself revoke the rule.
  If a safeguard's purpose remains uncertain after a focused check, retain it and note the uncertainty.
  Ask only when an unresolved choice materially changes the intended behavior and cannot be settled from the request or available evidence.

Rewrite retained rules as specific actions with their conditions and scope: for example, “When changing X, also update Y.”
Do not widen a local rule into a universal one or remove exceptions while compressing it.
Follow the document's conventions and group related rules; avoid a mandatory classification for every line.

## Keep editing within scope

If a failure prompted the review, check as needed whether the instruction was loaded, applicable, current, or in conflict before attributing the failure to its wording or length.
A repeated mistake or an already-answered question is a reason to investigate, not a diagnosis.

Document cleanup does not itself call for creating skills, hooks, or settings.
Make such changes only when the task and existing authorization cover them.
When changing where instructions live or how checks run, verify the affected host's loading and execution behavior rather than assuming conditional loading or enforcement.
For Claude Code, consult the official [memory](https://code.claude.com/docs/en/memory) and [hooks](https://code.claude.com/docs/en/hooks) documentation when those mechanisms are relevant.

## Check and report

Review the diff for lost constraints, changed scope, conflicting rules, and broken references.
Run existing checks relevant to the changed files.
Summarize consequential edits and their reasons, plus any unresolved choices; do not require a report for every removed line or default to line and token counts.
Reduced length and static checks do not establish better agent behavior; state whether behavior under the revised instructions was observed.

Use `empirical-prompt-tuning` only when explicitly asked for an empirical evaluation or a description/body consistency check.
Ordinary instruction editing does not trigger it or require a new evaluation runner.
