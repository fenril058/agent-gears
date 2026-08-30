---
name: task-delegation
description: >-
  Use after the current host permits subagent delegation, when selecting bounded independent tasks to delegate or writing a delegation brief.
  Uses task independence and total delegation cost to decide whether delegation that is merely permitted is worthwhile or to shape delegation that is explicitly required.
  Keeps design and final judgment in the main session and defines the required Scope, Deliverable, and Output Format.
---

# Task Delegation Policy

Delegate by task independence, not by model price.
A subagent is useful when it can complete a bounded unit of work without repeatedly consulting the main session and the main session can verify the result from a concise report or diff.

This skill does not authorize delegation.
Use it only after the current host permits subagent delegation, and obey that host's authorization rules.

Permission to delegate is not the same as a requirement to delegate.
A user request or an instruction in the procedure being followed may require delegation, but that requirement does not replace the host's permission.
The host's authorization rules determine whether delegation may proceed, even when stated in terms of cost.
When delegation is permitted but not explicitly required, decide whether to delegate using task independence and total delegation cost.
When delegation is permitted and explicitly required, do not cancel it solely because work in the main session would cost less.
Within that requirement's constraints, this skill still determines the delegated scope, agent type, number of launches, whether to continue an existing agent or spawn a new one, and the delegation brief.

## Keep judgment in the main session

The main session retains work that determines or accepts the direction:

- decomposing the problem and setting priorities;
- choosing the design or implementation approach;
- resolving ambiguity and making high-consequence trade-offs;
- reviewing the returned work and deciding whether it is complete;
- delivering the final answer.

A request for a second opinion is also judgment work.
Use `subagent-consultation`, not a task delegate.

## Delegate independent work

Delegate a unit of work when its boundaries, inputs, and acceptance criteria can be stated before it starts and its result can be integrated without ongoing coordination.
Typical candidates are:

- mechanical or repetitive edits whose correctness can be checked directly;
- broad, read-heavy exploration when the main session needs only the conclusion and citations;
- a self-contained implementation whose design, interfaces, and acceptance criteria are already settled.

Independence does not imply low difficulty.
Choose a subagent capable of the work; model price is a secondary implementation choice, not the delegation criterion.

## Account for total delegation cost

When delegation is permitted but not required, do not delegate when the total overhead is likely to exceed doing the work in the main session.
Include all of the following, not just model price:

- reconstructing the relevant context in the subagent;
- starting tools and preparing its environment;
- coordinating clarifications and retries;
- reviewing and integrating the result.

Keep the work in the main session when it is short, tightly coupled to the current decision, or already supported by context the main session holds.
When delegation is explicitly required, use total cost to shape and limit the delegation rather than as the sole reason to cancel it.
Price and rate limits may break a tie only after independence and total overhead have been considered.

## Write the brief

Every delegation brief must specify:

- **Scope**: the files, components, or question to handle, including exclusions.
- **Deliverable**: the result that must exist and its acceptance criteria.
- **Output Format**: the exact form to return, such as a diff, a cited summary (`path:line`), or a list of changed files and test results.

Tell the subagent to return conclusions and evidence, not a transcript of its investigation.
Include only the context needed to complete the bounded task.
If the subagent discovers an unresolved design choice or work outside the scope, it must stop that part and report the decision needed instead of expanding the task.

Example:

> Scope: Find where rate limiting is implemented, including middleware, configuration, and counters. Do not edit files.
> Deliverable: Explain the mechanism, configured limits, and application scope, with enough evidence for the main session to review.
> Output Format: A concise conclusion with `path:line` citations. Do not include a transcript or full source listings.

## Review and integrate

The main session remains responsible for validating the result.
Inspect the cited evidence or diff, run checks appropriate to the risk, resolve conflicts with other work, and make the final decision.

## Platform notes

Use the subagent mechanism exposed by the current host and obey its authorization rules.
Tool names and model override support vary by host and build, so read them from the active environment rather than assuming a particular interface.

This repository provides `bulk-edit` for mechanical edits and `search` for broad investigation.
They are specialized by task shape; their configured models are platform details.
