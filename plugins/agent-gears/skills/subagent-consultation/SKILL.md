---
name: subagent-consultation
description: >-
  Consult another agent for a second opinion when the user asks to consult a subagent,
  ask a subagent, or have one review something, or a calling skill requests consultation.
  Distinguish independent review from critique of a supplied proposal, select an
  available consultant, and verify and synthesize its answer within the requested scope.
---

# Subagent consultation

Own the consultation question, consultant selection, follow-up decisions, and synthesis.
Use the host's available agent tools or an execution adapter for the run itself.

## Purpose and scope

Use the user's question and the established task context to determine the target and the kind of judgment needed.
Proceed without a depth-selection question when these are clear.
Ask only for missing information that materially affects the consultation and cannot be inferred from that context.
Respect explicit requirements on the target, model, execution means, and prohibited actions.
Apply model and execution-mechanism requirements when launching the consultant, and include the target and applicable operation constraints in its instructions.

Keep exploration within the requested scope, including related code and sources needed to assess it.
A request about one function does not authorize a repository-wide audit.
A consultation or review request alone does not authorize implementing fixes, committing, pushing, or posting externally.
Continue investigation and operations already authorized by the task without asking for permission again.

## What the consultant receives

Provide the question, target materials or exact revisions, evaluation criteria, relevant constraints, and the permitted operations.
Make the prompt self-contained for a consultant without this conversation.
Ask for conclusions tied to evidence and for any missing information or failed verification that affects them.

Choose the framing by purpose:

- **Independent review:** supply raw target materials and evaluation criteria, withholding your findings, suspected locations, preferred answers, and conclusions.
  Check what conversation and background the launch mechanism actually passes, including automatic history inheritance; omitting a hypothesis from the prompt alone does not keep it out of inherited context.
  Use a fresh context without that history when available.
- **Design consultation or critique of a proposal:** supply the proposal being evaluated, its rationale, and constraints so the consultant can challenge it and offer alternatives.
  Distinguish your hypotheses from established facts.

Do not impose the same framing on every consultation.
For example, "review this diff once" calls for an independent read; "evaluate this design" requires the design.
If the available mechanism cannot meet a requested independence condition, report that limitation rather than calling the result independent.

## Consultant and execution mechanism

Read the current host's tool descriptions and available capabilities before choosing how to launch, continue, and collect a consultant's answer.
Do not assume a tool named `Agent`, a particular schema, or a fixed model name exists.
Use a consultant suited to the judgment and follow any user or caller requirements.
Treat these as separate capabilities:

- **Model selection:** the host may allow an override; that alone says nothing about history inheritance or model family.
- **Fresh context:** a consultant without the main conversation can reread materials without seeing your conclusions.
- **Different model family:** when available and appropriate, it may expose different blind spots, but it does not guarantee independent reasoning or errors.

Do not silently replace a required model, family, or context condition with a weaker substitute.
If no available consultant meets the requirement, state what cannot be fulfilled and distinguish your own analysis from the missing consultation.

### Host-specific execution

On Claude Code, use the current `Agent` tool when available and suitable; inspect its model and continuation options rather than prescribing them here.
When selecting the Codex CLI from Claude Code, use [codex-consultation](../codex-consultation/SKILL.md).
Supply the complete prompt, absolute target worktree path, whether tests/builds/diagnostics may be needed, and whether remote information is required.
That adapter owns execution capability, the run's time bound, cleanup, and execution facts.
It completes each call synchronously in the foreground with an answer or explicit failure; it keeps no persistent thread and returns no background job for later collection.

On Codex, use the exposed subagent operations according to their descriptions, including their history-inheritance controls.
For follow-up, use an operation that actually starts or resumes work: merely delivering a message may leave an idle agent idle.
Separate threads do not by themselves establish fresh context or a different model family.

## Verification, follow-up, and stopping

Check the returned answer against primary evidence before adopting its claims.
Keep supported findings, unresolved hypotheses, and unavailable evidence distinct.
A consultant's agreement is not verification, and disagreement calls for comparing reasons and evidence.

Distinguish these outcomes:

- **No usable answer:** report the execution failure.
  If an untried suitable consultant can still meet the request within its limits, use it; fallback selection belongs here, not in the execution adapter.
  Do not repeat exhausted attempts or silently relax requirements.
  If no suitable option remains, report the missing consultation and give only the analysis you could perform yourself.
- **Usable answer with some failed execution:** keep the usable parts and identify which conclusions depend on missing information.
  Retrieve that information within existing authorization when feasible, correct affected conclusions, and report what remains unverified.
  Do not discard the whole answer or switch consultants merely because one fetch, test, or diagnostic failed.

Use follow-up to resolve a material objection, evidence gap, or unanswered part of the question when the request permits it.
A single review needs no additional consultation when its answer is sufficient.
A request for deep consultation calls for pursuing important unresolved points, not meeting a default round count.

Continue the same consultant when its prior context helps resolve the issue and the mechanism supports continuation.
Use a fresh reader when an independent judgment is needed; a consultant already shown your hypothesis is no longer a fresh reader of it.
For a continued conversation, send the focused question and new evidence.
For a new invocation, include the necessary background, question, constraints, and evidence again; include the earlier answer only when the purpose permits it.
The Codex adapter is always a new invocation, even for follow-up on the same issue.

Honor explicit round instructions and stop at their limit; report any issue left open at that point.
When no further rounds are required, stop as soon as the requested question is adequately answered, further consultation makes no progress, or the remaining gap cannot be resolved with available authorized means.
Do not keep adding questions or consultants to seek exhaustive coverage.
Report remaining uncertainty instead of retrying indefinitely or inventing permission changes or host-configuration workarounds.

## Reporting

Scale the report to the consultation: a short review can be a paragraph or a few bullets.
State what was consulted and who actually answered, the main points, your evidence-based assessment (including material disagreements), and any limitations that affect the result.
Include follow-up outcomes or failed attempts when they matter to that assessment.
Use headings only when they help; no fixed report template or agent-name heading is required.
