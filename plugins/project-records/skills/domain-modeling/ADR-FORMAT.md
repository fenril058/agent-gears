# ADR Format

Resolve the ADR directory before writing — see "Resolve the ADR directory" in SKILL.md.
Below, `{adr-dir}` is whatever that resolved to. If it already holds ADRs, **their
conventions win over everything on this page**: match their numbering, front matter, and
section structure rather than imposing this template on a record that already has a style.

## Template

```md
# {Short title of the decision}

{1-3 sentences: the context, what was decided, and why.}
```

That is enough. An ADR can be a single paragraph. The value is in recording *that* a
decision was made and *why* — not in filling out sections.

### Optional sections

Include only when they add genuine value. Most ADRs need none of them.

- **Status** front matter (`proposed | accepted | deprecated | superseded by ADR-NNNN`) —
  useful once decisions start being revisited.
- **Considered options** — only when the rejected alternatives are worth remembering. The
  default home for rejected alternatives is the ephemeral tier
  (`conversation-context-export`); they come here only when the rejection is what makes
  the decision non-obvious.
- **Consequences** — only when non-obvious downstream effects need calling out.

## Numbering

Scan `{adr-dir}` for the highest existing number and increment. Match the existing width
(`0001-slug.md` vs `001-slug.md` vs `1-slug.md`); if the directory is empty, use
`0001-slug.md`.

## Superseding

This is the property that separates an ADR from a wiki page: **an ADR is not edited to
reflect the current state.** When a decision is reversed or replaced:

1. Write a **new** ADR for the new decision, noting `Supersedes ADR-NNNN`.
2. Mark the old one `superseded by ADR-MMMM`. Leave its body intact.

Never delete or rewrite the old ADR. "We decided X, then found out Y and switched to Z" is
the information that makes the record worth keeping; a record that only shows Z is
indistinguishable from never having considered X.

Correcting a typo or a broken link in an old ADR is fine. Changing what it says is not.

## When to write one

All three must hold — see SKILL.md for the bar itself. What typically qualifies:

- **Architectural shape.** "We're using a monorepo." "The write model is event-sourced,
  the read model is projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate via domain
  events, not synchronous HTTP."
- **Technology choices carrying lock-in.** Database, message bus, auth provider,
  deployment target. Not every library — the ones that would take a quarter to swap.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context;
  others reference it by ID only." The explicit no-s matter as much as the yes-s.
- **Deliberate deviations from the obvious path.** "Manual SQL instead of an ORM,
  because X." Anything a reasonable reader would assume the opposite of. These stop the
  next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of compliance."
  "Response times must stay under 200ms because of the partner API contract."
- **Rejected alternatives when the rejection is non-obvious.** If GraphQL was considered
  and REST chosen for subtle reasons, record it — otherwise someone proposes GraphQL again
  in six months.

What does not: reversible choices, obvious ones, and anything with no real alternative.
