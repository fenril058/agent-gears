---
name: skill-improver
description: Read the open `skill-feedback` issues, verify each cited occurrence at its source, and propose the smallest edit to one skill that would have changed those outcomes — as a pull request whose every hunk cites an occurrence. Use when the user asks to process accumulated skill feedback, improve a skill from observed failures, or run the improvement loop. Proposing no change is a complete result; it does not measure or claim improvement.
argument-hint: "[skill-name]"
---

# Skill Improver

This is the observer half of the improvement loop.
`skill-feedback` records occasions; this skill turns verified occasions into one proposed edit.

It runs when a human invokes it, not on a schedule.
A run with no verifiable evidence must end with no change, and that is a complete result.

## No change is the default

State the verdict first, before any proposal.

Report no change, with the reason, when any of these holds:

- No open issue cites a source that can be verified.
- The cited occurrences trace to model behaviour rather than to the skill's text.
- No wording would have changed the outcome without breaking the cases the skill currently handles.
- The evidence is one occurrence of something the skill already addresses.

A run that finds nothing is the loop working.
Do not manufacture an edit to justify the run.
Instructions written to fill a report become the next thing someone has to delete.

## Read the open feedback

```
gh issue list --label skill-feedback --state open \
  --json number,title,body,createdAt,comments
```

Group by the skill each issue names.
Count **independent occurrences**, not issues: two issues describing the same incident are one occurrence.

If the invocation named a skill, restrict the run to it, and still report no change when its evidence does not support one.

## Verify at the source

The issue body is a pointer, not the evidence.
Read the source it cites before treating anything in it as fact.

- `session: <id>` — `ctx show <id>`, or `ctx search` when the id is partial.
- `PR #<n>` / commit — `gh pr view`, `git show`.
- A path — read the file at the revision the issue describes.

Drop any occurrence you cannot verify, and say in the report that you dropped it.
An unverifiable report is not weak evidence; it is no evidence.

Check what the skill's text actually said at the time.
A rule added after the occurrence already covers it, and needs no second rule.

## Choose one skill

One run edits one skill and opens one pull request.

Pick the skill with the most verified independent occurrences.
Break a tie by evidence strength, not issue count — one occurrence with a clear stated reason outranks three verdicts without one.

## Propose the smallest edit

For each candidate edit, answer one question: **would this text have changed the cited outcome?**
If you cannot say yes about a specific occurrence, the edit is not supported. Drop it.

Write direction and its reason, not exhaustive rules.
Stating why a rule exists lets the agent generalize to the next case; an enumerated list only covers the cases already seen.

Before proposing, check the edit against:

- `rules/always-on.md` and the host's own instructions — a rule that contradicts either will not win, and it makes both harder to read.
- Other skills — if another skill already states it, the gap was routing, not wording.
- The skill's `description` — an edit to the body that the description no longer matches breaks triggering.

## Deletion is a result

An edit that removes text is a first-class outcome, and this repository's evidence favours it.
Propose removal when the occurrences show that the skill's text did not fire, restated what the host already injects, or duplicated another skill.

PR #60 is the worked example: 185 lines of delegation policy were removed because each specific rule turned out to be stated elsewhere or already applied by default.

## Open the pull request

Branch, commit, and open a PR against the default branch.
Never merge it — the human review is what closes the loop.

The PR body states, for every hunk:

- the occurrence it comes from, with the verified source;
- why the reason in that occurrence produces this wording;
- what the edit does not claim.

Link the issues it consumed with `Refs #<n>`.
Do not close them; they close when the change is merged and someone decides it addressed them.

## What this does not claim

This skill is a health check under `docs/adr/0001-evaluation-infrastructure-ownership.md`: a non-causal inspection of failures observed in real use.

It asserts only that a given wording would have changed a specific cited outcome.
It does not assert that the skill is better, that behaviour improved measurably, or that a comparison was run.
Any claim of a measured effect requires the isolation conditions ADR 0001 sets, which this loop does not establish.
