---
name: skill-improver
description: Read the open `skill-feedback` issues on fenril058/agent-gears, verify each cited occurrence at its source, and propose the smallest edit to one skill in that repository as a pull request whose every substantive hunk cites an occurrence. Use when the user asks to process accumulated skill feedback, improve a skill from observed failures, or run the improvement loop. Proposing no change is a complete result; it does not measure or claim improvement.
compatibility: Requires git and the gh CLI (GitHub CLI, authenticated) on PATH, with write access to fenril058/agent-gears. `ctx` is required to verify session-sourced occurrences, and `ghq` is used to locate the checkout; without ghq, ask the user for the path.
argument-hint: "[skill-name]"
---

# Skill Improver

This is the observer half of the improvement loop.
`skill-feedback` records occasions; this skill turns verified occasions into one proposed edit.

It runs when a human invokes it, not on a schedule.
A run with no verifiable evidence must end with no change, and that is a complete result.

## Work on agent-gears, wherever you are invoked

Every issue, branch, commit, and pull request in this loop belongs to `fenril058/agent-gears`, because that is where the skill sources live.
The session invoking this skill is usually somewhere else.

Resolve the checkout before touching git:

```
ghq list --exact --full-path fenril058/agent-gears
```

If `ghq` is unavailable or returns nothing, ask the user for the path rather than guessing.
Run every git command against that path, and pass `--repo fenril058/agent-gears` on every `gh` call.
Never branch, commit, or open a pull request in the current working directory.

## No change is the default

State the verdict first, before any proposal.

Report no change, with the reason, when any of these holds:

- No open issue cites a source that can be verified.
- The cited occurrences trace to model behaviour rather than to the skill's text.
- No wording addresses the stated reasons without breaking the cases the skill currently handles.
- The evidence is one occurrence of something the skill already addresses.

A run that finds nothing is the loop working.
Do not manufacture an edit to justify the run.
Instructions written to fill a report become the next thing someone has to delete.

## Read the open feedback

```
gh issue list --repo fenril058/agent-gears --label skill-feedback --state open \
  --limit 100 --json number,title,body,createdAt,comments
```

The `gh` default is 30 issues, which would silently truncate the set you then count occurrences in.
Set the limit explicitly, and if the result reaches it, page with `--search` on a date range until you have read them all.

Group by the skill each issue names.
Count **independent occurrences**, not issues.
Two issues describing the same incident are one occurrence.

If the invocation named a skill, restrict the run to it, and still report no change when its evidence does not support one.

## Verify at the source

The issue body is a pointer, not the evidence.
Read the source it cites before treating anything in it as fact.

- `provider: <name>` + `session: <provider session id>` — map it first, then read it:

  ```
  ctx locate session --provider <name> --provider-session <id>
  ctx show session <ctx session id>
  ```

- `PR #<n>` or a commit URL — `gh pr view --repo <owner>/<repo>`, `git show`.
- `<owner>/<repo>@<commit>:<path>` — read the file at that commit, not at HEAD.

Drop any occurrence you cannot verify, and say in the report that you dropped it.
An unverifiable report is not weak evidence; it is no evidence.

**Not yet indexed is not unverifiable.**
`ctx` indexes a session after it ends, so an issue filed during the session it describes will not resolve on the first try.
Leave that occurrence for a later run and say so; do not drop it and do not count it.

Check what the skill's text actually said at the time of the occurrence.
A rule added after it already covers it, and needs no second rule.

## Choose one skill

One run edits one skill and opens one pull request.

Pick the skill with the most verified independent occurrences.
Break a tie by evidence strength, not issue count.
One occurrence with a clear stated reason outranks three verdicts without one.

## Propose the smallest edit

For each candidate edit, answer one question.
**Does this wording address the reason the occurrence stated, and does it point away from the observed action?**
If you cannot say yes about a specific occurrence, the edit is not supported.
Drop it.

Write direction and its reason, not exhaustive rules.
Stating why a rule exists lets the agent generalize to the next case.
An enumerated list only covers the cases already seen.

Before proposing, check the edit against:

- `rules/always-on.md` and the host's own instructions.
  A rule that contradicts either will not win, and it makes both harder to read.
- Other skills.
  If another skill already states it, the gap was routing, not wording.
- The skill's `description`.
  An edit to the body that the description no longer matches breaks triggering.

## Deletion is a result

An edit that removes text is a first-class outcome, and this repository's evidence favours it.
Propose removal when the occurrences show that the skill's text did not fire, restated what the host already injects, or duplicated another skill.

PR #60 is the worked example.
185 lines of delegation policy were removed because each specific rule turned out to be stated elsewhere or already applied by default.

## Open the pull request

Branch, commit, and open a PR against the default branch of the resolved checkout.
Never merge it — the human review is what closes the loop.

The PR body states, for every substantive hunk:

- the occurrence it comes from, with the verified source;
- how the wording addresses the reason that occurrence stated;
- what the edit does not claim.

Hunks derived mechanically from a substantive one need no citation of their own: the `SKILL-ja.md` mirror, `README.md`, `marketplace.json` and `plugin.json` metadata, and version bumps.
Name them as derived and say which hunk they follow.

Link the issues it consumed with `Refs #<n>`.
Do not close them; they close when the change is merged and someone decides it addressed them.

## What this does not claim

This skill is a health check under `docs/adr/0001-evaluation-infrastructure-ownership.md`: a non-causal inspection of failures observed in real use.

It asserts only that the wording directly addresses the reason a cited occurrence stated, and points away from the action that was observed.
It does not assert that the outcome would have been different, that the skill is better, that behaviour improved measurably, or that a comparison was run.
A single stochastic run does not establish a counterfactual.
Any claim of a measured effect requires the isolation conditions ADR 0001 sets, which this loop does not establish.
