---
name: conversation-context-export
description: >-
  Export the conversation context. Write the goal, intent, design decisions, and
  constraints shared in the conversation to the `.dev/contexts/` directory, and post to
  a PR comment if a PR exists. Hand off to the next worker (a reviewer, an AI in another
  session, a bug-hunting AI, etc.). Use when the user says "export the context", "write
  out the conversation context", or "save what we discussed to .dev".
compatibility: Requires git and the gh CLI (GitHub CLI, authenticated) on PATH; gh is used to detect a PR and post/update the context comment. Install gh from https://cli.github.com.
---

# Conversation context export procedure

Write the development context shared through the conversation (goal, intent, design
decisions, constraints, etc.) to `.dev/contexts/{sanitized branch name}.md`. If a PR
exists, also post it to a PR comment.

## Uses

This file is used in these situations:

- **Reviewing the PR description**: an AI cross-checks the human-written PR description
  against the implementation context to point out errors or missing explanations.
- **AI-vs-AI bug hunting on a feature PR**: a briefing for the defense-side AI to
  understand the design intent.
- **Continuing development in a new session**: carry over the previous session's
  context.
- **Sharing via a PR comment**: when a PR exists, also post it as a comment so other
  workers or sanity-review can reference it directly.

## Worktree note

The write in step 3 targets `.dev/contexts/`, not implementation files, but it is still
subject to the worktree rule in your always-on instructions (`CLAUDE.md` / `AGENTS.md` /
`copilot-instructions.md`).

If your session's workspace root **is** the target worktree, write normally — no extra
check needed.

If you are running from a session whose workspace root is a **different** (sibling)
worktree, the write is allowed only if all of these hold:

- The target worktree is explicitly included in this session's filesystem sandbox
  writable range.
- The write target is exactly `.dev/contexts/{sanitized branch name}.md`.
- The user has explicitly authorized this one-time cross-worktree write.

This skill never builds, tests, runs `direnv exec`, or performs Git operations, so those
restrictions in the worktree rule never apply here.

If any condition doesn't hold, tell the user and ask them to switch to a session whose
workspace root is the target worktree instead.

## Procedure

### 1. Fetch metadata

Run with the Bash tool:

```
git branch --show-current && git rev-parse --short HEAD && gh pr view --json number -q .number
```

Get the branch name, source commit, and PR number. For "Updated at" use the current
datetime (YYYY-MM-DD HH:mm:ss).

- If a PR exists, get its number and fill the PR field of the metadata.
- If the command errors (PR not created), write "PR not created at export time".

### Branch name sanitization

When using the branch name as a filename, replace these characters with `-`:

```
/ \ : * ? " < > |
```

Example: `dependabot/npm_and_yarn/feed-5.2.0` → `dependabot-npm_and_yarn-feed-5.2.0`

Below, the sanitized branch name is called the "sanitized branch name".

### 2. Check for an existing file

Check whether `.dev/contexts/{sanitized branch name}.md` already exists.

If it exists, read it with the Read tool. Then judge whether **you exported it in this
conversation (same session) or another session wrote it (different session)**:

- **Same session**: you wrote it with the Write tool in this conversation.
- **Different session**: anything else (a previous-session AI, another AI).

Based on this, apply the "rules for updating an existing file" in step 3.

### 3. Write out the context

Read [TEMPLATE.md](TEMPLATE.md) in the same directory as this SKILL.md and create the
file in its structure.

If the `.dev/contexts/` directory does not exist, create it.

Include the "suggested skills" section of the template when there are skills the next
worker should invoke to continue (e.g. conversation-context-import, sanity-review, a
domain skill used in this work); add a one-line reason each. Omit the section if there
are none.

**Redact sensitive information** — API keys, tokens, passwords, and personally
identifiable information must not appear in the file. This matters doubly because step
4 posts the same content to a PR comment, which publishes it.

Write to `.dev/contexts/{sanitized branch name}.md` with the Write tool.

### 4. Post to a PR comment

If no PR number was obtained in step 1 (PR not created), skip this step.

