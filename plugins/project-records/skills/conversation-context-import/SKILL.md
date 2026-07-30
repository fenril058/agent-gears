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

The current branch's context lives at `.dev/contexts/{sanitized branch name}.md`. Take the
branch name from `git branch --show-current`; the sanitized form replaces each of these
characters with `-`:

```
/ \ : * ? " < > |
```

Example: `dependabot/npm_and_yarn/feed-5.2.0` → `dependabot-npm_and_yarn-feed-5.2.0`

## What to load

List `.dev/contexts/*.md`, then branch on what's there:

- **Only the current branch's file** → load it without asking.
- **Only other branches' files** → load them all without asking.
- **Both** → ask with AskUserQuestion which to take: the current branch's file only, or
  every file in `.dev/contexts/` (list the filenames in the options).
- **Nothing** → report that no context file was found, and stop.

Report which files you loaded.

## Related skills

- **conversation-context-export**: write the current conversation context to
  `.dev/contexts/`. Used to save context at a development milestone.
