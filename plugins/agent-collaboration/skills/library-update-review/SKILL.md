---
name: library-update-review
description: >-
  Review a library-update pull request. Review PRs created by dependabot/renovatebot, or
  manually created library-update PRs, doing release-note analysis, code updates,
  dependency investigation, and past-failure investigation.
argument-hint: "[PR-URL-or-number]"
---

# Library-update review procedure

Review a change that updates a library, and, when needed, handle migration between
versions and breaking changes.
The example commands and files use Node.js, but read them as appropriate for the library
and language actually changed.

## Scope

- Library-update pull requests created by dependabot or renovatebot.
- Library-update pull requests created by a human.

## Sections and work to do

Structure the report in the format below and write it.
When you reference external documentation, state its URL.

### 1. Library overview

Investigate the library overview.
Check the in-library README or the official docs, and report what the library is for and
how it is used.

### 2. Version info

Read package.json and report the before/after version info changed by this PR, and each
one's release date.

Investigate npmjs.com or GitHub and report whether a major version update exists.
This PR updates a patch or minor version, but it may not be the latest — a major version
update may exist.
In a major version update, the library may be renamed, or the repository moved to an
organization.

### 3. Confirm the change scope

Understand what changed in this PR and its extent.

From the lock-file diff, list the updated/added/removed packages.

- Even when there are many, list the main targets without omission.
- If a package change unrelated to the target library is included, note it.
- Don't conclude safety or impact here. Treat it as a point to check in later sections.

Example: for npm's `package-lock.json`, get the lock-file diff with `gh pr diff` or
`git diff`. Check a package's surrounding context with `grep -C15 '<package name>'
package-lock.json`.

### 4. Library dependencies

Check the library's dependencies.
Read package-lock.json to check dependencies. A command like `grep -C15 <library name>
package-lock.json` is effective.

- List other libraries that depend on this library.
- List other libraries this library depends on.

### 5. Usage sites and version info

Investigate where in the repository the library or runtime is referenced/specified.

Beyond import/require statements, include config files, Dockerfile, CI config, and dev
environment config — places where a version is specified.
In addition to `git grep <library name>`, search by version number and package name.

Compile the results into a per-file list of reference sites. This list is the input for
section 7-2 "version consistency check".
Files read in other sections (3, 4, etc.) may also contain version specs, so include them
in the list without omission.

### 6. Summary of changes

Summarize the changes.
Reference the library's official site or GitHub, and read the release notes, changelog,
and migration guide closely to understand the changes.
Extract the feature additions and API spec changes that likely relate to the features the
application uses, and report them.
You must check every version's changes between before and after, one by one.

Important: the explanation in the PR description may be wrong, so ignore it. Refer only
to the current code and the diff.

### 7. Update code/config

Check whether the library or runtime update requires changes to application code or
config files.
Propose a PR if needed.

Distinguish the following two angles:

#### 7-1. Code changes from API or spec changes

If the library's API changed, the application code needs to change.

If the release notes/changelog alone don't make the correct change clear, also check the
actual diff in GitHub commits and the official docs.
Report that change content too.

#### 7-2. Version consistency check

Check whether the version numbers changed in the PR are also referenced elsewhere in the
repository.

Investigate as follows:

1. Identify the changed version numbers from the PR diff.
   - Identify both before and after.
2. Judge the kind of update target.
   - npm package, runtime, Docker base image, etc.
3. Investigate the whole repository for other places that should be updated together to
   match the PR's updated version.
   - Also check the reference-site list made in "5. Usage sites".
   - For example, for a Node.js runtime update, the local dev and production
     environments must match. Beyond Dockerfile, check engines/packageManager in
     package.json and package-lock.json, .nvmrc, CI config, etc.
   - The above is just a representative example. Think carefully about omissions per the
     situation.
4. If an old version remains anywhere, report/fix it.

Notes:

- Don't conclude "no problem" from an exact version-string match alone. It may be managed
  by a range (`22.x` etc.) or an alias.
- Don't judge version correspondences by guessing; confirm from official docs or the
  actual distribution.
  - Example: the npm version corresponding to a Node.js version.
- If you can't confirm a related version due to external-access restrictions etc., report
  it as "unconfirmed" and prompt manual confirmation.

### 8. Interesting updates

Report interesting updates, if any. For example:

- A new feature or invented concept that could also apply to the application.
- An interesting feature using a new language/runtime capability.
- A change in the library's development structure.

### 9. Investigate past failures

Investigate whether this repository has had problems with the library being updated.
Search pull requests and issues by the library name, and report cases like:

- A pull request was closed without merging.
- It was merged, but a defect occurred and it was reverted.

If you find a problem, check whether it has been resolved.

## Final check

### Cross-section consistency check

Review the whole report cross-sectionally for contradictions or omissions between
sections.

- Is a file read/touched in some section included in section 5's reference-site list?
- Are all reference sites listed in section 5 verified in section 7-2's consistency check?
- Do the dependency info from section 4 and the change summary in section 6 not
  contradict?
- Among the changed packages listed in section 3, is any one whose grounds/intent is not
  explained in section 6's release-note summary? If a change is unexplained, check that
  it is included as a review note as an unexplained change.

If you find a discrepancy, fix the relevant section.

### Output format check

Review the report's format. If the output destination is a GitHub comment, output in a
format suited to it.

## Tips: format suited to a GitHub comment

### Write external-repo issue/PR numbers in full URL form

Write https://github.com/:owner/:repo/issues/12345 , not #12345.
Add half-width spaces so the URL doesn't stick to adjacent text. This renders as a
clickable link in the web browser.

### Label the pull request to explain its status

If the output destination is a GitHub pull request, add an appropriate label after
submitting the report.
For example, for an important security update PR with a CVE number issued, add a
"security" label.

## Report when you lack permissions

If you are Claude Code running on GitHub Actions, you may not have enough permission to
carry out the task.
Report the needed permissions so the repository admin can respond appropriately.

- The task you were trying to perform.
- The missing permission. For example:
  - Claude Code's allowedTools.
  - The GitHub Actions job's permissions.
