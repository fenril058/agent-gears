---
name: durable-knowledge-export
description: >-
  Export durable knowledge to a persistent home outside the repo — the GitHub wiki, or a
  dedicated knowledge repo. Use when a finding is worth keeping beyond the current
  branch/PR: a measurement, a tool evaluation, a convention, or a cross-cutting gotcha
  about the system itself. First judge durable vs ephemeral; ephemeral per-branch context
  goes to conversation-context-export instead, and an architectural decision about this
  codebase goes to domain-modeling. Triggers: "save this as durable knowledge", "write
  this to the wiki", "this should outlive the branch".
compatibility: Requires git and the gh CLI (GitHub CLI, authenticated) on PATH; gh is used to read repo state and write to the GitHub wiki. The knowledge-repo sink additionally requires the AGENT_KNOWLEDGE_REPO environment variable pointing at a local git repo; without it that sink is unavailable and the skill stops rather than inventing a location.
---

# Durable knowledge export procedure

Write durable knowledge — knowledge that stays useful after the originating branch is
gone — to a persistent home **outside the repo**, and keep that home's index in sync.

Outside the repo is the point. Durable knowledge that lands inside the working tree gets
entangled with the branch it came from and competes with the repo's own records; this
skill deliberately writes elsewhere.

This is the **durable tier**. It has two siblings:

- `conversation-context-export` — the **ephemeral tier** (per-branch/PR context in
  `.dev/contexts/` + a PR comment).
- `domain-modeling` — the **record tier** (this codebase's glossary and architectural
  decision records, committed alongside the code).

Route each finding with the judgment in section 1.

The durable home is chosen by **sink resolution** (section 2): a reachable GitHub wiki for
repo-scoped knowledge, a dedicated knowledge repo for knowledge that spans repos. The
judgment in section 1 never changes — only the sink adapts to the environment.

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
- **Kind test**: measurements, tool evaluations, conventions/policies, cross-cutting
  system gotchas → durable. Per-change rationale, rejected alternatives for *this* PR,
  remaining work on *this* branch, one-off debugging notes → ephemeral.

Routing:

- **Ephemeral** → do not use this skill. Use `conversation-context-export`.
- **An architectural decision about this codebase** → do not use this skill. Use
  `domain-modeling`. An ADR is immutable and versioned with the code it explains; the
  pages here are living documents that always show the current state, so a decision
  stored here would lose the record of what was decided and later reversed. The same
  goes for this project's vocabulary — that is `CONTEXT.md`, also `domain-modeling`.
- **Mixed** → split: the durable fact goes to the durable home here; the change rationale
  goes to `conversation-context-export`; the decision goes to `domain-modeling`.
- **Unsure** → present the finding and the judgment to the user and ask which tier.

## 2. Resolve the sink

Resolve the sink explicitly — do not assume. Two questions decide it: **what the
knowledge is scoped to**, then **what is reachable**.

### 2-1. Scope

- **Repo-scoped** — the knowledge is about *this* repo (its build, its quirks, a
  measurement taken here). Continue to 2-2.
- **Cross-repo** — the knowledge spans repos (an evaluation of a tool used everywhere, an
  environment quirk of this machine, a convention applied across projects). A wiki belongs
  to one repo and cannot hold this. The sink is the **knowledge repo** → section 3B. If no
  knowledge repo is configured, go to 2-3.

### 2-2. Reachability (repo-scoped knowledge)

```
gh repo view --json url,hasWikiEnabled -q '.url, .hasWikiEnabled'
```

(If `gh` fails or the repo has no GitHub remote, treat it as "no wiki".)

1. **GitHub wiki (preferred)** — let `{repo-url}` be the URL. Check reachability:
   ```
   git ls-remote {repo-url}.wiki.git
   ```
   If it lists refs, the sink is the **wiki** → section 3A.
2. **No reachable wiki, knowledge repo configured** → the sink is the **knowledge repo**
   → section 3B.
   - One-line note to the user: if they would rather use the wiki, enable Wikis and create
     the first page once via the web UI, then re-run. (You cannot bootstrap a
     never-initialized wiki by push; enabling `has_wiki` alone does not create the first
     page.)
