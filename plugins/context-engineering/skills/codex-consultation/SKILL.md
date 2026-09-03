---
name: codex-consultation
description: >-
  Run one synchronous Codex consultation from Claude Code by invoking the Codex CLI
  directly in the foreground. Use only as the Codex-specific execution adapter selected
  by subagent-consultation, or when explicitly asked to consult Codex. Handle the
  install check, working directory, sandbox capability, network access, the timeout, and
  execution failures; leave prompt design, round-trip decisions, and answer synthesis to
  the caller.
---

# Codex consultation adapter

Run one consultation through the Codex CLI and return the answer and the execution facts to the calling skill.
Do not judge, summarize, or merge the answer yourself.

**One call, one result.**
A consultation request completes inside the call that made it, as either a usable answer or an explicit failure.
Never return a job identifier, a status or result command, or anything else the caller has to retrieve by hand.
Do not route the run through `codex:codex-rescue`, a background job, or any other Codex plugin lifecycle: those hand back a job the caller cannot collect, and the review that asked for the consultation stalls waiting for a human.

## Inputs

Require the caller to supply:

- The complete consultation prompt.
  It must stand on its own: Codex sees nothing of the caller's conversation, and nothing of an earlier round (see "Second round").
- The target worktree's absolute path.
- Whether the consultation is static or verification-capable.
- Whether remote information is required.

If the target path or the consultation prompt is missing, return that omission instead of guessing.

## Check that the CLI is there

```text
command -v codex
```

If `codex` is not on PATH, return "Codex CLI is not installed" as a consultation failure and stop.
Do not substitute another consultant: `subagent-consultation` owns that fallback.

## Select execution capability

Use `-s read-only` only when the work is clearly limited to static inspection.

Use `-s workspace-write` when Codex may run tests, builds, linters, reproduction commands, or diagnostics that create caches, temporary files, generated artifacts, or other filesystem output.
A review or diagnosis is not inherently read-only.

For a write-capable review or diagnosis, append this constraint to the consultation prompt:

```text
Do not modify tracked source files or implement a fix. You may run tests, builds,
linters, and diagnostic commands and allow their normal temporary or generated
outputs.
```

If the user requested an implementation, do not add that constraint.

### Network access

Remote commands such as `gh pr view`, `gh api`, fetching remote refs, and reading release notes need network access, which the sandbox blocks by default.
Enable it with `-c sandbox_workspace_write.network_access=true`.

That setting is namespaced to the workspace-write sandbox and does nothing in a read-only run: on codex-cli 0.152.0, `-s read-only` with the flag set still fails DNS resolution (`curl: (6) Could not resolve host`).
So a consultation that needs remote information runs with `-s workspace-write`, whether or not it also needs to write.

## Run it

```bash
timeout 900 codex exec --ephemeral -C <target worktree absolute path> \
  -s <read-only|workspace-write> \
  [-c sandbox_workspace_write.network_access=true] \
  -o <answer file> \
  "<the caller's prompt>" < /dev/null
```

- `-C <path>` runs Codex in the target worktree.
  Do not assume the host's current directory is that worktree.
- `--ephemeral` writes no session file, so a killed or timed-out run leaves nothing queued and nothing to collect.
- `< /dev/null` is required.
  Codex reads stdin as an extra `<stdin>` block and waits for EOF even when the prompt is an argument, so without it the run hangs.
- Pass the prompt as a command-line argument, not on stdin.
- `-o <file>` makes Codex write its final message to that file.
  stdout also carries the banner, the command transcript, and the token count; read the answer from the file and keep the transcript for the execution facts.
  Put that file on a scratch path outside the target worktree, so a consultation never leaves an untracked file in the repository under review.

Bound the consultation at 900 seconds (15 minutes).
That is an execution-policy default, not part of the contract; the caller may specify a different bound.

Put the bound on the process with `timeout 900`, so it holds whatever the host does, and also give the Bash call a tool-call timeout of 900000 ms.
If the host caps tool-call timeouts lower — Claude Code's Bash tool documents a 600000 ms maximum — that cap is the bound that actually applies.
Report whichever bound fired.
Where `timeout` is unavailable, rely on the tool-call timeout alone.

## When it does not finish

A run that hits the timeout is a consultation failure.
`timeout` exits 124 when it fires, so read that exit code as a timeout rather than as a Codex CLI error.
Do not start a second Codex run to recover the first, do not switch to background execution, and do not hand the caller anything to retrieve later.
Report the timeout, its bound, and any partial transcript.

`--ephemeral` is what makes that safe: there is no session to resume and no job left behind, so killing the process ends the consultation cleanly.

If a bounded consultation repeatedly exceeds the bound, the answer is a narrower prompt, not a longer-lived job.
Say so to the caller instead of retrying unchanged.

## Second round

`codex exec` is single-shot: a second run has no memory of the first.
This adapter keeps no Codex thread and does not use `--resume`.

A second round is therefore a fresh invocation whose prompt restates everything it needs: the original background, goal, constraints, and evaluation angles, a summary of the first answer, and the caller's rebuttal, supplements, and follow-up questions.
The caller builds that prompt; this adapter only runs it.

## Return execution facts

Return all of the following to the caller:

- The Codex answer from the `-o` file, without silently correcting it.
- Whether the run was read-only or write-capable, and whether network access was enabled.
- Which tests, builds, or diagnostics Codex reports running, and their outcomes.
- Any missing remote information or command failure.
- On failure, which kind it was: CLI not installed, timeout, non-zero exit, or no usable answer.

Treat messages such as `could not fetch`, `permission denied`, `not found`, sandbox errors, network errors, and failed commands as execution failures even if Codex also produced an answer.
Never represent an unexecuted test or unavailable PR context as verified.

A non-zero exit, an empty answer file, or an answer that only reports being unable to proceed is a consultation failure, not an answer.

The calling `subagent-consultation` skill owns follow-up decisions, consultant fallback, independent verification, synthesis, and the final user-facing report.
