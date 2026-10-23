---
name: conversation-context-import
description: >-
  Import the conversation context. Load past conversation contexts saved in the
  `.dev/contexts/` directory and use them to continue development or review. Use when the
  user says "load the context", "import the conversation context", or "read the context
  from .dev".
---

# Conversation context import procedure

Load past conversation contexts saved in `.dev/contexts/`.

## Naming convention

The current branch's context lives at `.dev/contexts/{sanitized branch name}.md`.
Take the branch name from `git branch --show-current`; the sanitized form replaces each of these characters with `-`:

```
/ \ : * ? " < > |
```

Example: `dependabot/npm_and_yarn/feed-5.2.0` → `dependabot-npm_and_yarn-feed-5.2.0`

## What to load

Honor the user's requested files, branches, or scope before applying defaults, including requests to load all contexts or use a past branch.
Do not ask again for permission already given.
If a specified file or branch's context is missing, report that rather than silently substituting another context.

For a general request to load context, list `.dev/contexts/*.md` and select as follows:

- If the current branch's file exists, load only that file without asking, even if other branches' files exist.
- Otherwise, use the request and available filenames to identify relevant context.
  If the target is unclear, present the candidate filenames and ask only what is needed to identify it before reading their contents.
  Do not load all other branches' files by default.
- If no context files exist, report that none were found and stop; do not invent context.

Report which files you loaded.

## Related skills

- **conversation-context-export**: write the current conversation context to
  `.dev/contexts/`. Used to save context at a development milestone.
