---
name: no-neologism
description: Use when checking prose, code, or answers for undefined terms or ad-hoc coinages and fixing them to established terminology. Before giving a concept your own name, confirm whether an accepted term exists in the field; if you must introduce a new term, define it at first use. Apply this alongside writing and revising Japanese technical documents.
---

# No Neologism (checking for undefined terms / ad-hoc coinages)

The core invariant lives in the always-on rules (AGENTS.md / CLAUDE.md):
**Don't introduce undefined terms or ad-hoc coinages. Use established terminology.**
This skill carries the checking procedure.

## Procedure

1. Identify the words in the prose / answer that "give a concept a name". In particular,
   phrasings you coined on the spot, or metaphors being used as if they were terms of art.
2. For each word, confirm:
   - Is there a **term conventionally used in the field**? If so, replace with it
     (don't escape to a nearby-but-different word — e.g. don't swap Japanese 「見抜く」
     "see through" for 「見分ける」 "tell apart").
   - If no existing term and **a new term is genuinely needed**, **define it at first use**
     (introduce in bold, state in one sentence what it refers to). Use that term
     consistently thereafter.
   - If the word was added as mere decoration, **cut it**.
3. Are you paraphrasing the same concept with different words? Have you retreated to a
   vague word whose referent drifts (Japanese 「ツール」 "tool", 「文脈」 "context",
   「経路」 "path", etc.)?

## How to fix

- An established term exists but you used your own → switch to the established term.
- A term you started using without defining → add a definition at first use, or open it
  up into ordinary phrasing.
- Borrowing the ring of a term of art for a non-technical context → restate with a plain
  verb / noun.

## Combine with

For Japanese technical documents, check this together with the `japanese-tech-writing`
skill's "perspective and voice" section (choosing conventional terms / translations,
prohibiting retreat to vague words).
