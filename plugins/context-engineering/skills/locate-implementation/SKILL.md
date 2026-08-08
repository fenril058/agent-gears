---
name: locate-implementation
description: Locate candidate implementation files and line ranges for a concrete behavior or symptom described in natural language when the repository terminology, symbols, and paths are unknown and the code likely spans multiple subsystems. Use fastcontext only for this bounded repository-location task. Do not use it for known files or symbols, small searches, architecture or design analysis, issue prioritization, or questions requiring non-repository evidence.
compatibility: >-
  Requires the fastcontext CLI on PATH plus an OpenAI-compatible API (env vars FC_API_KEY, FC_MODEL, FC_BASE_URL; legacy names are also supported).
  Neither is bundled with the skill; if either is missing, report it as a setup gap and then fall back to Grep/Read.
  Install from https://github.com/microsoft/fastcontext.
---

# Locate Implementation (fastcontext)

Use `fastcontext` as a bounded, read-only locator.
Return candidate files and line ranges for the main agent to verify; do not delegate design or final judgment to it.

## Eligibility gate

Run `fastcontext` only when all of these are true:

- The request names a concrete behavior, failure symptom, or execution path in natural language.
- Repository-specific identifiers, symbols, and paths are not yet known, and one or two targeted Grep searches are unlikely to locate the path.
- The implementation likely crosses multiple files or subsystems.
- The useful result is a compact list of candidate files and line ranges.
- The repository is large or unfamiliar enough that delegated exploration can keep substantial intermediate reads out of the main context.

Otherwise use Grep, Glob, and direct reads.

Never use `fastcontext` for:

- a known file, symbol, error string, or other exact search term;
- architecture mapping, design evaluation, feasibility analysis, or issue prioritization;
- repository-wide status or quality assessment;
- questions that depend on issues, web pages, runtime state, logs, or other non-repository evidence;
- a small repository or a question answerable in one or two direct search/read steps.

## Setup

`fastcontext` uses an OpenAI-compatible API and reads these variables, preferring the `FC_` names:

- `FC_API_KEY` (`API_KEY`)
- `FC_MODEL` (`MODEL`)
- `FC_BASE_URL` (`BASE_URL`)

Keep credentials outside the repository and the Nix store.
For Ollama, use a non-empty dummy key and a base URL such as `http://localhost:11434/v1`.

During initial setup, verify the real endpoint once with `fastcontext -q "test" --max-turns 1`.
Do not repeat this probe before normal searches, and never start it while another `fastcontext` process is running.

## Query narrowly

Name the behavior, boundary, or symptom and ask only for candidate locations.
Use `--citation` and default to `--max-turns 1`.

```bash
fastcontext -q "Trace an edit rejected with HTTP 409 from the client request through conflict recovery, including its tests." --citation --max-turns 1
```

Do not ask it to map a whole architecture, rank work, or recommend a design.

## Enforce a wall-clock budget

Give the search at most 90 seconds of wall-clock time.
`--max-turns` bounds agent turns, not elapsed time.
Use the execution environment's continuation and termination mechanisms; after the budget, stop the process and use the fallback.

Preserve the complete execution result until the process finishes:

- If the runner returns a continuation or session handle, retain and surface it; never project only stdout and discard the handle.
- Poll the handle until an exit status arrives or the 90-second budget expires.
- Do not interpret empty stdout as an empty search result while a handle says the process is still running.
- Report "no results" only after a successful completed process returns empty output.
- Do not run multiple `fastcontext` processes concurrently against the same local model.

For Codex wrappers, emit the continuation handle as well as stdout:

```javascript
text(result.output);
if (result.session_id) text(`SESSION_ID=${result.session_id}`);
```

If the process remains active near 60 seconds, give the user a brief progress update.

## Verify and return

Read the cited files before relying on the result.
Return only:

- the candidate implementation path or behavior summary;
- supporting `path:line` citations;
- a short note about gaps or uncertain candidates.

## Fallback

State the reason in one line, then continue with targeted Grep, Glob, and reads.
Use an Explore subagent only when delegation is authorized.

Distinguish these cases:

- Missing CLI or credentials: report a setup gap.
- Connection refusal or endpoint failure: report an unconfirmed execution failure, not a configuration conclusion.
- More than 90 seconds: report that the search exceeded its wall-clock budget.
- Completed with no output: report an empty result only after confirming successful completion.
