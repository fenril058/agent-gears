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

## Procedure

### 1. Get the branch name

Run with the Bash tool:

```
git branch --show-current
```

### Branch name sanitization

When using the branch name as a filename, replace these characters with `-`:

```
/ \ : * ? " < > |
```

Example: `dependabot/npm_and_yarn/feed-5.2.0` → `dependabot-npm_and_yarn-feed-5.2.0`

Below, the sanitized branch name is called the "sanitized branch name".

### 2. Check for files

Check the files in the `.dev/contexts/` directory.

Search `.dev/contexts/*.md` with the Glob tool (or `find .dev/contexts -name '*.md'` /
`ls .dev/contexts/` if Glob is unavailable) and determine:

- whether a file with the same name as the current branch
  (`.dev/contexts/{sanitized branch name}.md`) exists,
- whether any other files exist.

### 3. Decide what to load

Branch by the file situation:

#### Only the current branch's file exists

Load it without asking.

#### Only other files exist (no current-branch file)

Load all files without asking.

#### Both exist

Ask with the AskUserQuestion tool:

- **Load only the current branch's context**: only `.dev/contexts/{sanitized branch
  name}.md`.
- **Load all contexts**: all files in `.dev/contexts/` (list the filenames when
  presenting).

#### No files exist

Report that no context file was found in `.dev/contexts/` and stop.

### 4. Load and report

Read the target files with the Read tool.

After loading, report to the user which files you loaded:

```
Loaded the following conversation contexts:
- `.dev/contexts/feature-a.md`
- `.dev/contexts/feature-b.md`
```

## Related skills

- **conversation-context-export**: write the current conversation context to
  `.dev/contexts/`. Used to save context at a development milestone.
