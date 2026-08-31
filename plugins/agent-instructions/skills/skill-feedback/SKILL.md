---
name: skill-feedback
description: Record one observation of a skill behaving wrong as a GitHub issue labeled `skill-feedback`, while the evidence is still in the conversation. Use when a skill gave wrong guidance, failed to fire in the situation its description names, fired when it should not have, or contradicted another instruction — or when the user asks to record feedback about a skill. Do not use for a result no wording in the skill could have changed, or for a change already decided.
---

# Skill Feedback

Feedback about a skill disappears when the session ends.
This skill writes one observation down while the evidence is still reachable.

The entry is the input to `skill-improver`, which proposes an edit to the skill's text.
So record only what a change to that text could have prevented.

## What counts

Record an occasion, not an impression.

- The skill fired and its guidance produced the wrong result.
- The skill did not fire in the situation its `description` names.
- The skill fired where it should not have.
- The skill's instructions contradicted an always-on rule, the host's own instructions, or another skill.

Do not record:

- A result no wording in the skill would have changed.
  That is model behaviour, not skill feedback, and the improver can do nothing with it.
- An aggregate impression such as "this skill feels bloated".
  Without a specific occasion there is nothing to verify.
- A change already decided.
  Edit the skill and open a pull request instead.
  This loop is for observations not yet turned into a decision.

## Write the entry

The reason is the part that generalizes.
A detailed explanation of why the expected result was expected is worth more than many undetailed reports, because the improver can turn a reason into a rule and cannot turn a verdict into anything.

Every entry states:

- **Skill**: the `name` from its frontmatter.
- **Expected**: what should have happened, **and why**.
  The why is what an edit can encode; without it the entry supports no specific wording.
- **Observed**: what the skill actually caused.
- **Source**: where to verify it — a session id, a pull request, a commit, or a path.
  The improver reads the source, not this summary.
- **Handled in session**: what corrected it at the time, if anything.

## File it

```
gh issue create --label skill-feedback \
  --title "<skill-name>: <one-line symptom>" \
  --body "$(cat <<'BODY'
## Expected
...and why.

## Observed
...

## Source
session: <id> / PR #<n> / <path>

## Handled in session
...
BODY
)"
```

Create the label once if it does not exist: `gh label create skill-feedback`.

One occasion per issue.
Two occasions that share a cause are still two issues; the improver counts independent occurrences and needs them separable.

## Confirmations

A confirmation that a skill behaved correctly is worth recording only when it contradicts an open feedback issue.
Then it changes a decision the improver would otherwise make, and it belongs as a comment on that issue rather than as a new one.
Routine confirmations dilute a corpus this small.
