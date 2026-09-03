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
A consultation request completes inside the call that made it, as either a usable answer or a consultation failure.
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

Do the whole consultation in one command, so the answer file is cleaned up even when the run is cut short:

```bash
ans=$(mktemp) && trap 'rm -f "$ans"' EXIT
timeout -k 10 <effective bound in seconds> \
  codex exec --ephemeral -C <target worktree absolute path> \
  -s <read-only|workspace-write> \
  [-c sandbox_workspace_write.network_access=true] \
  -o "$ans" \
  "<the caller's prompt>" < /dev/null
rc=$?
printf '\n===ANSWER(rc=%s)===\n' "$rc"; cat "$ans"
```

- `-C <path>` runs Codex in the target worktree.
  Do not assume the host's current directory is that worktree.
- `--ephemeral` writes no session file, so a killed or timed-out run leaves nothing queued and nothing to collect.
- `< /dev/null` is required.
  Codex reads stdin as an extra `<stdin>` block and waits for EOF even when the prompt is an argument, so without it the run hangs.
- Pass the prompt as a command-line argument, not on stdin.
- `-o "$ans"` makes Codex write its final message there.
  stdout carries the banner, the command transcript, and the token count as well, so read the answer from the part after the `===ANSWER===` marker and keep the transcript for the execution facts.

### The answer file

Codex's final message can quote source, PR context, and whatever else the consultation touched, so the file it lands in is not a scratch artifact to leave lying around.
`mktemp` creates it mode 0600 outside the target worktree, and the `trap ... EXIT` removes it on every path the shell can take: success, non-zero exit, and timeout alike.
If the host kills the shell before the trap runs, the file is still 0600 and still yours to remove on the next turn.

This is a separate obligation from `--ephemeral`.
`--ephemeral` leaves no Codex session or job behind; the trap leaves no answer file behind.

## Bound the run

The policy default is 900 seconds (15 minutes).
It is an execution-policy default, not part of the contract; a caller may specify another bound.

The effective bound is the smaller of the policy bound and the host's maximum tool-call timeout.
Set the tool-call timeout to the effective bound — never ask the host for more than it documents — and give `timeout` the same number of seconds.
On Claude Code the Bash tool documents a 600000 ms maximum, so the effective bound there is 600 seconds.

When the effective bound is below the policy bound, the consultation ran **host-limited**.
Report that in the execution facts on every outcome, not only on a timeout, so the caller knows the consultation got less time than the policy allows.

`-k 10` sends KILL 10 seconds after the TERM, so the run stays bounded even when Codex does not exit on TERM.
Where `timeout` is unavailable, the tool-call timeout is the only bound and there is no process-side kill guarantee; report that as a further degradation.

## When it does not finish

Hitting the effective bound is a consultation failure.
`timeout` exits 124 when TERM ended the run and 137 when the KILL was needed; both are the same timeout-class failure, not a Codex CLI error.

Do not start a second Codex run to recover the first, do not switch to background execution, and do not hand the caller anything to retrieve later.
Report the timeout, the effective bound, whether it was host-limited, and any partial transcript.

`--ephemeral` is what makes that safe: there is no session to resume and no job left behind, so killing the process ends the consultation cleanly.

If a bounded consultation repeatedly exceeds the bound, the answer is a narrower prompt, not a longer-lived job.
Say so to the caller instead of retrying unchanged.

## Second round

`codex exec` is single-shot: a second run has no memory of the first.
This adapter keeps no Codex thread and does not use `--resume`.

A second round is therefore a fresh invocation whose prompt restates everything it needs: the original background, goal, constraints, and evaluation angles, a summary of the first answer, and the caller's rebuttal, supplements, and follow-up questions.
The caller builds that prompt; this adapter only runs it.

## Classify the outcome

Every run ends as exactly one of two outcomes.
Which one it is decides what the caller does next, so do not blur them.

### Consultation failure — no usable answer

- The Codex CLI is not installed.
- The run hit the effective bound (`timeout` exit 124 or 137).
- The `codex exec` process exited non-zero for any other reason.
- The answer file is empty, or the answer only reports being unable to proceed.

Report the failure and stop.
Whether to fall back to another consultant is `subagent-consultation`'s decision, not this adapter's.

### Usable result with execution degradation — an answer from a partly failed run

Codex answered, but part of what it tried did not work: a fetch, test, build, or diagnostic command failed, remote information was unavailable, or a sandbox or network error appeared in the transcript.

This is not a consultation failure and not a reason to fall back.
Return the answer together with the execution facts, and leave it to the caller to fetch what is missing, re-evaluate the points that depended on it, and state the gap in its report.

Watch the transcript for `could not fetch`, `permission denied`, `not found`, sandbox errors, network errors, and non-zero exits from commands Codex ran.
In either outcome, never represent an unexecuted test or unavailable PR context as verified.

## Return execution facts

Return all of the following to the caller:

- Which of the two outcomes it was.
- The Codex answer as written, without silently correcting it.
- Whether the run was read-only or write-capable, and whether network access was enabled.
- The effective bound, and whether it was host-limited.
- Which tests, builds, or diagnostics Codex reports running, and their outcomes.
- Any missing remote information or command failure.

The calling `subagent-consultation` skill owns follow-up decisions, consultant fallback, independent verification, synthesis, and the final user-facing report.
