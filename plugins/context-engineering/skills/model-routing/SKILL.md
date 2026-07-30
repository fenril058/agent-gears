---
name: model-routing
description: >-
  Use when handing mechanical, high-volume work (bulk edits, formatting, boilerplate replacement) or a broad read-heavy investigation to a cheaper-model subagent — whether the user asked for the delegation, or usage is metered per token so the tier split actually pays.
  Defines what may be delegated, what must stay on the main session, and how to write the brief, plus when delegation does not pay off at all.
---

# Model Routing (delegation policy)

**Delegation is not a default behavior.**
Consider it when the user asks for it, or when the billing model makes the tier split genuinely pay.
In either case, the host's instructions must authorize the spawn; an economic reason never overrides them.

Two conditions gate the older "delegate whatever can be delegated, to cut tokens" advice:

- Hosts increasingly discourage unprompted subagent spawning, because a spawn starts cold and re-derives context the main session already holds.
  Check the host's own instructions before self-initiating.
- The saving assumes the token price differs by tier.
  On a flat-rate plan the constraint is a rate limit, not a price, so a cheaper tier buys nothing and the cold start costs extra.
  Where usage is metered per token, the saving is real and self-initiating can be worth it when the host permits that behavior.

So the criteria below govern *how* to delegate once delegation is on the table, not whether to reach for it on your own.

## What may be delegated

- The work can be specified in one sentence and correctness can be judged mechanically.
- It's a cross-file search but all you want is the conclusion (location / summary).
- It's repetition of the same operation, in volume.

## What stays on the main session

- You're still deciding *what* to do (design, direction).
- The cost of failure is high and the judgment needs contextual nuance.
- It's short and the delegation overhead would exceed the work itself.
  Don't delegate a trivial task just because it's "mechanical".
- A second opinion.
  That is judgment work and belongs on a strong model; see `subagent-consultation`.
  Never route it to a cheap-tier delegate.

## Writing the brief

Delegation keeps the read-heavy intermediate context out of the main session only if the delegate returns the conclusion, not a transcript of what it read.

Always fill in these three.
Otherwise the delegate fills the gaps at its own discretion and the result drifts:

- **Scope**: what / which set of files to handle. Write the exclusions too.
- **Expected deliverable**: what should exist when it's done.
- **Return format**: one of — diff / cited summary (`path:line`) / list of changed files.

Tell the delegate to return the conclusion only, and to read large Markdown by section
(mdidx) rather than in full, so its own context stays cheap as well.

## Platform implementations

### Claude Code

Claude Code cannot auto-switch the main session's model from a skill or hook, so the delegation is done explicitly via the Task/Agent tool.
Start it only when the user asked for delegation or the host explicitly permits self-initiated delegation under the metered-usage condition above.
This repo ships two delegate agents (defined in `agents/`, placed in `~/.claude/agents/`); call them by name in `subagent_type`:

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

Codex has the same shape under different names, so the tier split works there too.
Agents are defined under the `agents_dir` config (`$CODEX_HOME/agents/*.toml`) rather than `agents/*.md`, launched with a spawn-subagent tool rather than the Agent tool, and inspected with `/agent`.
Per-agent model overrides exist where the build enables them.
Tool names vary between builds; read them off your Codex, not off this file.
Only the `model:` frontmatter key itself is Claude Code specific.
