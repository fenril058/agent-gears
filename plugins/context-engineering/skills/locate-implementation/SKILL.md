---
name: locate-implementation
description: Locate candidate implementation files and line ranges for a concrete behavior or symptom described in natural language when the repository terminology, symbols, and paths are unknown and the code likely spans multiple subsystems. Use fastcontext only for this bounded repository-location task. fastcontext may send repository content to its configured OpenAI-compatible endpoint and writes trajectories under the checkout's .fastcontext directory by default. Require explicit user permission before a main session calls a non-loopback or unclassifiable endpoint; a delegated agent without direct user interaction must fall back. Do not use it for known files or symbols, small searches, architecture or design analysis, issue prioritization, or questions requiring non-repository evidence.
compatibility: >-
  Requires the fastcontext CLI on PATH plus an OpenAI-compatible API (env vars FC_API_KEY, FC_MODEL, FC_BASE_URL; legacy names are also supported).
  Neither is bundled with the skill; if either is missing, report it as a setup gap and then fall back to Grep/Read.
  Install from https://github.com/microsoft/fastcontext.
---

# Locate Implementation (fastcontext)

Use `fastcontext` as a bounded repository locator.
Its exploration tools do not edit source files, but the CLI is not read-only with respect to the checkout.
Unless `--traj` is provided, it creates `.fastcontext/` in the current checkout and writes a timestamped JSONL trajectory there.
It may also transmit repository content to its configured endpoint.
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

## Endpoint classification and permission

Before any `fastcontext` API call, determine the effective base URL by taking the first non-empty value from `FC_BASE_URL`, then `BASE_URL`.
If neither variable has a non-empty value, classify the endpoint as indeterminate.
Do not make a network request, perform a DNS lookup, or run a `fastcontext` probe to classify it.
Do not print API keys, authentication headers, or an unfiltered environment-variable listing.
Parse the string with a local standards-compliant URL parser and use its normalized hostname, excluding URL userinfo and the port and removing brackets around an IPv6 literal.
Do not identify the host by visually scanning or splitting the string.
Do not place the URL value in a command-line argument or interpolate it into a command.
If a subprocess performs the parsing, it must read the selected environment variable inside the process and output only the scheme, normalized hostname, and port.
If no such parser is available or parsing fails, classify the endpoint as indeterminate.
In a parsed URL, userinfo is separate from and appears before the host, so `http://localhost@collector.example.com/v1` has host `collector.example.com`.

Classify the endpoint from the URL string alone:

- **Loopback:** the parsed host is exactly `localhost` (case-insensitive), an IPv4 address in `127.0.0.0/8`, or the IPv6 address `::1`.
- **Non-loopback:** the URL has a determinate host that is not loopback. Private-network, VPN, and LAN addresses are non-loopback.
- **Indeterminate:** the URL is absent or cannot be parsed, or its host cannot be determined.

`0.0.0.0` and `::` are unspecified addresses, not loopback addresses; classify them as non-loopback.
Do not resolve a hostname or infer that its address is loopback.
For a loopback endpoint, no additional permission about sending data externally is required.
This exemption is an operational decision to trust the configured local endpoint, including any forwarding or redirect behavior.
It is not a technical guarantee that traffic or repository content remains on the device.
For a non-loopback or indeterminate endpoint, complete the following disclosure and permission exchange before the first API call.
Show only the destination scheme, host, and port.
For the port, use an explicit port or the scheme's standard default when known; use `unknown` for any value that cannot be determined.
Do not show the path, query, userinfo, credentials, or API key.
Also state that repository content may be sent and that API usage or charges may occur.
Ask an explicit question in the conversation that includes this disclosure, and receive the user's answer before the tool call.
A tool-level command-approval prompt does not count as this permission.

Only a session that can converse directly with the user may obtain this permission.
A delegated agent without direct user interaction may run `fastcontext` only for a loopback endpoint.
For a non-loopback or indeterminate endpoint, it must not accept a parent agent's statement that permission was obtained; it must fall back to targeted Grep, Glob, and direct reads.
If `fastcontext` is still needed, the main session must obtain permission directly and run it.

Do not repeat the confirmation if the user has already explicitly requested this run while demonstrating that they understand both the destination and the transmission of repository content.
A general request to investigate or to use `fastcontext` does not authorize sending repository content to an external or indeterminate endpoint.
If permission is not obtained, do not run `fastcontext`; state the reason in one line and fall back to targeted Grep, Glob, and direct reads.

## Query narrowly

Classify the endpoint and obtain any required permission before running the query.
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
- Permission not obtained for a non-loopback or indeterminate endpoint: report that `fastcontext` was skipped and use the fallback.
- Delegated agent with a non-loopback or indeterminate endpoint: use the fallback regardless of a parent's permission claim.
- Connection refusal or endpoint failure: report an unconfirmed execution failure, not a configuration conclusion.
- More than 90 seconds: report that the search exceeded its wall-clock budget.
- Completed with no output: report an empty result only after confirming successful completion.
