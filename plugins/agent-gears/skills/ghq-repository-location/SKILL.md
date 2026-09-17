---
name: ghq-repository-location
description: >-
  Local convention for where Git repositories live on this machine: clone through ghq,
  and resolve an already-cloned repository's path from ghq instead of guessing it from a
  remote URL. Use when cloning a repository, or when a task needs the local path of a
  repository that is not the current working directory.
---

# Repository location with ghq

This machine keeps every clone under the ghq root.
Two decisions follow from that, and nothing else in this skill.

## Cloning

Clone with `ghq get <repository URL>`.
Do not pick a destination directory yourself, and do not clone into the current working directory or a temporary path, unless the user asks for a throwaway clone outside the ghq root.

## Finding an existing clone

Ask ghq where the repository is:

```
ghq list --exact --full-path <repo>
```

If several owners have a repository with that name, narrow it with `<owner>/<repo>`.

Do not construct the path from a remote URL, from `origin`, or from the owner name in an issue or PR link.
The directory is named after the URL that was cloned, which is not always the current `origin`: a fork cloned from upstream and then re-pointed to the fork keeps the upstream owner in its path.
So a path derived from `origin` can be plausible, absent, and wrong at the same time.

If `ghq` is unavailable, or the listing is empty, report that the local path is unknown and ask.
Do not fall back to guessing a path, and do not treat a directory that happens to exist at a guessed path as the repository in question.

## Anything else about ghq

Read `ghq --help`.
This skill does not restate ghq's subcommands or options.
