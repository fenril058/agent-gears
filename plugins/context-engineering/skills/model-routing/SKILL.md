---
name: model-routing
description: Use when you want to save tokens by delegating high-volume but low-judgment work (bulk edits, formatting, boilerplate replacement) or broad search / investigation to a cheaper-model subagent. Keeps design decisions and reasoning on the main model (Opus) and pushes mechanical, repetitive work down to Haiku/Sonnet. Defines the criteria for what to delegate.
---

# Model Routing (delegation policy)

The most effective lever for cutting tokens is to delegate the work that *can* be
delegated to a cheaper model.

**Key constraint**: Claude Code cannot auto-switch the main session's model from a
skill/hook. So instead of "automatically lowering the model", **keep heavy thinking
on the main model (Opus) and push mechanical, high-volume work out to subagents**.
Delegate via the Task/Agent tool.

## Where to delegate

- **Haiku — `bulk-edit` agent**: clearly specified work that requires no judgment.
  Bulk renames, formatting, boilerplate string replacement, template expansion, repetitive edits.
- **Sonnet — `search` agent**: codebase exploration / summary / investigation (including
  running fastcontext), and medium-sized implementations whose approach is already clear.
  Have it return only the conclusion so it doesn't pollute the main context.
- **Opus (keep on main)**: design decisions, reasoning, resolving ambiguity, weighing
  trade-offs, final review. Lowering the model here degrades quality.

## Criteria

Delegate when:
- The work can be specified in one sentence and correctness can be judged mechanically.
- It's a cross-file search but all you want is the conclusion (location / summary).
- It's repetition of the same operation, in volume.

Keep on main when:
- You're still deciding *what* to do (design, direction).
- The cost of failure is high and the judgment needs contextual nuance.
- It's short and the delegation overhead would exceed the work itself.

When both signals fire (e.g. mechanical but low-volume), keep it on main if the
delegation overhead (writing the brief, launching, collecting the result) exceeds the
actual work. Don't delegate trivial tasks just because they're "mechanical".

## How to use (Claude Code)

`bulk-edit` / `search` are defined in this repo's `agents/` and placed in
`~/.claude/agents/`. Call them via the Task/Agent tool with the name in `subagent_type`.
When delegating, always fill in these three (otherwise the delegate fills gaps at its
own discretion and results drift):

- Scope: what / which set of files to handle. Write the exclusions too.
- Expected deliverable: what should exist when it's done.
- Return format: one of — diff / cited summary / list of changed files.

Example brief (bulk rename to bulk-edit):

> subagent_type: bulk-edit
> Scope: the identifier `foo_bar` across the whole repo (word-boundary matches only; exclude partial matches and occurrences inside comments)
> Work: mechanically replace with `fooBar`. Don't change behavior. Leave ambiguous spots unreplaced and report them.
> Return: a list of changed files and a count of replacements (no diff needed).

Example brief (investigation to search):

> subagent_type: search
> Scope: where rate limiting is implemented (middleware / decorator / config / counter)
> Expected deliverable: a summary of the mechanism, limit values, scope of application, and key files
> Return: a concise summary with citations (`path:line`). No need to transcribe full code.

## Other agents (Codex etc.)

Agent definitions (`model:`) are Claude Code specific. On Codex, follow this skill's
criteria and use Codex's own model setting (`/model` etc.) to split heavy vs. light work.
