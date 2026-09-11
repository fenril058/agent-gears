---
name: codepatrol
description: >-
  Run a security investigation of a repository, area by area. Based on a target list
  and a checklist of security perspectives, pick an uninvestigated area, investigate
  it, and write a report to `.dev/codepatrol/`. Designed for long-running work across
  multiple sessions: it checks the current state and continues where the last session
  left off. Use when the user says "run codepatrol", "continue the security
  investigation", or "security-audit this area".
argument-hint: "[update the target list]"
---

# Security investigation procedure

Investigate the repository's source code area by area from a security perspective and
write a report per area. The work is expected to span multiple sessions: on every run,
check the current state and continue from there.

## File layout

```
{directory containing this SKILL.md}/
  SKILL.md               ← this procedure
  CHECKLIST.md           ← generic checklist of perspectives (master copy)
  REPORT-TEMPLATE.md     ← report template
  checklist-vs-report.md ← responsibility boundary between checklist and report
                           (what to write where; referenced by steps 2/4/5)

.dev/codepatrol/
  checklist.md         ← working copy of the checklist (generated from CHECKLIST.md,
                         customized to the repository)
  targets.md           ← investigation target list (auto-generated, hand-editable)
  {area}.md            ← per-area investigation report
```

## Steps

### Step 1: Check the state

Check the existence of:

1. the `.dev/codepatrol/` directory
2. `.dev/codepatrol/targets.md` (investigation target list)
3. `.dev/codepatrol/checklist.md` (working copy of the checklist)

### Step 2: Initial setup

#### If targets.md is missing, or the user said "update the target list"

Scan the server-side entry points and auto-generate the target list. Auto-detection is
limited to the server side; if client/config/infra areas are needed, the user adds them
to targets.md by hand.

Run with the Bash tool to get metadata:

```
git rev-parse --short HEAD
```

Then survey the repository layout to detect investigation areas:

1. Grasp the framework and the location of server-side code from package.json,
   Gemfile, go.mod, etc.
2. Enumerate the server-side entry points, i.e. the places that accept external input.
   Only what actually exists in the repository:
   - HTTP routing and the controllers/handlers it references
   - handlers for realtime communication such as WebSocket
   - cross-cutting middleware/filters: authentication, authorization, CSRF, rate
     limiting, etc.
   - other external-input entrances not covered above: webhook receivers, batch/jobs,
     etc.

Write the detected areas to `.dev/codepatrol/targets.md`. Format:

```markdown
# Codepatrol Investigation Targets

Generated at: {YYYY-MM-DD HH:mm:ss}
Source commit: {short hash}

Each H2 heading is an investigation area name. The name becomes the report name as-is.
To add/split/merge areas, edit this file by hand.

## {area}

{path of the target directory/files}
{list of the main files}
```

**Area grouping guidelines:**

- A directory holding controllers/handlers is in principle 1 directory = 1 area.
- Single-file controllers may be grouped with related ones.
- Cross-cutting middleware/filters (auth etc.) form 1 area.
- Realtime communication such as WebSocket forms 1 area.
- Area names become part of file names, so keep them to alphanumerics, hyphens, and
  underscores — no path separators or spaces.

**When updating targets.md:**
If targets.md already exists, read it with the Read tool and compare with the new scan.

- Keep existing H2 headings (area names). Do not destroy the user's manual
  splits/merges.
- The prose under an existing H2 heading may be refreshed from the scan.
- Append newly detected areas as H2 headings at the end.
- Do not delete areas that no longer match the scan (deleted directories etc.); leave
  them for the user to remove.

#### If checklist.md is missing

[CHECKLIST.md](CHECKLIST.md) in the same directory as this SKILL.md is a generic,
repository-independent checklist. Do not copy it as-is; generate a working copy
customized to the repository:

1. Read [CHECKLIST.md](CHECKLIST.md) with the Read tool.
2. Survey the repository's security mechanisms: the concrete names of authorization
   middleware and the role hierarchy, the tenant boundary unit (project/team/org
   etc.), the authentication/session scheme, the template engine and client-side
   rendering scheme, the DB access layer, file storage, places that send outbound
   requests, the rate-limit implementation, and business logic such as billing.
   - The purpose of this survey is to fill concrete names into the perspectives, not
     to find vulnerabilities (that is step 4). Do not dig deep into individual
     implementations.
   - Use existing area reports (`.dev/codepatrol/{area}.md`) as a source if present.
3. Customize each perspective from the survey and write
   `.dev/codepatrol/checklist.md` with the Write tool:
   - Record `Source commit: {output of git rev-parse --short HEAD}` at the top, so it
     is diagnosable which point in time the survey reflects.
   - Summarize the surveyed mechanisms at the top as a "security mechanisms of this
     repository" section. Write library names without version numbers.
   - Add this repository's concrete names (middleware, functions, directories) to
     each perspective's description.
   - Delete perspectives about mechanisms the repository does not have (e.g. delete
     A5/E2 if WebSocket is unused).
   - Append repository-specific perspectives at the end of the relevant category,
     continuing the numbering.
   - Keep the category structure (symbol + number). Report headings and the grouping
     in step 5 refer to it.

