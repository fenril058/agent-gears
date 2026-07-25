# ADR-0001: Project Charter

**Status:** Accepted

## Background

### Why this project exists

This project is **not** an attempt to reimplement or compete feature-for-feature with existing Markdown search tools.

Instead, it is an **Agent-oriented Markdown retrieval engine** whose primary objective is:

> Maximize Coding Agent task success while minimizing delivered context.

Success is measured by:

- Retrieval accuracy
- Delivered context tokens
- Context window footprint
- End-to-end Coding Agent task success

—not by the number of search features.

---

## Existing work

This project was inspired by the excellent work in the following projects:

- `markdown-query`
- `mdq`

from the `dahatake/skills` repository.

Those projects demonstrate that Markdown-aware retrieval is dramatically more efficient than reading entire Markdown documents.

Among other capabilities, they provide:

- BM25-based lexical search
- SQLite indexing
- Japanese tokenization
- Multiple chunking strategies
- Markdown-aware retrieval
- Optional semantic retrieval

These projects should be treated as:

- a benchmark
- a source of architectural ideas
- an implementation reference where appropriate

They are **not** the implementation target.

The goal of this project is **not** feature parity.

---

## Design philosophy

`mdctx` has different goals.

`markdown-query` is primarily a Markdown search engine.

`mdctx` is an Agent context assembler.

The distinction is important.

### markdown-query

```text
query
    ↓
ranking
    ↓
chunks
```

### mdctx

```text
query
    ↓
candidate retrieval
    ↓
section resolution
    ↓
context assembly
    ↓
budget optimization
    ↓
Agent-ready evidence
```

Search is only one stage.

The final product is a bounded evidence package suitable for Coding Agents.

---

## Relationship with mdidx

`mdidx` already exists.

Its responsibilities are intentionally very small.

```text
Markdown
    ↓
stable section numbering
    ↓
JSON
```

Current usage:

```bash
mdidx spec.md | jq '.index'
mdidx spec.md | jq '.sections[7]'
```

This JSON contract is considered stable.

`mdctx` must build on top of this contract rather than replace it.

Backward compatibility with existing `mdidx` output is a primary architectural constraint.

---

## Relationship with mdq

`mdq` is MIT licensed.

Therefore we are legally able to:

- execute it
- benchmark against it
- vendor parts of it
- port algorithms from it

However:

**Do not vendor or copy `mdq` during the initial implementation.**

Instead:

1. implement a native Go solution
2. build benchmark infrastructure
3. compare against `mdq`
4. adopt ideas only when measurements justify them

Performance measurements—not implementation convenience—should drive architectural decisions.

---

## Architecture principles

These principles override implementation convenience.

### Preserve mdidx compatibility

Never break existing `mdidx` JSON output.

---

### Single source of truth

There must be exactly one Markdown section model shared by:

- mdidx
- mdctx

---

### Deterministic first

Prefer deterministic algorithms before heuristic or LLM-assisted approaches.

---

### Machine-readable by default

stdout is JSON.

stderr is diagnostics.

---

### Context is the product

The product is **not search**.

The product is the evidence context delivered to the Coding Agent.

---

## Success criteria

The implementation is considered successful if Coding Agents:

- locate correct Markdown sections more reliably
- receive fewer irrelevant tokens
- avoid reading entire Markdown documents
- require fewer retrieval tool invocations

—even if another Markdown search engine has more features.

---

# Design Priority Order

Whenever there is a trade-off, follow this order.

1. Preserve `mdidx` compatibility.
2. Improve Coding Agent task success.
3. Reduce delivered context tokens.
4. Reduce context window footprint.
5. Improve retrieval accuracy.
6. Reduce implementation complexity.
7. Improve execution speed.

Do **not** sacrifice (1)–(4) in order to improve (6) or (7).

---

# Non-goals

The following are explicitly **out of scope** for the initial implementation.

- Feature parity with `markdown-query`
- Reimplementation of `mdq`
- Embedding-based retrieval
- LLM-based query rewriting
- LLM-based summarization
- Human-oriented interactive search
- Rich query DSLs
- GUI
- Cloud services
- External APIs

The initial implementation should remain:

- deterministic
- offline
- reproducible
- lightweight
- Go-native
- Agent-oriented
