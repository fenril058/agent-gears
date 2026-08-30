---
name: agent-instructions-refine
description:  Review and refine an agent instruction file (such as CLAUDE.md or AGENTS.md) to keep it concise, high-signal, and easy for the agent to follow. Remove information that can be derived from the code, preserve essential project guidance, and rewrite the remainder as terse, testable, imperative rules.
---

# Refine Agent Instructions

Agent instruction files (e.g., CLAUDE.md or AGENTS.md) compete for the agent's limited attention.
A bloated file doesn't just cost tokens—it buries the rules that matter.
Keep them small and high-signal: include only broadly applicable guidance and information the agent cannot derive on its own.
Move everything else to skills, imported files, or other documentation.

These principles apply to any persistent agent instruction file, including CLAUDE.md, AGENTS.md, and equivalent files.

## The test

For every line ask: **"If I delete this, will the agent get something wrong?"**
If not, cut it. That single question drives every keep/cut decision below.

## Keep vs cut

| Keep (can't be derived; applies broadly) | Cut (derivable, generic, or volatile) |
| --- | --- |
| Bash commands the agent can't guess — the **exact** command, not a description (`pytest -v --no-header`, not "run the tests") | Anything the agent can learn by reading the code |
| Code style that differs from defaults, as concrete rules ("validate with Zod, never raw types"; "API routes go through `/lib/auth`") | Standard language conventions the agent already knows |
| Testing instructions, the preferred test runner, and where fixtures live | Detailed API docs — link to them instead |
| Repo etiquette: branch naming, PR / commit conventions | Information that changes frequently |
| The **rules** a project-specific architecture decision imposes ("events cross context boundaries, never synchronous HTTP") | The decision's rationale and rejected alternatives — that is an ADR (see `domain-modeling`); link it, don't retell it |
| Non-standard directory layout / conventions that deviate from the norm — the deviation, not a file-by-file tour | Self-evident advice ("write clean code") |
| **Ownership boundaries** — in a monorepo, what each service / module owns and, crucially, does **not** own | **Secrets / credentials** (API keys, passwords, tokens) — never, even in a private repo |
| Dev-env quirks (required env vars, `.env.example` location), non-obvious gotchas, easy-to-miss follow-up edits | Aspirational rules the team doesn't actually follow — the agent applies them strictly and causes friction; document what you *do* |
|  | Stale context you won't maintain — the agent follows written rules confidently, so outdated ones actively mislead |

## Where moved-out content goes

- **Sometimes-relevant** domain knowledge or a multi-step workflow → a **skill** (loaded on demand), or a **separate file referenced via `@path`** so it loads only when needed.
  Leave at most a one-line pointer in CLAUDE.md.
- **Must happen every time, deterministically** (a check that can't be left to the model's discretion) → a **hook**, not prose. Instructions are advisory; hooks are enforced.

## Procedure

1. **Inventory**: read the target file and anything it imports. Record current line count and rough token count as the "before" baseline.
2. **Classify** each line with the test above, sorting into: keep (invariant, broad, non-derivable) / move to a skill or `@`-file / convert to a hook / delete (derivable, outdated, contradicted by code, duplicated).
3. **Rewrite** what stays:
   - Imperative, specific, testable ("when you change X, also change Y" — not "be careful with X").
   - No undefined terms or ad-hoc coinages; use established terminology.
   - One sentence per line; blank line between paragraphs.
   - Group by topic with short headers.
   - Reserve emphasis (IMPORTANT / YOU MUST) for the few rules that actually get
     ignored — if everything shouts, nothing does.
4. **Report**: a change summary (for each removal, why — derivable / outdated / duplicated / moved-to-skill / moved-to-hook) plus before/after line and token counts.

## Guard

Don't delete anything you can't confirm is derivable or wrong.
When unsure, flag it for the user instead of dropping it. A missing safeguard is worse than a slightly long file.

## Signals it needs refining

- The agent repeats a mistake **despite** a rule against it → the file is too long and the rule is getting lost. Prune.
- The agent asks something **already answered** in the file → the phrasing is ambiguous.
  Rewrite that line, don't add a new one.

## Combine with

- `empirical-prompt-tuning` checks instruction text. It runs only on an explicit request for an empirical evaluation or for a description / body consistency check, never automatically.
  This skill is the direct editing procedure. When an operator asks whether the slimmed file still works, [[empirical-prompt-tuning]] starts from a static description / body audit and the host's own tooling; a candidate-vs-baseline comparison happens only on explicit request, and only when its isolation conditions can be met.
- Apply the always-on rule against undefined terms while editing.
  Invoke [[no-neologism]] only when the task calls for a dedicated terminology audit.

Based on Anthropic's "Write an effective CLAUDE.md" guidance
(<https://code.claude.com/docs/en/best-practices>).
