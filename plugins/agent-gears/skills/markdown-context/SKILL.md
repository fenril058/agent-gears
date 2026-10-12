---
name: markdown-context
description: Retrieve selected sections from a long Markdown document when heading-based extraction would avoid reading substantial unrelated content. Use for partial reading of long specs, design docs, or manuscripts. Small files, unknown length alone, and tasks requiring the whole document do not call for this skill.
compatibility: Requires the mdidx and jq binaries on PATH. mq is optional (structural queries only). These are not bundled with the skill; see the repo README tools section to install (mdidx e.g. `nix profile install github:fenril058/agent-gears#mdidx`).
---

# Markdown Context Retrieval

Use `mdidx` to fetch sections by heading when that saves more reading than the index and selection add.
It splits at recognized headings; it does not determine which sections contain all the requirements for a task.

## Choose the reading method

- Read small files directly.
  Unknown length alone is not a reason to index: use available file information, a bounded Read, or a size check if needed.
- If the task needs the whole document, read it directly, in chunks if necessary.
  Indexing and then printing `.sections[]` adds work without narrowing the content.
- For a long document with only part relevant, use the heading index below when helpful.
  An existing line range or a targeted `rg` search followed by Read or shell extraction may already be sufficient.
- If `mdidx` or `jq` is missing, use Read or shell operations for the current task.
  Installation instructions are in the [repo README](https://github.com/fenril058/agent-gears#readme).

## Fetch sections with mdidx

`mdidx` converts Markdown into `{index, sections}` JSON.
The N in the index's `## N. heading` corresponds to `sections[N]`.
Each section ends at the next recognized heading, including a child heading.
If there is a preamble, it occupies `sections[0]`; otherwise the first heading does.

1. Inspect the index unless you already have one for the current file contents:

   ```bash
   mdidx path/to/doc.md | jq -r '.index'
   ```

2. Fetch the selected sections:

   ```bash
   mdidx path/to/doc.md | jq -r '.sections[3,5,8]'
   ```

   To include a heading's children, use a slice such as `.sections[2:6][]`, ending before the next heading of the same or shallower depth.
   Choose the numbers from the index, not from this example.

Include governing context such as the parent introduction, global constraints, and referenced definitions or exceptions when they apply.
If headings do not establish where relevant requirements live, search the body or broaden the read; a selected section alone does not prove completeness.

For repeated queries on unchanged contents, convert once and reuse the result:

```bash
mdidx path/to/doc.md > /tmp/doc.idx.json
jq -r '.index'       /tmp/doc.idx.json
jq -r '.sections[5]' /tmp/doc.idx.json
```

## Structural queries with mq (optional)

Use `mq` for extraction by element type or transformations, rather than translating heading-section retrieval into a more complex query.

- Headings: `mq -F text '.h2' doc.md`
- Code blocks: `mq -F text '.code' doc.md`
- Input/output formats: `-I` / `-F` (see `mq --help`)
