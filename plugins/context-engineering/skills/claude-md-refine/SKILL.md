---
name: claude-md-refine
description: Use when reviewing or tightening a CLAUDE.md / AGENTS.md (agent instruction file) so it stays small and high-signal — it is read every turn, and bloat makes the agent ignore the rules that matter. Cuts what the agent can derive from the code, moves sometimes-relevant knowledge to skills or @-imported files, keeps test/architecture/ownership-boundary facts, and rewrites the rest as terse, testable, imperative rules. Triggers: "refine / clean up / slim down CLAUDE.md", "review my agent instructions", or the file has grown bloated.
---

# Refine CLAUDE.md (slimming an agent instruction file)

CLAUDE.md / AGENTS.md is read every turn. A bloated file doesn't just cost tokens —
it buries the rules that matter, so the agent starts ignoring them. Keep it small
and high-signal: only what applies broadly and what the agent cannot derive on its
own. Everything else moves out.

This applies to any always-loaded agent instruction file (CLAUDE.md, AGENTS.md, and
equivalents).

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
| Project-specific architecture decisions | Long explanations, tutorials, file-by-file tours |
| Non-standard directory layout / conventions that deviate from the norm — the deviation, not a file-by-file tour | Self-evident advice ("write clean code") |
| **Ownership boundaries** — in a monorepo, what each service / module owns and, crucially, does **not** own | **Secrets / credentials** (API keys, passwords, tokens) — never, even in a private repo |
| Dev-env quirks (required env vars, `.env.example` location), non-obvious gotchas, easy-to-miss follow-up edits | Aspirational rules the team doesn't actually follow — the agent applies them strictly and causes friction; document what you *do* |
|  | Stale context you won't maintain — the agent follows written rules confidently, so outdated ones actively mislead |

## Where moved-out content goes

- **Sometimes-relevant** domain knowledge or a multi-step workflow → a **skill** (loaded
  on demand), or a **separate file referenced via `@path`** so it loads only when needed.
  Leave at most a one-line pointer in CLAUDE.md.
- **Must happen every time, deterministically** (a check that can't be left to the
  model's discretion) → a **hook**, not prose. Instructions are advisory; hooks are enforced.

## Procedure

1. **Inventory**: read the target file and anything it imports. Record current line
   count and rough token count as the "before" baseline.
2. **Classify** each line with the test above, sorting into: keep (invariant, broad,
   non-derivable) / move to a skill or `@`-file / convert to a hook / delete (derivable,
   outdated, contradicted by code, duplicated).
3. **Rewrite** what stays:
   - Imperative, specific, testable ("when you change X, also change Y" — not "be
     careful with X").
   - No undefined terms or ad-hoc coinages — apply [[no-neologism]].
   - One sentence per line; blank line between paragraphs.
   - Group by topic with short headers.
   - Reserve emphasis (IMPORTANT / YOU MUST) for the few rules that actually get
     ignored — if everything shouts, nothing does.
4. **Report**: a change summary (for each removal, why — derivable / outdated /
   duplicated / moved-to-skill / moved-to-hook) plus before/after line and token counts.

## Guard

Don't delete anything you can't confirm is derivable or wrong. When unsure, flag it
for the user instead of dropping it. A missing safeguard is worse than a slightly
long file.

## Signals it needs refining

- The agent repeats a mistake **despite** a rule against it → the file is too long and
  the rule is getting lost. Prune.
- The agent asks something **already answered** in the file → the phrasing is ambiguous.
  Rewrite that line, don't add a new one.

## Combine with

- `meta/empirical-prompt-tuning` is the measured QA loop for instruction text
  (operator-triggered). This skill is the direct editing procedure — run
  [[empirical-prompt-tuning]] afterward to verify the slimmed file still works.
- Undefined-term checking is delegated to [[no-neologism]].

Based on Anthropic's "Write an effective CLAUDE.md" guidance
(<https://code.claude.com/docs/en/best-practices>).