Posting publishes the content. Before posting, re-confirm the file contains no
unredacted secrets or personal information (step 3's redaction rule).

#### 4-1. Get repo info and the current GitHub user

Run with the Bash tool:

```
gh repo view --json owner,name -q '.owner.login + "/" + .name' && gh api user -q .login
```

Line 1 is the repo's `{owner}/{repo}`, line 2 is the current GitHub username.

#### 4-2. Search for an existing conversation-context comment

Run the following to search the PR comments for the conversation-context comment. Target
only comments whose body starts with the TEMPLATE.md heading `# {branch name} 対話コンテキスト`:

```
gh api repos/{owner}/{repo}/issues/{PR number}/comments --paginate -q '.[] | select(.body | startswith("# {branch name} 対話コンテキスト")) | {id: .id, login: .user.login}'
```

Embed the current branch name (before sanitization) in `{branch name}`. Confirming the
exact heading line with `startswith` excludes unrelated comments that merely contain the
string "対話コンテキスト".

If several are found, prefer your own comment. If you have several, use the latest. If
you have none and only another user's comments exist, target the latest.

#### 4-3. Decide and execute the post

Branch by the search result. Read the comment body from a file to avoid shell escaping
issues.

##### If no existing comment is found

Post a new comment:

```
gh pr comment {PR number} --body-file .dev/contexts/{sanitized branch name}.md
```

##### If an existing comment is found and you are the author

Update the existing comment:

```
gh api repos/{owner}/{repo}/issues/comments/{comment ID} --method PATCH -F body=@.dev/contexts/{sanitized branch name}.md
```

##### If an existing comment is found and another user is the author

You cannot edit another user's comment, so ask with the AskUserQuestion tool:

- **Post as a separate comment**: post a new comment with `gh pr comment`.
- **Skip the GitHub post**: finish with only the local file write.

#### 4-4. Report the result

If the post/update completed, report the PR comment URL to the user. If skipped, report
that.

## Guidelines for what to write

### Emphasize

- **Accurate description of the implementation's behavior**: not "it works like this"
  but "given this input, it behaves like this".
- **Rejected alternatives and their reasons**: the judgment a human later wonders "why
  didn't we do it this way".
- **Discovered constraints and pitfalls**: information so the next worker doesn't step
  in the same trap.

### Keep thin

- Things obvious from reading the code (function names used, list of changed files,
  etc.).

### "What not to write" rules per section

- **Design approach**: don't write the reason for a config value that is clear from
  reading the code/config (e.g. filename naming, env version choice).
- **Newly confirmed facts**: don't write impressions, reflections on the process, or war
  stories. Only facts that affect future decisions.
- **Pitfalls to watch**: a constraint (an unchangeable fact) goes in "discovered
  constraints". A positive discovery goes in "newly confirmed facts".

### Section boundary guide

**"Design approach" vs "rejected alternatives":**

- Design approach = the adopted approach and its grounds.
- Rejected alternatives = approaches considered but not adopted, and why.

**"Discovered constraints" vs "pitfalls to watch":**

- Constraint = a fact that binds the judgment and won't disappear no matter how careful
  the worker is.
- Pitfall = an accident avoidable by changing the steps or approach if you know about it.

### Rules for updating an existing file

#### Re-export within the same session

- Fully regenerate based on the whole conversation context.
- Not bound by the existing file's content. The current understanding is authoritative.

#### Updating another session's record

Respect the prior session's record as "a predecessor's findings":

- Keep existing items as a rule.
- Append newly discovered information.
- **Correct or delete only when you actually re-tested/verified and disproved it in your
  own work.** Don't delete on inference alone.
- If an item is clearly misclassified, you may move it between sections (the content is
  preserved).
- If you infer a change of intent / approach / scope judgment, confirm with the user.

#### Common rules

- The file always represents "the currently correct state". Don't leave strikethroughs
  or change history (leave history to git).

## Related skills

- **conversation-context-import**: load a saved conversation context. Used when
  continuing development in a new session or reviewing a feature PR.
- **sanity-review**: write a PR review report. Loads the conversation context posted to
  the PR comment and uses it in the review.
- **durable-knowledge-export**: the durable tier. This skill is the ephemeral tier
  (per-branch context that dies with the PR). A finding that should outlive the branch —
  a measurement, convention, or system-wide gotcha — goes to its persistent home (the
  GitHub wiki, or an in-repo docs dir if there is no wiki) via that skill instead.
