---
name: sandbox-network-access
description: Diagnose DNS and outbound connection failures from command-line tools and API clients in sandboxed or restricted execution environments. Use when a tool cannot resolve or reach an external service.
---

# Diagnose network access failures

## Classify the failure

- Read the complete error and identify which hostname and operation failed.
- Check name resolution and connectivity to that hostname from the same execution context as the failing command.
- Distinguish DNS, connection, and TLS failures from HTTP responses; a network failure does not establish that credentials are invalid or that the remote service is down.
- Do not generalize one failed hostname or one execution context to all network destinations.
- Inspect client authentication, such as `gh auth status`, only after confirming that the client can reach its service; connectivity failures can make authentication checks inconclusive.

## Use an authorized execution context

- If the execution context blocks the required outbound connection, do not repeat the same request from that context.
- Retry the requested operation in an execution context with authorized access to the required destination, or report the blocker if none is available.
- Do not change credentials, client configuration, or sandbox policy unless evidence identifies a relevant authentication or configuration problem and the change is authorized.

## Verify the result

- After changing execution context, rerun the original operation and inspect its result.
- If the service returns an authentication or permission response, then check the relevant credentials and scopes.
- Never print or copy credentials while diagnosing the failure.
