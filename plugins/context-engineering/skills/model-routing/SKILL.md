---
name: model-routing
description: Use when you want to save tokens by delegating high-volume but low-judgment work (bulk edits, formatting, boilerplate replacement) or broad search / investigation to a cheaper-model subagent. Keeps design decisions and reasoning on the strong main model and pushes mechanical, repetitive work down to a cheaper model. Defines the criteria for what to delegate.
---

# Model Routing (delegation policy)

The most effective lever for cutting tokens is to delegate the work that *can* be
delegated to a cheaper model.

## General policy

Think in capability tiers, not in specific model names:

- **Strong tier (keep on the main session)**: design decisions, reasoning, resolving
  ambiguity, weighing trade-offs, final review. Lowering capability here degrades quality.
- **Cheap tier (delegate to a subagent)**: mechanical, high-volume work, and broad
  read-heavy search / investigation. Quality is not capability-bound here, so paying for
  the strong tier is waste.

The shape is always the same: **keep heavy thinking on the strong model and push
mechanical, high-volume work out to a cheaper subagent.** The per-platform mechanics
(how a subagent is launched, whether the model can be switched mid-session) differ —
see *Platform implementations* below.

## Delegation criteria

Delegate when:

- The work can be specified in one sentence and correctness can be judged mechanically.
- It's a cross-file search but all you want is the conclusion (location / summary).
- It's repetition of the same operation, in volume.

Keep on the main session when:

- You're still deciding *what* to do (design, direction).
- The cost of failure is high and the judgment needs contextual nuance.
- It's short and the delegation overhead would exceed the work itself.

When both signals fire (e.g. mechanical but low-volume), keep it on the main session if
the delegation overhead (writing the brief, launching, collecting the result) exceeds the
actual work. Don't delegate trivial tasks just because they're "mechanical".

## Context minimization

Delegation cuts tokens twice: the cheaper tier does the work, *and* the read-heavy
intermediate context stays out of the main session. To get the second saving, the
delegate must return only the conclusion — not a transcript of what it read.

When delegating, always fill in these three. Otherwise the delegate fills the gaps at its
own discretion and the result drifts:

- **Scope**: what / which set of files to handle. Write the exclusions too.
- **Expected deliverable**: what should exist when it's done.
- **Return format**: one of — diff / cited summary (`path:line`) / list of changed files.

Tell the delegate to return the conclusion only, and to read large Markdown by section
(mdidx) rather than in full, so its own context stays cheap as well.

## Platform implementations

### Claude Code

Claude Code cannot auto-switch the main session's model from a skill or hook, so the
delegation is done explicitly via the Task/Agent tool. This repo ships two delegate
agents (defined in `agents/`, placed in `~/.claude/agents/`); call them by name in
`subagent_type`:

- **`bulk-edit` (cheap tier)**: clearly specified work that requires no judgment —
  bulk renames, formatting, boilerplate string replacement, template expansion,
  repetitive edits.
- **`search` (mid tier)**: codebase exploration / summary / investigation (including
  running fastcontext), and medium-sized implementations whose approach is already clear.

Example brief (bulk rename to `bulk-edit`):

> subagent_type: bulk-edit
> Scope: the identifier `foo_bar` across the whole repo (word-boundary matches only; exclude partial matches and occurrences inside comments)
> Work: mechanically replace with `fooBar`. Don't change behavior. Leave ambiguous spots unreplaced and report them.
> Return: a list of changed files and a count of replacements (no diff needed).

Example brief (investigation to `search`):

> subagent_type: search
> Scope: where rate limiting is implemented (middleware / decorator / config / counter)
> Expected deliverable: a summary of the mechanism, limit values, scope of application, and key files
> Return: a concise summary with citations (`path:line`). No need to transcribe full code.

### Codex

Agent definitions (`model:`) are Claude Code specific. On Codex, follow this skill's
*General policy* and *Delegation criteria*, and use Codex's own model setting (`/model`
etc.) to split heavy vs. light work.
