---
name: gh-cli-network
description: Diagnose GitHub CLI (`gh`) DNS and connection failures in sandboxed or restricted execution environments. Use when `gh` reports that `api.github.com` cannot be reached; do not use for ordinary GitHub operations.
---

# Diagnose GitHub CLI network failures

## Separate connectivity from authentication

- Read the complete error before deciding whether the failure is network or authentication related.
- A DNS or connection failure happens before GitHub can return an HTTP authentication response, so it does not prove that a token is invalid.
- Check whether `api.github.com` resolves and is reachable from the same execution context as the failing command.
- Treat `gh auth status` as inconclusive when that context cannot reach GitHub; repeat it only after connectivity is available.

## Retry with network access

- When the execution context cannot resolve or reach GitHub, retry the requested command in an execution context with authorized outbound access.
- Do not repeatedly retry from the same context after confirming that its network access is blocked.
- Do not change credentials or GitHub CLI configuration unless a reachable GitHub response or a successful connectivity check identifies an authentication or permission problem.

## Verify the result

- After changing execution context, rerun the original command and inspect its result.
- If GitHub returns an authentication or permission response, then check `gh auth status` and the required token scopes.
- Never print or copy a token while diagnosing the failure.