3. **Neither** → go to 2-3.

### 2-3. No sink available

**Do not invent one.** Writing durable knowledge into the working tree is what this skill
exists to avoid, and a scratch directory would lose it.

Stop, tell the user which checks failed, and offer the two ways forward:

- **Enable the wiki** — Wikis on, first page created once via the web UI. Best when the
  knowledge should reach teammates.
- **Set up a knowledge repo** — create a git repo and point `AGENT_KNOWLEDGE_REPO` at it
  (section 3B describes the layout). Best for personal or cross-repo knowledge.

Report the finding in full in your reply so it is not lost while they decide.

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

## 3B. Sink: knowledge repo

A git repo dedicated to durable knowledge, living outside every project it describes.
`AGENT_KNOWLEDGE_REPO` holds its local path. It is the only sink that can hold knowledge
spanning several repos, and the fallback when a repo has no wiki.

### Layout

Pages are filed under the path of the repo they describe, mirroring the ghq layout so the
location is computable rather than remembered:

```
{AGENT_KNOWLEDGE_REPO}/
  README.md                       ← top-level index
  github.com/{owner}/{repo}/
    README.md                     ← per-repo index
    {Topic}.md
  _cross/
    README.md
    {Topic}.md                    ← knowledge spanning repos
```

Derive `{owner}/{repo}` from the target repo's remote, not from its directory name — a
fork whose origin was repointed keeps the upstream owner's directory, so the two disagree.

### Procedure

1. **Locate**: read `AGENT_KNOWLEDGE_REPO`. If it is unset or the path is not a git repo,
   you are in section 2-3 — stop, do not create it silently.
2. **Page**: `{scope-path}/{Topic}.md`, topic-named, where `{scope-path}` is
   `github.com/{owner}/{repo}` for repo-scoped knowledge or `_cross` for cross-repo. New →
   create; existing → read first, then apply the update rules in section 4.
3. **Index**: maintain the `README.md` in the same directory, and add the directory to the
   top-level `README.md` if it is new. Under the page-list heading add
   `- [{Topic}]({Topic}.md) — {hook}` if absent; create the index with that heading if it
   does not exist.
4. **Confirm, then commit** in the knowledge repo (not the project repo):
   ```
   git -C {AGENT_KNOWLEDGE_REPO} add {scope-path} README.md && git -C {AGENT_KNOWLEDGE_REPO} commit -m "{message}"
   ```
   Same git-identity caveat as 3A step 4 if the repo has no configured identity.
5. **Push only if it has an upstream.** `git -C {AGENT_KNOWLEDGE_REPO} remote` — if a
   remote exists, pushing publishes, so confirm first (section 5). If there is no remote,
   committing locally is the whole job; say so rather than reporting a URL.

## 4. Page content and update rules

Read [TEMPLATE.md](TEMPLATE.md) in this skill's directory and follow it for both sinks.
Key points:

- Make the page **self-contained**: the originating branch will be gone, so include
  enough context to stand alone.
- For measurements/evaluations, record the **date and the source command/commit** so
  staleness is visible later.
- Apply the same "emphasize / keep thin" discipline as `conversation-context-export`:
  durable facts and their grounds — not war stories or things obvious from the code.

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
- **Knowledge-repo sink**: show the drafted page and the index change before committing.
  If the repo has a remote, pushing publishes — confirm that separately, same as the wiki.
  Report the file paths, and the commit.
- If you split a finding, also report what went to `conversation-context-export` and
  `domain-modeling`.

## Related skills

- **conversation-context-export**: the ephemeral tier — per-branch/PR context to
  `.dev/contexts/` + a PR comment. Route ephemeral findings there.
- **conversation-context-import**: load saved ephemeral context.
- **domain-modeling**: the record tier — this codebase's glossary (`CONTEXT.md`) and its
  architectural decision records, committed with the code. Route decisions and vocabulary
  there; they are immutable records, not living pages.
