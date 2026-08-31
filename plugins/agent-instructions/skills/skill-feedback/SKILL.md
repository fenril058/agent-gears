---
name: skill-feedback
description: Record one observation of an agent-gears skill behaving wrong as a GitHub issue labeled `skill-feedback` on fenril058/agent-gears, while the evidence is still in the conversation. Use when a skill from this collection gave wrong guidance, failed to fire in the situation its description names, fired when it should not have, or contradicted another instruction — or when the user asks to record feedback about a skill. Do not use for a result no wording in the skill could have changed, for a change already decided, or for a skill this collection does not own.
compatibility: Requires the gh CLI (GitHub CLI, authenticated) on PATH, with write access to fenril058/agent-gears. `ctx` is optional and only used to resolve a session identifier. Install gh from https://cli.github.com.
---

# Skill Feedback

Feedback about a skill disappears when the session ends.
This skill writes one observation down while the evidence is still reachable.

The entry is the input to `skill-improver`, which proposes an edit to the skill's text.
So record only what a change to that text could have prevented.

## Scope

This loop covers the skills this repository owns.
Every issue goes to `fenril058/agent-gears` regardless of where the failure was observed, because that is where the skill's source lives.

Working in another project is the normal case and is not a reason to skip recording.
It is a reason to pass `--repo` on every `gh` call, so the issue never lands in that project's tracker.

Do not record feedback here about a skill this repository does not own.

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
A detailed explanation of why the expected result was expected is worth more than many undetailed reports.
The improver can turn a reason into wording; it can turn a verdict into nothing.

Every entry states:

- **Skill**: the `name` from its frontmatter.
- **Expected**: what should have happened, **and why**.
  The why is what an edit can encode.
  Without it the entry supports no specific wording.
- **Observed**: what the skill actually caused.
- **Source**: see below.
- **Handled in session**: what corrected it at the time, if anything.

### Source must be resolvable to a fixed state

The improver reads the source, not this summary, and it needs the state as it was when the failure happened.

Use one of:

- `provider: <name>` and `session: <provider session id>` — the host's own session identifier, plus which agent it came from (`claude`, `codex`, …).
  The improver maps it with `ctx locate session`.
- `PR #<n>` or a full commit URL.
- `<owner>/<repo>@<commit>:<path>` — a path alone is not enough.
  Without a commit the improver would read today's file and mistake it for the file that produced the failure.

## Confirm before filing

Filing publishes.
`fenril058/agent-gears` is a public repository, so the issue body is world-readable the moment it is created.

Before calling `gh`:

1. Get the user's explicit go-ahead for this specific issue.
   Noticing a failure is not a request to publish one.
   Show them the body you intend to file.
2. **Redact sensitive information** — API keys, tokens, passwords, and personally identifiable information must not appear.
   The same applies to the content of a non-public project you were working in when you observed the failure.
   Quote only what the observation needs.
3. Keep the excerpt minimal.
   The reason generalizes; the customer's source code does not belong in it.

## File it

```
gh issue create --repo fenril058/agent-gears --label skill-feedback \
  --title "<skill-name>: <one-line symptom>" \
  --body "$(cat <<'BODY'
## Skill
<name from frontmatter>

## Expected
...and why.

## Observed
...

## Source
provider: claude / session: <provider session id>
(or: PR #<n> / <owner>/<repo>@<commit>:<path>)

## Handled in session
...
BODY
)"
```

Create the label once if it does not exist: `gh label create skill-feedback --repo fenril058/agent-gears`.

One occasion per issue.
Two occasions that share a cause are still two issues.
The improver counts independent occurrences and needs them separable.

## Confirmations

A confirmation that a skill behaved correctly is worth recording only when it contradicts an open feedback issue.
Then it changes a decision the improver would otherwise make, and it belongs as a comment on that issue rather than as a new one.
Routine confirmations dilute a corpus this small.
