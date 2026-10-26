---
name: durable-knowledge-export
description: >-
  Save or update knowledge that should outlive a branch in a GitHub wiki or a dedicated knowledge repository.
  Use when saving is requested or entrusted by the task, such as "save this as durable knowledge" or "update this wiki".
  Merely discovering a useful fact does not call for an export.
compatibility: >-
  Requires git on PATH for Git-based destinations.
  GitHub repository discovery can use the authenticated gh CLI (https://cli.github.com).
  A local knowledge repository needs neither gh nor GitHub access; its path may be supplied explicitly or through AGENT_KNOWLEDGE_REPO.
---

# Durable knowledge export

Save knowledge for future work beyond the originating branch, using a topic page that can be updated as the facts change.
The local policy is to keep these pages outside the project repository by default, separate from branch handoff notes and records versioned with the code.
This is a storage policy, not a claim that in-repo documentation cannot last.
Honor an explicit destination; for an in-repo document, follow that project's documentation workflow rather than moving it elsewhere.

## Scope and authorization

Use the request, conversation, and project instructions to establish what saving is entrusted to you.
Finding useful knowledge alone does not authorize writing it somewhere.
Branch handoff notes belong with `conversation-context-export`; this project's agreed vocabulary and architectural decision records belong with `domain-modeling`.
Referring or splitting material between skills does not authorize additional files, commits, or publication.
Use those skills only for the recording already within scope.

A request to update a specified wiki includes the commit and push needed to publish that update unless the user limits it to a draft or local edit.
Reuse existing authorization; do not require the user to say "push without asking".
Saving to a local knowledge repository authorizes the file update; commit and push there follow the request and existing authorization.
A configured remote alone authorizes neither operation, and a general saving request alone does not authorize publication to a service selected by this skill.
Where publication or commit scope is missing, prepare the page and navigation changes for review before asking about that action.

## Choose the destination

Honor a specified wiki, repository, or established preference without selecting it again.
A wiki may hold cross-repo knowledge when that is the requested home; being attached to one repository is not a content restriction.

When no destination is specified:

- For knowledge about the current project, prefer its GitHub wiki if confirmed available.
  Use the configured knowledge repository when the project has no wiki, including a confirmed disabled or uninitialized wiki.
- For knowledge spanning projects, use the configured knowledge repository.
- `AGENT_KNOWLEDGE_REPO` names an existing local Git repository outside the projects it describes.
  Verify that a supplied path is that repository's root before writing.

If no destination can be established, present the draft to the user and ask for the missing destination.
Do not create a repository, enable a wiki, change authentication, or invent a `docs/knowledge/` fallback.

When GitHub discovery is needed, identify the intended repository from the request and Git remotes, resolving ambiguous forks or multiple remotes before choosing.
For example, `gh repo view "{host}/{owner}/{repo}" --json url,hasWikiEnabled` checks the repository's wiki setting; it does not establish that the wiki has pages or that Git access works.
Check access using the wiki's clone URL, for example with `git ls-remote "{wiki clone URL}"`.
Authentication, network, or retrieval failures leave availability unknown; empty output alone does not establish the cause either.
Retry through an allowed execution route when appropriate, then report unresolved access without silently switching destinations.
Here, "confirmed uninitialized" means the user has checked that no initial wiki page has been created.
If choosing a fallback depends on that status, ask the user to check it; do not infer it from `Repository not found`, even when the parent repository is accessible.
An explicitly selected wiki stays selected even when it is unavailable; ask about an alternative only if needed.
Do not probe GitHub when an explicitly selected local destination suffices.

## Destination conventions

For a **GitHub wiki**, use its provided clone URL and the user's existing Git access method, then edit the wiki checkout.
GitHub's [documented workflow](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages) starts with an initial page created on GitHub before cloning.
Follow that guidance when initialization is confirmed necessary; a clone failure does not by itself diagnose an uninitialized wiki.
Publish to the wiki's verified default branch, rather than hard-coding a branch name.
If a fresh checkout lacks a Git identity, reuse an established identity from the project with per-command `git -c user.name=… -c user.email=… commit`; do not invent one or change global configuration.

For a **knowledge repository**, first follow its existing page layout and navigation.
The default layout, where none is established, mirrors repository identity:

```text
{knowledge repo}/README.md
{knowledge repo}/{host}/{owner}/{repo}/README.md
{knowledge repo}/{host}/{owner}/{repo}/{Topic}.md
{knowledge repo}/_cross/README.md
{knowledge repo}/_cross/{Topic}.md
```

Derive the described repository's identity from the intended remote, not its checkout directory name.
For a project without a usable remote identity, resolve the scope with the user rather than inventing an owner or host.
Use `_cross/` for knowledge spanning projects.
In this default layout, link a new page from its scope's `README.md`, and add the scope to the top-level index only when new.
In an existing wiki or knowledge layout, update navigation when a new or renamed page needs a link; do not force a page list into `Home.md` or rewrite an index for a content-only update.

## Update and save

Read an existing topic page before editing; extend or correct it using verified evidence, preserving unrelated contributions.
Follow the destination's style instead of requiring a fixed template or classification.
Include enough context to stand alone; for measurements or evaluations, include the date, conditions, sources, and limits needed to judge staleness.
Do not copy secrets or conversation/local-history material that is not intended for the destination into pages or indexes.
Summarize the necessary evidence without exposing private identifiers.

Before editing, inspect the destination checkout's working tree and staged changes so existing work can be distinguished from this export.
Stage only the intended files or hunks and review the staged diff; a commit must exclude pre-existing unrelated work, including staged work.
If that cannot be done without disturbing it, leave the draft changes and resolve the conflict with the user.
Before an authorized push, verify the push URL, destination branch, and commits it would publish, excluding unrelated pending commits.
A remote's existence is not an upstream configuration; even an upstream can differ from Git's configured push destination (see [git-push](https://git-scm.com/docs/git-push)).
If the destination is ambiguous, ask rather than guessing a remote or configuring tracking.
Report the saved path or confirmed published URL, and distinguish local edits, commits, and successful publication from pending or failed actions.
