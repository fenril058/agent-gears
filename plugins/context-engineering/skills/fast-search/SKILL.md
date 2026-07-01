---
name: fast-search
description: Use when you need broad, semantic search over a codebase ("where is X done", "how is this feature implemented"). For semantic questions that span multiple files — not simple string matches or references to a known file — answer them in few steps with fastcontext.
compatibility: Requires the fastcontext CLI on PATH plus an OpenAI-compatible API (env vars API_KEY or OPENAI_API_KEY, MODEL, BASE_URL). Neither is bundled with the skill; without them, fall back to Grep/Read. Install from https://github.com/microsoft/fastcontext.
---

# Fast Search (fastcontext)

Answer broad "where / what" questions with `fastcontext` instead of brute-force
full-text Grep. For semantic questions, find the relevant spots in few steps.

## Prerequisites (one-time setup)

The `fastcontext` CLI is not bundled with this skill. Install it from
[microsoft/fastcontext](https://github.com/microsoft/fastcontext); if it isn't on PATH,
use the "Fallback" below.

fastcontext is backed by an OpenAI-compatible API. It needs the following environment
variables. Without them it fails with `Missing credentials`.

- `API_KEY`: key for the OpenAI-compatible endpoint (`OPENAI_API_KEY` also works)
- `MODEL`: the model name to use
- `BASE_URL`: the endpoint URL (omit for OpenAI itself)

Set the key in your own environment (don't commit it, don't put it in the nix store).
Check whether it's configured with `fastcontext -q "test" --max-turns 1`.
If it's unset / not runnable, follow "Fallback" below.

## When to use which

- Known file / simple string or symbol match → **Grep / Read** (don't use fastcontext).
- Semantic questions that span multiple files, like "where do we authenticate?" or
  "how is this config loaded?" → **fastcontext**.
- You only need the conclusion of the search (no body dump) and there's a lot of it →
  delegate to the `search` subagent (see the `model-routing` skill). Delegating runs it
  cheaply without polluting the main context.

## How to use

```bash
fastcontext -q "where is the auth token validated"
```

When you only want the citations (file / location):

```bash
fastcontext -q "the load path of the config file" --citation
```

Use `--max-turns N` to bound a long search, `--verbose` to trace behavior.

## Fallback (when fastcontext is unavailable)

When fastcontext is unset / not runnable (`Missing credentials` etc.), substitute the
broad, semantic search with the following. Don't hoard everything via full-text Read
just because fastcontext is absent.

- The Explore subagent (read-centric broad search), or a combination of Grep/Glob/Read.
- If you only need the conclusion and there's a lot of it, delegate to the `search`
  subagent (`model-routing` skill).

## Don't

- Don't run fastcontext for a question that's answered by reading a single file.
- Don't take fastcontext's results at face value; before editing, actually Read the
  relevant file to confirm.
