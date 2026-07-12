---
name: spec-ambiguity-audit
description: Use before implementing a non-trivial spec, design doc, or plan — or when the user asks to "find gaps in this doc", "check this spec for ambiguity", "get a second pair of eyes on this design", or "what's underspecified here". Has a cheap-tier model read the document cold (no project background) and list everything that blocks implementation, then filters the list mechanically against the document itself before reporting. Catches real gaps a from-scratch implementer would trip on; do not use it as a substitute for a full design review of contested architecture decisions.
---

# Spec Ambiguity Audit

A low-context-window model reading a spec cold, with no background on the project,
notices things a deeply-familiar author skips past — because it has to resolve every
term from the text alone. That's the entire value of this skill: **borrow the weak
model's lack of context as a feature.** Don't give it a project summary, don't answer
its likely questions in advance, don't prime it. The moment you explain the project,
you've destroyed the thing that makes this useful.

The counterpart cost is that a large fraction of what it flags turns out to be
something the document already answers a few lines away — the weak model quoted the
answer and still asked the question. Filtering that out is not optional; skipping it
turns a useful signal into noise the user has to re-derive themselves.

## The two-pass shape

**Pass 1 (cheap tier, cold read):** dispatch a subagent on the cheapest available model
(e.g. haiku) with only the document path and this instruction: read it as the engineer
about to implement it, and list every point where you can't tell which of several
implementations is intended, without guessing at an answer. Require a line-number
citation on every item — this is not optional, the filter in pass 2 depends on it.
See `references/prompt-template.md` for the exact prompt (Japanese-project version
included).

**Pass 2 (mechanical filter, no model call):** collect the cited ranges, sort and merge
overlapping/adjacent ones, and extract only those windows from the source file with
`scripts/extract_context.py`. Then — as the main model — read *only the extracted
windows*, not the full document, and classify each item:

- **valid**: the extracted window doesn't answer it. Keep it.
- **already answered nearby**: the window contains the answer, sometimes in the very
  sentence the weak model quoted. Drop it.
- **noise**: a misreading, or a question about something the document isn't obligated
  to specify. Drop it.

Report only the survivors, with citations, to the user. Optionally mention what was
filtered and why — it builds trust in the surviving list and costs little.

## Why the filter has to be mechanical, not another model call

An earlier version tried a second pass where the *same* weak model re-read its own
cited context and self-filtered ("does this line already answer your question?"). It
filtered out nothing, including cases where the answer was the exact sentence it had
just quoted — it invented a narrower, more specific version of the question to justify
keeping the item. A model asked to grade its own prior output is anchored to defending
it, not revising it. Don't route the filter through the same model that produced the
list, self or fresh instance — use grep-and-read instead, which has no stake in the
outcome.

## Why merge before extracting

Cited ranges cluster — several questions often point at the same paragraph or two
nearby ones. Extracting a fixed margin around *each* citation independently, without
merging overlaps first, can pull in more total lines than the source file contains
(observed: 708 extracted lines from a 673-line file). Always sort ranges and merge
overlapping/adjacent windows before reading — `extract_context.py` does this for you.

```bash
python3 scripts/extract_context.py <file> --margin 10 \
  --range 62 --range 316-318 --range 300-301
```

Pass every cited range from pass 1 in one invocation so merging can dedupe across all
of them, not just within a single command.

## When the mechanical filter isn't worth it

For a short document (roughly under ~500 lines) with citations clustered across a
large fraction of it, merged extraction can still cover most of the file — at that
point just read the document once instead of invoking the script. The win from this
skill scales with document size and how spread out the citations are; it's largest on
long specs or plans (hundreds to thousands of lines) where citations are sparse.

## When a citation's local context isn't enough

Occasionally the real answer lives in a different section entirely — e.g. a question
raised in a "rebase" section is actually answered in an "autosave" section 100+ lines
away. This was rare in testing (roughly 1 in 6 already-answered items), so treat it as
a fallback: if the extracted window doesn't resolve an item and you suspect the answer
is elsewhere, search for it specifically rather than re-reading the whole document.

## Reading the precision number

If you report a valid/total ratio to the user, flag what it actually measures: it
reflects the document's maturity as much as the weak model's judgment. A rough draft
with large unwritten sections will score high because nearly everything genuinely is
unspecified — that's not the audit working better, it's the document being thinner.
A carefully considered spec that still scores 50%+ valid is the more meaningful signal.

## Reference

- `references/prompt-template.md` — the pass-1 prompt, with a Japanese-project variant
- `scripts/extract_context.py` — merges and extracts cited ranges (see `--help`)
