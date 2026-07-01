---
name: markdown-context
description: Use when you need to read only the relevant sections out of a large or unfamiliar Markdown file. For READMEs, design docs, specs, long documents, book manuscripts, etc., save tokens by fetching just the right part from a heading index instead of loading the whole file. mdidx is the primary tool; bring in mq only when you need structural queries.
compatibility: Requires the mdidx and jq binaries on PATH. mq is optional (structural queries only). These are not bundled with the skill; see the repo README tools section to install (mdidx e.g. `nix profile install github:fenril058/agent-gears#mdidx`).
---

# Markdown Context Retrieval

Don't full-text Read a large Markdown file. **Look at the index, take only the sections
you need.** The built-in Read (offset/limit) + Grep can't reliably find a section's end,
but mdidx cuts section boundaries at headings, so you neither miss nor over-grab.

> Needs `mdidx` and `jq` on PATH (`mq` is optional). They are not shipped with this skill;
> if missing, install per the [repo README](https://github.com/fenril058/agent-gears#readme)
> — e.g. `nix profile install github:fenril058/agent-gears#mdidx`.

## Decision

- File is small (a few dozen lines) → just Read it.
- File is large / length unknown / you only need part → the mdidx steps below.
- You need "only the code blocks", "cross-cutting extraction by element type", or a
  "transform" → mq (below).

## mdidx (primary, fixed 2 steps)

`mdidx` converts Markdown into `{index, sections}` JSON. `index` is a numbered table of
contents; `sections` is an array of raw Markdown per heading. The N in the index's
`## N. heading` corresponds to `sections[N]`.

1. Look at the TOC (a few dozen lines):

   ```bash
   mdidx path/to/doc.md | jq -r '.index'
   ```

2. Take only the sections you need (N is the index number):

   ```bash
   mdidx path/to/doc.md | jq -r '.sections[5]'
   ```

   For multiple sections, `jq -r '.sections[3,5,8]'`. To grab a heading together with
   its subsections, slice the range: `jq -r '.sections[2:6][]'`. Children follow their
   parent in the numbering, so a contiguous deeper-heading range is that heading's whole
   subtree. `sections[0]` is any preamble before the first heading.

If you query the same file repeatedly, convert once and cache:

```bash
mdidx path/to/doc.md > /tmp/doc.idx.json
jq -r '.index'       /tmp/doc.idx.json
jq -r '.sections[5]' /tmp/doc.idx.json
```

`--pretty` is for human-readable formatting; not needed in a pipeline.

## mq (auxiliary, only when you need structural queries)

`mq` is jq for Markdown. It can extract / traverse / transform by element type.
**If your goal is fetching sections, use mdidx.** Use mq only for other purposes like:

- List just the headings: `mq -F text '.h2' doc.md`
- Collect just the code blocks: `mq -F text '.code' doc.md`
- When you need to specify the input format or transform, `-I` / `-F` (see `mq --help`)

`mq -F text` output mixes blank lines between elements. If that's hard to read, append
`| sed '/^[[:space:]]*$/d'` to strip blank lines
(e.g. `mq -F text '.h2' doc.md | sed '/^[[:space:]]*$/d'`).

## Don't

- Don't full-text Read a large Markdown file without reason.
- Don't write a "section fetch" that mdidx handles as an mq query (a wrong query
  silently drops content).
