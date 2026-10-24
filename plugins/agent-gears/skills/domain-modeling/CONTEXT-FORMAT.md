# CONTEXT.md Format

Apply the recording scope established in [SKILL.md](SKILL.md) before creating or updating files.
Only agreed terms belong in the glossary; a tentative or withdrawn name does not create an entry.

## Structure

```md
# {Context Name}

{One or two sentences on what this context is and why it exists.}

## Language

**Order**:
A customer's request for goods, from placement until it is fulfilled or cancelled.
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Be opinionated.**
  When several words exist for one concept, propose the best and list the rest under `_Avoid_` once agreed.
  If the field has an established term, that is the one to pick.
- **Keep definitions tight.**
  Use one or two sentences defining what it IS, not what it does.
- **Only terms specific to this project's context.**
  General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them constantly.
  Before adding a term, check whether it is unique to this context rather than a general concept.
- **No implementation details.**
  A term's definition should survive a rewrite of the code that implements it.
- **Group under subheadings** when natural clusters emerge.
  A flat list is fine when all terms belong to one cohesive area.

## Single vs multi-context repos

**Single context (most repos):** one `CONTEXT.md` at the repo root.

**Multiple contexts:** a `CONTEXT-MAP.md` at the root lists the contexts, where they live, and how they relate:

```md
# Context Map

## Contexts

- [Ordering](./src/ordering/CONTEXT.md) — receives and tracks customer orders
- [Billing](./src/billing/CONTEXT.md) — generates invoices and processes payments
- [Fulfillment](./src/fulfillment/CONTEXT.md) — manages warehouse picking and shipping

## Relationships

- **Ordering → Fulfillment**: Ordering emits `OrderPlaced`; Fulfillment consumes it to start picking
- **Fulfillment → Billing**: Fulfillment emits `ShipmentDispatched`; Billing consumes it to generate invoices
- **Ordering ↔ Billing**: shared types for `CustomerId` and `Money`
```

Infer which structure applies:

- `CONTEXT-MAP.md` exists → read it to find the contexts.
- Only a root `CONTEXT.md` → single context.
- Neither → single context; create the root `CONTEXT.md` only when recording is within scope and the first agreed term needs saving.

With multiple contexts, infer which one the current topic belongs to.
If unclear, ask.

## Updating

Changing a glossary definition changes the meaning of every document that used the term.

- When recording is entrusted to you, add agreed terms inline without asking for the same recording permission per term.
- **Changing an existing definition needs agreement to that change.**
  State the old and proposed definitions and resolve the difference before editing.
  If that specific change is already agreed, apply it without reconfirming.
  Permission to maintain the glossary alone does not authorize silent redefinition.
- Removing a term needs the same treatment.
  Prefer moving it to `_Avoid_` under the term that replaced it, so the old word still resolves.
