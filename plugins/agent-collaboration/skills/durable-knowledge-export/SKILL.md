---
name: durable-knowledge-export
description: >-
  Export durable, cross-branch knowledge to its best persistent home — the GitHub wiki if
  one exists, otherwise an in-repo docs directory. Use when a finding is worth keeping
  beyond the current branch/PR: a measurement, a tool evaluation, an architecture
  decision, a convention, or a cross-cutting gotcha about the system itself. First judge
  durable vs ephemeral; ephemeral per-branch context goes to conversation-context-export
  instead. Triggers: "save this as durable knowledge", "write this to the wiki/docs",
  "this should outlive the branch".
---

# Durable knowledge export procedure

Write durable knowledge — knowledge that stays useful after the originating branch is
gone — to its best persistent home, and keep that home's index in sync.

This is the **durable tier**. Its sibling is `conversation-context-export`, the
**ephemeral tier** (per-branch/PR context written to `.dev/contexts/` + a PR comment).
Route each finding to the right tier with the judgment in section 1.

The durable home is chosen by **sink resolution** (section 2): a reachable GitHub wiki is
preferred; otherwise an in-repo docs directory. The judgment in section 1 never changes —
only the sink adapts to the environment.

## 1. Judge: durable or ephemeral

Treat a finding as **durable** only when **all three** hold:

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
- **Mixed** → split: the durable fact goes to the durable home here; the change rationale
  goes to `conversation-context-export`.
- **Unsure** → present the finding and the judgment to the user and ask which tier.

## 2. Resolve the sink

Pick the durable home in this order. Resolve it explicitly — do not assume.

```
gh repo view --json url,hasWikiEnabled -q '.url, .hasWikiEnabled'
```

(If `gh` fails or the repo has no GitHub remote, treat it as "no wiki" and go to the
in-repo docs sink.)

1. **GitHub wiki (preferred)** — let `{repo-url}` be the URL. Check reachability:
   ```
   git ls-remote {repo-url}.wiki.git
   ```
   If it lists refs, the sink is the **wiki** → section 3A.
2. **No reachable wiki** → the sink is **in-repo docs** → section 3B.
   - One-line note to the user when falling back: if they would rather use the wiki,
     enable Wikis and create the first page once via the web UI, then re-run. (You cannot
     bootstrap a never-initialized wiki by push; enabling `has_wiki` alone does not create
     the first page.)

State which sink you chose and why before writing.

## 3A. Sink: GitHub wiki

The wiki is a separate git repo with no content REST API, so clone → edit → push.

1. Clone into the session scratch directory (not inside the main repo working tree):
   ```
   git clone {repo-url}.wiki.git {scratch}/repo.wiki
   ```
   Match the protocol the user's git uses (`gh auth status` shows ssh vs https); if ssh,
   use `git@github.com:owner/repo.wiki.git`.
2. **Page**: a topic-named file matching house style (e.g. `SKILL-token-ja-en.md`). New →
   create; existing → read first, then apply the update rules in section 4.
3. **Index**: in `Home.md`, under the page-list heading, add `- [[{PageName}]] — {hook}`
   if absent.
4. **Confirm, then push** (writing to the wiki is an outward-facing publish — see
   section 5):
   ```
   git add {PageName}.md Home.md && git commit -m "{message}" && git push
   ```
   The commit needs a git identity. If global `user.name`/`user.email` are unset (common
   in fresh clones), the commit fails — pass the repo's identity inline:
   `git -c user.name='...' -c user.email='...' commit -m "{message}"` (reuse the values
   from the main repo's `git config user.name`/`user.email`).
5. Page web URL to report: `{repo-url}/wiki/{PageName}`.

## 3B. Sink: in-repo docs

A version-controlled docs directory in the main repo. Unlike `.dev/contexts/` (ephemeral,
not merged), this is **docs-as-code**: it is committed and merged to the default branch
through the normal PR flow, where it lives permanently.

1. **Directory**: default `docs/knowledge/`. Create it if absent. (If the repo already has
   a conventional docs location, prefer it and tell the user.)
2. **Page**: `docs/knowledge/{Topic}.md`, topic-named. New → create; existing → read
   first, then apply the update rules in section 4.
3. **Index**: maintain `docs/knowledge/README.md`. Under its page-list heading, add
   `- [{Topic}]({Topic}.md) — {hook}` if absent. Create the index with that heading if it
   does not exist.
4. **Do not commit or push from this skill.** Write the files into the working tree and
   let them ride the user's normal commit/PR for the current branch (that is what makes
   them durable on merge). Tell the user the files are written and ready to commit.

## 4. Page content and update rules

Read [TEMPLATE.md](TEMPLATE.md) in this skill's directory and follow it for both sinks.
Key points:

- Make the page **self-contained**: the originating branch will be gone, so include
  enough context to stand alone.
- For measurements/evaluations, record the **date and the source command/commit** so
  staleness is visible later.
- Apply the same "emphasize / keep thin" discipline as `conversation-context-export`:
  durable facts, decisions, and their grounds — not war stories or things obvious from
  the code.

Updating an existing page (either sink is cross-session, the wiki possibly cross-author):

- Keep existing items as a rule; append new information.
- **Correct or delete only what you actually re-verified and disproved.** Don't delete on
  inference alone.
- The page always represents the currently correct state. Leave history to git (no
  strikethroughs / changelog inside the page).

## 5. Confirm and report

- **Wiki sink**: before pushing, show the user the drafted page and the `Home.md` change
  and confirm — use the AskUserQuestion tool unless the user already said to push without
  asking. After push, report the page web URL.
- **In-repo docs sink**: no confirmation needed for the working-tree write (it rides the
  normal PR). Report the written file paths.
- If you split a finding, also report what went to `conversation-context-export`.

## Related skills

- **conversation-context-export**: the ephemeral tier — per-branch/PR context to
  `.dev/contexts/` + a PR comment. Route ephemeral findings there.
- **conversation-context-import**: load saved ephemeral context.
