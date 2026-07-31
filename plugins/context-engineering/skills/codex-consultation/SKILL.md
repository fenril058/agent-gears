---
name: codex-consultation
description: >-
  Run a persistent Codex consultation from Claude Code through the Codex plugin.
  Use only as the Codex-specific execution adapter selected by
  subagent-consultation, or when explicitly asked to consult Codex while preserving
  its thread for follow-up. Handle cwd, sandbox capability, job result retrieval,
  continuation, and execution failures; leave prompt design and answer synthesis to
  the caller.
---

# Codex consultation adapter

Execute a consultation through `codex:codex-rescue` while preserving the Codex
thread for a possible second round. Return the Codex answer and execution facts to
the calling skill. Do not judge, summarize, or merge the answer yourself.

## Inputs

Require the caller to supply:

- The complete consultation prompt.
- The target worktree's absolute path.
- Whether the consultation is static or verification-capable.
- Whether remote information is required.
- Whether this is a fresh consultation or a continuation.

If the target path or consultation prompt is missing, return that omission instead
of guessing.

## Select execution capability

Use read-only execution only when the work is clearly limited to static inspection.

Use write-capable execution when Codex may run tests, builds, linters, reproduction
commands, or diagnostics that create caches, temporary files, generated artifacts,
or other filesystem output. A review or diagnosis is not inherently read-only.

For a write-capable review or diagnosis, append this constraint to the consultation
prompt:

```text
Do not modify tracked source files or implement a fix. You may run tests, builds,
linters, and diagnostic commands and allow their normal temporary or generated
outputs.
```

If the user requested an implementation, do not add that constraint.

Remote commands such as `gh pr view`, `gh api`, fetching remote refs, and reading
release notes require network access independently of filesystem access. Do not
claim they are available merely because the run is write-capable.

When the installed Codex plugin exposes a per-run network option, use it for a
remote-required consultation. Otherwise rely on the trusted target repository's
project-local `.codex/config.toml`:

```toml
[sandbox_workspace_write]
network_access = true
```

Do not create or edit that config as part of a consultation. If remote access fails,
return the failure to the caller so it can fetch the missing information and decide
whether to continue the same Codex thread.

## Start the consultation

On Claude Code, invoke the Agent tool with `subagent_type: codex:codex-rescue`.

Put the target worktree's absolute path in the request as `--cwd <path>`. The rescue
agent must remove it from the prompt and pass it to
`codex-companion.mjs task --cwd <path>` as a runtime option. Do not assume Claude
Code's current directory is the target worktree.

For verification-capable work, request `--write`. For static inspection, explicitly
request read-only behavior. Preserve the caller's foreground/background choice; if
none was supplied, prefer foreground for a bounded consultation and background for
a long-running investigation.

Use a fresh Codex task for the first round. Keep the resulting job and thread
identifiers. A task created under one cwd is stored in that workspace's state and
cannot be retrieved from another cwd.

If the rescue agent starts a background job, retrieve it from the same cwd with
`/codex:status` and `/codex:result`. Do not treat a successful enqueue operation as
the consultation answer.

## Handle timeouts

For a bounded foreground consultation, give the rescue agent's Bash invocation a
timeout of at least 900 seconds when the host supports tool-call timeouts.

Use background execution from the start for repository-wide investigation,
substantial tests or builds, or any consultation likely to exceed that bound.

If a foreground invocation times out, do not immediately start another Codex task.
First query `/codex:status` from the same cwd. Retrieve the existing result if the
job completed, or continue waiting if it is still running. Retry only when no job
exists or the existing job definitively failed.

## Continue the same Codex consultant

For a second round, invoke the rescue agent with `--resume` from the same absolute
cwd. Send only the caller's rebuttal, supplements, follow-up questions, and requested
areas for deeper investigation. Do not create a fresh Codex task.

The Claude wrapper agent may be invoked again; continuity is defined by the resumed
Codex thread, not by reusing the wrapper agent's context.

## Return execution facts

Return all of the following to the caller:

- The Codex answer without silently correcting it.
- The job or thread identifier when available.
- Whether the run was read-only or write-capable.
- Which tests, builds, or diagnostics Codex reports running and their outcomes.
- Any missing remote information or command failure.

Treat messages such as `could not fetch`, `permission denied`, `not found`, sandbox
errors, network errors, and failed commands as execution failures even if Codex also
produced an answer. Never represent an unexecuted test or unavailable PR context as
verified.

The calling `subagent-consultation` skill owns follow-up decisions, independent
verification, synthesis, and the final user-facing report.
