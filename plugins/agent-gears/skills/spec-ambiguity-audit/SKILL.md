---
name: spec-ambiguity-audit
description: Audit a spec, design doc, or plan for ambiguities that leave an implementer unable to choose the intended behavior. Use when the user asks to find gaps or underspecified behavior, or when that audit is clearly part of the requested work. Implementation from a non-trivial document alone does not call for this skill; architectural design review is a separate task.
---

# Spec Ambiguity Audit

Find decisions an implementer cannot make from the supplied documents without guessing.
The useful discipline is to separate a reading without project background from verification against the source, so familiarity does not silently fill gaps and misreadings do not reach the user as findings.

## Scope and reading

Use the audit scope already authorized by the request; do not ask for the same permission again.
An audit alone does not authorize rewriting the spec or implementing it.
Focus on ambiguity, contradictions, undefined terms, and omissions that change implementation or observable behavior within the document's scope.
Do not demand exhaustive detail about excluded features or choices the implementer is free to make.

For a short audit, read the document directly unless the user requests an independent read.
Delegate an independent read when requested, or when it will help expose assumptions the main agent may supply unconsciously in a substantial document.
Use [references/prompt-template.md](references/prompt-template.md), supplying the document and relevant references, without the main conversation, project summary, suspected gaps, or intended answers.
Keep the reader within those sources; unrelated code, history, and project memory would change the audit into a different investigation.

Check the tools and instructions available in the current session before choosing an execution method.
Prefer an available subagent tool that can omit parent conversation (for example, `fork_turns: "none"` where supported), or an available fresh-run CLI whose context behavior is understood.
Verify what instructions and memory it loads; a separate thread alone does not establish a reading without background.
Choose an economical model if adequate and available; model selection and conversation inheritance are separate capabilities.
Do not require manual session switching when a suitable tool is available, or change host configuration to enable this audit.

If independent execution is unavailable, disclose the limitation and perform the source review possible in the current session.
If the user specifically requires an independent read, report that part as unperformed.
Rereading in the same conversation does not satisfy it.

## Verify candidate findings

Treat all findings, including an independent reader's list, as candidates until verified.
As the main agent, verify each candidate against the actual source; asking its author to approve the list is insufficient.
Read the cited passage and its context, then check relevant definitions, other sections, and referenced documents before retaining an item as unresolved.
Absence from a local excerpt is not evidence of absence from the document.
If a necessary reference is unavailable, identify it as a verification limit rather than declaring the specification silent.

Keep an item only when competing interpretations or a missing decision would materially affect implementation and the supplied sources do not settle it.
Drop answered questions, misreadings, duplicates, and demands outside the document's scope.
Do not narrow or invent a new question merely to preserve a rejected item.
When an answer requires an unstated inference, distinguish that inference from an explicit rule and assess whether the implementation choice remains unresolved.

For long documents with sparse citations, optionally use [scripts/extract_context.py](scripts/extract_context.py) to reduce repeated reading.
It extracts text; the main agent still judges the findings.
Supply ranges from the same file together so expanded overlapping or adjacent windows are merged:

```bash
python3 <skill-dir>/scripts/extract_context.py <file> --margin 10 \
  --range 62 --range 316-318 --range 300-301
```

Choose the margin for the passage; extraction does not replace checking other sections or references.
For short documents or excerpts covering most of the file, just read the source once.

## Report

Report only unresolved findings, each with a source location, the decision the text leaves open, and its implementation consequence.
Use line numbers when available, otherwise a stable section or quotation; locate missing requirements at the section that needs them rather than inventing a line citation or silently dropping the gap.
Keep the report proportional to the findings; zero findings is a valid result, and no fixed count or table is required.
State the sources reviewed, whether an independent read actually ran, and any limits that affect the conclusions.
A retained/total ratio does not measure audit accuracy: document maturity and the candidate list both affect it.