**The checklist's scope**: what to write and not write in the checklist follows
[checklist-vs-report.md](checklist-vs-report.md) (gist: only spec/mechanism facts and
neutral perspectives; no bug assertions, severities, exploit hypotheses, or references
to report findings — those go to the report). Respect this boundary at generation time.

#### If checklist.md already exists (update)

When the user says "update the checklist", or before using an existing
`.dev/codepatrol/checklist.md` in an investigation:

1. Read the existing `.dev/codepatrol/checklist.md` with the Read tool.
2. Re-scan the repository's mechanisms and add/update perspectives (following "If
   checklist.md is missing" above).
3. Against the boundary in [checklist-vs-report.md](checklist-vs-report.md), rewrite
   any nonconforming text (bug assertions, severities, exploit hypotheses, references
   to report findings that crept in) into spec facts or neutral perspectives, or
   delete it. Do this together with the perspective updates.

### Step 3: Check progress and pick a target

1. Read `.dev/codepatrol/targets.md` with the Read tool.
2. Parse the H2 headings to get the list of all area names.
3. Search `.dev/codepatrol/*.md` with the Glob tool; areas with an `.md` file other
   than `targets.md` and `checklist.md` are "investigated". Report timestamps are not
   tracked, so only report the investigated/uninvestigated split to the user.

**Judge progress only by report existence. Do not infer the need for re-investigation
from code changes.**

**If the user explicitly named a target area:**
Investigate that area whether or not it is already investigated. Skip the selection
flow below.

**If every area has a report:**
Ask the user which area to re-investigate.

**If there are uninvestigated areas:**
Let the user choose with the AskUserQuestion tool. Prioritize areas involving
authorization, authentication, and outbound communication. If there are too many
uninvestigated areas for the 2–4 options, first ask how to narrow down (propose the
next one / name an area directly / revisit targets.md).

### Step 4: Run the investigation

1. Read `.dev/codepatrol/checklist.md` with the Read tool.
2. Read the code of the selected area:
   - start from the file paths recorded in targets.md
   - explore related files with Glob/Grep as needed
   - follow the data flow: entry point → internal logic → data layer
3. Apply each checklist perspective:
   - investigate only the applicable perspectives (not every perspective applies to
     every area)
   - record presence/absence of problems with evidence per perspective
   - when a problem is found, pin the concrete code location (file path:line)
   - if you find a discrepancy between the working checklist (mechanism summary,
     concrete names) and the implementation, fix checklist.md on the spot — but keep
     the fix at the level of mechanism/spec facts; write the discovered bug itself to
     the report, not the checklist (see
     [checklist-vs-report.md](checklist-vs-report.md))

**Depth of investigation:**

- Actually read the code for each perspective. Do not mark "no problem" on guesswork.
- Balance coverage and depth: do not over-invest in one perspective; prefer passing
  over all perspectives once.
- For easy bugs (add escaping, add middleware — fix is obvious), write the concrete
  fix in the report.
- For problems needing a design change, say so in the report and recommend a separate
  discussion.

### Step 5: Critical review by an external agent

Have an external agent criticize the step-4 findings to detect omissions. A chain of
critical thinking finds vulnerabilities a solo investigation misses.

Split the working checklist's categories into 2–4 groups and run
`subagent-consultation` per group. For a small area with few applicable perspectives,
one combined consultation is fine. Grouping guide:

- **authorization group**: authorization, tokens/shared URLs, authentication/session
- **input/output validation group**: SSRF, XSS, injection
- **others**: files, DoS, information leaks, business logic, configuration

For each group, invoke `subagent-consultation` with the Skill tool. Include in the
args:

```
In the security investigation of {area}, I obtained the findings below for
{the group's perspective categories}. Review them critically: are there omissions, are
there attack vectors I missed? Actively point out perspectives that are not on the
checklist.

{summary of the group's findings}
```

If `subagent-consultation` is unavailable, skip this step and note that in the
report's overall assessment.

When you receive the external agent's points:

- verify each point yourself by reading the code
- reflect valid points into the step-4 findings (= what goes in the report). External
  agents' points lean toward bugs, so do not fold them into the checklist (that would
  turn the checklist into a findings list and steer future investigations toward
  specific spots; see [checklist-vs-report.md](checklist-vs-report.md))
- if views differ, record both sides' reasons in the report

### Step 6: Write the report

Run with the Bash tool to get metadata:

```
git rev-parse --short HEAD
```

Read [REPORT-TEMPLATE.md](REPORT-TEMPLATE.md) in the same directory as this SKILL.md
and write the report in its structure to `.dev/codepatrol/{area}.md` with the Write
tool.

After writing, report a summary of the findings to the user.

## Related skills

- **subagent-consultation**: the consultation mechanism for the critical review in
  step 5.
- **sanity-review**: writes a PR review report. Useful when reviewing the fix PR for a
  problem found by this investigation.
- **conversation-context-export**: exports the conversation context. The report header
  format is modeled on it.
