# CONTEXT.md Format

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

- **Be opinionated.** When several words exist for one concept, pick the best and list the
  rest under `_Avoid_`. If the field has an established term, that is the one to pick.
- **Keep definitions tight.** One or two sentences. Define what it IS, not what it does.
- **Only terms specific to this project's context.** General programming concepts
  (timeouts, error types, utility patterns) don't belong even if the project uses them
  constantly. Before adding a term, ask: is this unique to this context, or is it a
  general concept? Only the former belongs.
- **No implementation details.** Not a spec, not a scratch pad. A term's definition should
  survive a rewrite of the code that implements it.
- **Group under subheadings** when natural clusters emerge. A flat list is fine when all
  terms belong to one cohesive area.

## Single vs multi-context repos

**Single context (most repos):** one `CONTEXT.md` at the repo root.

**Multiple contexts:** a `CONTEXT-MAP.md` at the root lists the contexts, where they live,
and how they relate:

```md
# Context Map

## Contexts

- [Ordering](./src/ordering/CONTEXT.md) — receives and tracks customer orders
- [Billing](./src/billing/CONTEXT.md) — generates invoices and processes payments
- [Fulfillment](./src/fulfillment/CONTEXT.md) — manages warehouse picking and shipping

## Relationships

- **Ordering → Fulfillment**: Ordering emits `OrderPlaced`; Fulfillment consumes it to
  start picking
- **Fulfillment → Billing**: Fulfillment emits `ShipmentDispatched`; Billing consumes it
  to generate invoices
- **Ordering ↔ Billing**: shared types for `CustomerId` and `Money`
```

Infer which structure applies:

- `CONTEXT-MAP.md` exists → read it to find the contexts.
- Only a root `CONTEXT.md` → single context.
- Neither → single context; create the root `CONTEXT.md` lazily when the first term
  resolves.

With multiple contexts, infer which one the current topic belongs to. If unclear, ask.

## Updating

Unlike the durable tier's living pages, a glossary entry is a definition, and changing one
changes the meaning of every document that used the term. So:

- Adding a term is routine — do it inline, the moment it resolves.
- **Changing an existing definition is not.** Surface it: say what the old definition was,
  what the new one is, and confirm before editing. A silent redefinition is how two people
  end up meaning different things by the same word again.
- Removing a term needs the same treatment. Prefer moving it to `_Avoid_` under the term
  that replaced it, so the old word still resolves.
