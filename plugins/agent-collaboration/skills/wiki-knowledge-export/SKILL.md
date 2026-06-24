---
name: wiki-knowledge-export
description: >-
  Export durable, cross-branch knowledge to the GitHub wiki. Use when a finding is worth
  keeping beyond the current branch/PR — a measurement, a tool evaluation, an
  architecture decision, a convention, or a cross-cutting gotcha about the system itself.
  First judge durable vs ephemeral; ephemeral per-branch context goes to
  conversation-context-export instead. Triggers: "save this to the wiki", "write this up
  as durable knowledge", "this should outlive the branch".
---

# Wiki knowledge export procedure

Write durable knowledge — knowledge that stays useful after the originating branch is
gone — to the GitHub wiki (a separate git repo), and keep the `Home.md` index in sync.

This is the **durable tier**. Its sibling is `conversation-context-export`, the
**ephemeral tier** (per-branch/PR context written to `.dev/contexts/` + a PR comment).
Route each finding to the right tier with the judgment below.

## 1. Judge: durable or ephemeral

Treat a finding as **durable** (belongs in the wiki) only when **all three** hold:

1. It is about the **project / system / tooling itself**, not about one specific change.
2. It stays useful **after the originating branch is merged or abandoned**.
3. A future session on an **unrelated branch** would benefit from it, or would otherwise
   re-discover it.

Sharp tests:

- **Branch-delete test**: "If this branch vanished in six months, would I still want
  this?" Yes → durable.
- **Title test**: the natural title is a **topic/concept** (durable) vs a
  **branch/PR/change** (ephemeral).
- **Kind test**: measurements, tool evaluations, architecture decisions (ADRs),
  conventions/policies, cross-cutting system gotchas → durable. Per-change rationale,
  rejected alternatives for *this* PR, remaining work on *this* branch, one-off debugging
  notes → ephemeral.

Routing:

- **Ephemeral** → do not use this skill. Use `conversation-context-export`.
- **Mixed** (a per-change investigation that also yielded a durable fact) → split: the
  durable fact goes to the wiki here; the change rationale goes to
  `conversation-context-export`.
- **Unsure** → present the finding and the judgment to the user and ask which tier.

## 2. Resolve the wiki location

Run with the Bash tool:

```
gh repo view --json url -q .url
```

Let `{repo-url}` be the output (e.g. `https://github.com/owner/repo`). Then:

- Wiki git remote: `{repo-url}.wiki.git`
- A page's web URL: `{repo-url}/wiki/{PageName}` (the filename without `.md`)

Confirm the wiki is reachable:

```
git ls-remote {repo-url}.wiki.git
```

- If it lists refs, proceed.
- If it errors or lists nothing, the wiki is not initialized (Wikis disabled, or no first
  page ever created). Report to the user: "Enable the repo's Wikis and create the first
  page once via the web UI, then re-run." Stop — you cannot bootstrap a never-initialized
  wiki by push.

## 3. Clone the wiki

Clone into a scratch directory (not inside the main repo working tree):

```
git clone {repo-url}.wiki.git {scratch}/repo.wiki
```

Use a path under the session scratch directory. Match the remote protocol the user's git
already uses (`gh auth status` shows ssh vs https); `gh repo view` returns https, so if
the user's git is ssh, use `git@github.com:owner/repo.wiki.git` instead.

## 4. Choose the page and draft it

### Page name

Use a **topic-named** file, matching the house style of existing pages (e.g.
`SKILL-token-ja-en.md`, `waza-check.md`). Title Case or kebab; words joined by `-`. The
page name must read as a concept, not a change.

### New vs update

Check whether `{PageName}.md` already exists in the clone.

- **New page**: create it.
- **Existing page**: read it first, then update by these rules (the wiki is inherently
  cross-session and possibly cross-author):
  - Keep existing items as a rule; append new information.
  - **Correct or delete only what you actually re-verified and disproved.** Don't delete
    on inference alone.
  - The page always represents the currently correct state. Leave history to git (no
    strikethroughs / changelog inside the page).

### Page content

Read [TEMPLATE.md](TEMPLATE.md) in this skill's directory and follow it. Key points:

- Make the page **self-contained**: the originating branch will be gone, so include
  enough context to stand alone.
- For measurements/evaluations, record the **date and the source command/commit** so
  staleness is visible later.
- Apply the same "emphasize / keep thin" discipline as `conversation-context-export`:
  durable facts, decisions, and their grounds — not war stories or things obvious from
  the code.

## 5. Update the Home.md index

Open `Home.md` and, under the page-list heading (e.g. `## ページ一覧`), add a one-line
pointer in the existing format if not already present:

```
- [[{PageName}]] — {one-line hook of what the page records and why it matters}
```

For an updated existing page, refresh the hook only if its scope changed.

## 6. Confirm, then commit and push

Writing to the wiki is an outward-facing publish. **Before pushing**, show the user the
drafted page (and the `Home.md` change) and confirm — use the AskUserQuestion tool unless
the user already said to push without asking.

After confirmation, in the clone:

```
git add {PageName}.md Home.md
git commit -m "{concise message}"
git push
```

## 7. Report

Report the page's web URL (`{repo-url}/wiki/{PageName}`) to the user. If you split a
finding, also report what went to `conversation-context-export`.

## Related skills

- **conversation-context-export**: the ephemeral tier — per-branch/PR context to
  `.dev/contexts/` + a PR comment. Route ephemeral findings there.
- **conversation-context-import**: load saved ephemeral context.
