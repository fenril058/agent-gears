---
name: fast-search
description: Use when you need broad, semantic search over a codebase ("where is X done", "how is this feature implemented"). For semantic questions that span multiple files — not simple string matches or references to a known file — answer them in few steps with fastcontext.
compatibility: Requires the fastcontext CLI on PATH plus an OpenAI-compatible API (env vars FC_API_KEY, FC_MODEL, FC_BASE_URL; legacy names are also supported). Neither is bundled with the skill; if either is missing, report it as a setup gap and then fall back to Grep/Read. Install from https://github.com/microsoft/fastcontext.
---

# Fast Search (fastcontext)

Answer broad "where / what" questions with `fastcontext` instead of brute-force
full-text Grep. For semantic questions, find the relevant spots in few steps.

## Prerequisites (one-time setup)

The `fastcontext` CLI is not bundled with this skill. Install it from
[microsoft/fastcontext](https://github.com/microsoft/fastcontext); if it isn't on PATH,
use the "Fallback" below.

fastcontext is backed by an OpenAI-compatible API. It reads the following environment
variables. The `FC_` names are preferred; the names in parentheses are legacy
fallbacks.

- `FC_API_KEY` (`API_KEY`): key for the OpenAI-compatible endpoint
- `FC_MODEL` (`MODEL`): the model name to use
- `FC_BASE_URL` (`BASE_URL`): the endpoint URL

Set the key in your own environment (don't commit it, don't put it in the nix store).
For Ollama's OpenAI-compatible API, use a non-empty dummy key and a base URL such as
`http://localhost:11434/v1`.

Check availability by actually running `fastcontext -q "test" --max-turns 1` instead
of inferring it only from legacy environment-variable names. If the command reports
missing credentials, connection failure, or is otherwise not runnable, follow
"Fallback" below.

## When to use which

- Known file / simple string or symbol match → **Grep / Read** (don't use fastcontext).
- Semantic questions that span multiple files, like "where do we authenticate?" or
  "how is this config loaded?" → **fastcontext**.
- You only need the conclusion of the search (no body dump), there's a lot of it, **and
  delegation is authorized under the `model-routing` gates** → hand it to the `search`
  subagent (see that skill for the brief).

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

Don't fall back silently — say in one line why, and name the cause precisely:

- **The CLI or the credentials are absent** (command not found, `Missing credentials`):
  a setup gap, not an expected state. Report it as such, so the user can fix the
  environment.
- **The run failed for some other reason** (connection refused, timeout, an endpoint
  that's down): report it as an unconfirmed failure, not as a misconfiguration. The setup
  may well be fine.

Then substitute the broad, semantic search with the following and carry on — don't block
the task, and don't hoard everything via full-text Read just because fastcontext is
unavailable.

- A combination of Grep/Glob/Read, or the Explore subagent when delegation is authorized
  under the `model-routing` gates.

## Don't

- Don't run fastcontext for a question that's answered by reading a single file.
- Don't take fastcontext's results at face value; before editing, actually Read the
  relevant file to confirm.
