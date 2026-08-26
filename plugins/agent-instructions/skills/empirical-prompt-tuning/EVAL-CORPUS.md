# Persistent eval corpus

`empirical-prompt-tuning` measures an instruction by running it, but a measurement that lives only in the conversation cannot be repeated.
This file defines the on-disk form of that measurement, so the same scenarios and the same fixed checklist can be re-run later, against a different host, a different model, or a different revision of the skill.

The evaluation semantics are unchanged.
The checklist, the `[critical]` rule, and the accuracy formula are the ones defined in `SKILL.md`; this is only their persistent encoding.
`SKILL.md` writes verdicts as `○ / × / partial`; the JSON writes the same three as `pass` / `fail` / `partial`.

The one addition is not a fourth verdict.
`unevaluated` records that the item could not be measured at all — an out-of-band state saying *no measurement exists*, not a judgement about the work.
An in-session run never needs it, because the operator sees whether the evidence was there.
A stored run does: the file outlives the session that produced it, and "we could not tell" has to survive as itself rather than collapsing into a `fail`.
Everywhere a measurement does exist, the three values and the formula are exactly `SKILL.md`'s.

## Layering

```text
eval corpus            evals/cases.json — scenarios and the fixed checklist. No host in it.
      |
runner interface       scripts/eval-render.sh — corpus -> execution prompt, judgment prompt, result skeleton.
      |                scripts/eval-compare.sh — run files -> requirement-level delta matrix.
      |
host execution         Claude Code Task tool / Codex / Copilot. Lives outside this repo's data.
```

The corpus is the shared part.
Everything that differs between hosts — how an executor is dispatched, how `tool_uses` is read, whether token counts exist at all — belongs to the runner, and lands in the result file as metadata rather than in the corpus.

A case has no field in which to name a tool, an agent type, or a model.
That is a schema guarantee only for structured fields: `scenario`, `prompt`, `tags`, and `notes` are free text, and nothing stops a careless author from writing "use the Task tool" inside one.
Keeping host-specific wording out of those strings is a convention the validator cannot enforce for you.

## The executor never sees the checklist

The execution prompt carries the scenario, the user message, and the candidate instruction — and no requirements.
Grading happens afterwards, from a separate prompt, against the deliverable.

This matters most for the baseline arm — the `without-skill` side of the comparison.
If the checklist reaches the executor, a `without-skill` run is handed the skill's core expectations ("ask exactly one question", "attach a recommended answer", "do not start implementing") and can simply implement them.
The baseline then scores like the skill, measured uplift collapses toward zero, and the comparison says nothing about whether the skill is worth having.

The baseline prompt also withholds the skill's **name**.
Naming it tells the executor what the candidate is, and on a host that can load skills on its own it may cue exactly the discovery the baseline is supposed to exclude.
Withholding the skill at the host boundary — not loading it into the executor's session in the first place — is the runner's job; the prompt can only avoid pointing at it.

So `eval-render.sh` splits the two:

| `--part` | Contains | Given to |
|---|---|---|
| `execution` (default) | target prompt, scenario, user message, self-report structure | a fresh executor |
| `judgment` | scenario, user message, the deliverable, **the observed tool calls and file changes**, the checklist, the judgment rules | a separate evaluator that did not produce the deliverable |

### The judge needs evidence, not claims

Some requirements cannot be settled from the deliverable at all.
"Looked the fact up instead of asking" and "wrote the glossary entry now" are statements about what the executor *did*, and an executor that writes "I recorded this as an ADR" without creating a file is indistinguishable, on output alone, from one that did.

So the judgment prompt carries two evidence slots the caller fills in — the tool-call transcript and the observed file changes — and instructs the judge that a claim is not evidence.
Capturing them is host-specific, which is why the corpus does not describe how; it only declares, per requirement, what kind of observation the item needs:

```json
{"id": "facts-self-served", "critical": true, "text": "...", "evidence": "tool-calls"}
```

`evidence` is `deliverable` (the default, omit it), `tool-calls`, or `file-state`.
When the evidence an item needs was not captured, the judge reports it as unjudgeable and the caller records that requirement with `"verdict": "unevaluated"` and a `note` saying what was missing.
It never becomes a `pass` by default.

Evidence has to be specific enough to settle the item.
A list of tool *names* does not show which file was read; a list of changed *paths* shows that something was written but not what, so an item like "the settled term is in the glossary" needs the content, not just the path.
The prompt asks for the target path or command and the result for each tool call, and the path plus the relevant content or diff for each change.

### Scenarios describe the world, not the expected behaviour

A scenario states where the executor is and what has already happened.
It must not state what a good answer looks like, because the baseline arm reads the same scenario: describing "the interview needs facts from the repo, and decisions from the user" hands the baseline the very distinction `facts-self-served` is testing.
Expected behaviour belongs in requirements, which the executor never sees.
The target skill's name is withheld for the same reason.

This differs from the inline subagent invocation contract in `SKILL.md`, where the executor receives the checklist and self-reports achievement against it.
That contract is for measuring one instruction's clarity, where the executor's own reading of the requirements is part of the signal.
Corpus-driven runs — and every baseline comparison — need the executor blind instead.

## Where it lives

```text
plugins/<plugin>/skills/<skill>/evals/cases.json   the corpus, committed
.dev/evals/<skill>/<host>/<model>/<run-id>.json    results, not committed (.dev/ is gitignored)
```

`evals/` holds exactly one file, `cases.json`, as a regular file.
The validator rejects anything else under it — a misspelled `case.json`, a leftover `cases.json.bak`, a symlink, or an `evals/` directory nested at the wrong depth — so none of them can sit there unvalidated.
Discovery is NUL-delimited and checks path components by count, because a shell glob's `*` crosses `/` and a newline in a directory name splits a newline-delimited list.

The corpus travels with the skill, so it is symlinked to `~/.claude/skills/<skill>/evals/` along with everything else in the directory.
Whether any host loads or is influenced by files a skill directory happens to contain is **unverified** — it has not been tested on Claude Code, Codex, or Copilot.
No problem has been observed, but do not treat that as a guarantee.

## `agent-gears/eval-cases@1`

```json
{
  "schema": "agent-gears/eval-cases@1",
  "skill": "grilling",
  "notes": "optional, why this corpus exists",
  "cases": [
    {
      "id": "storage-choice-median",
      "tags": ["median"],
      "scenario": "one paragraph of context the executor is placed in",
      "prompt": "the message the simulated user sends",
      "notes": "optional",
      "requirements": [
        {"id": "one-question", "critical": true, "text": "...", "surface": "推奨|recommend"}
      ]
    }
  ]
}
```

Abridged for readability: a real corpus needs at least 2 cases and 3 to 7 requirements each, per the rules below.

| Field | Rule |
|---|---|
| `skill` | must equal the skill directory name |
| `cases` | **at least 2**. `SKILL.md`'s red-flag table: "One scenario overfits. Minimum 2, ideally 3." A hold-out scenario added at convergence makes more, so there is no upper bound |
| `cases[].id` | kebab-case, unique, and stable — results reference it, so renaming an id orphans every result already recorded |
| `cases[].scenario` | the situation; `cases[].prompt` is what the user actually types |
| `cases[].tags` | free-form. Conventions in use: `median`, `edge`, `hold-out` (the overfitting check in `SKILL.md`) |
| `requirements` | **3 to 7 items**, per `SKILL.md`'s Baseline preparation |
| `requirements[].id` | unique within the case; results report verdicts by this id |
| `requirements[].critical` | required boolean. At least one `true` per case, or the success judgment is vacuous |
| `requirements[].evidence` | optional. `deliverable` (default) / `tool-calls` / `file-state` — what the runner must capture for the judge to settle this item |
| `requirements[].surface` | optional **ERE** (not PCRE — `\d` and `\w` do not mean what you expect) for the surface half of the surface/semantic pair. Include both the Japanese and English spellings in one alternation |

Requirement text is written in English, matching the English-canonical rule for instructions.
`prompt` is written in whatever language the user would really use.

Unknown fields are rejected.
That is not pedantry: it is what stops a cross-host aggregate score from being quietly added to the format later (see "Do not fold hosts together").

## `agent-gears/eval-run@1`

One file is one `(corpus, host, model, candidate)` combination, holding one row per case per trial.
That is deliberate — giving the combination its own file means there is nowhere to write a number that spans two of them.

```json
{
  "schema": "agent-gears/eval-run@1",
  "run_id": "2026-08-25T00-00-00Z-grilling-claude-code-with-skill",
  "started_at": "2026-08-25T00:00:00Z",
  "corpus": {"skill": "grilling", "path": "plugins/critique/skills/grilling/evals/cases.json", "digest": "sha256:..."},
  "host": {"id": "claude-code", "model": "claude-opus-5", "version": "2.0.0"},
  "candidate": {"kind": "with-skill", "label": "grilling @ 2355dff", "revision": "git:2355dff"},
  "results": [
    {
      "case_id": "storage-choice-median",
      "trial": 1,
      "success": true,
      "accuracy": 0.9,
      "requirements": [{"id": "one-question", "verdict": "pass", "surface": "hit", "note": "..."}],
      "tool_uses": 3,
      "duration_ms": 21000,
      "retries": 0,
      "token_usage": {"input": 12000, "output": 900},
      "issues": [{"phase": "planning", "issue": "...", "cause": "...", "general_fix_rule": "..."}],
      "discretionary": ["..."],
      "unevaluated": ["execution: fastcontext not configured"]
    }
  ]
}
```

- `corpus.path` is resolved from the repository root, so record it repo-relative. `--result-stub` does that for you, using `git` — without `git` on PATH it records the path as given, which then has to be resolvable from the repository root by hand.
- `corpus.digest` is `sha256:` over the corpus file. Two runs are comparable only if the digest matches; editing a case invalidates every earlier result against it, and the digest is what makes that visible.
- The referenced corpus is validated too. Without that, a run pointing at a corpus with no `[critical]` requirement would make `success` vacuously true and a fully-failed run would validate as a success.
- **`host.model` is required.** If the host does not report one, write an explicit marker such as `"unknown"` — but a run whose model is unknown cannot be used for candidate comparison, because two runs from different models would both read as "unknown" and their difference would be invisible. That is precisely the confusion this format exists to prevent.
- `host.version` is optional. So are `tool_uses`, `duration_ms`, `retries`, and `token_usage` — not every host reports them. `token_usage` is recorded only where the host provides it; its absence is not a failure.
- A requirement whose corpus entry declares a `surface` pattern must report `surface: hit|miss` in the result. Otherwise the surface half of the surface/semantic pair could be dropped wholesale while the run still validated.
- `issues[].phase` is one of `understanding` / `planning` / `execution` / `formatting`, the trace phases from `SKILL.md`.
- `unevaluated` carries the honest-reporting escape hatch from `SKILL.md`: an axis that could not be measured is named here rather than narrated into a fake pass.
- `verdict` is `pass` / `fail` / `partial` / `unevaluated`. `success` and `accuracy` are derived from the verdicts, not asserted independently:

```text
success  = false, as soon as any [critical] requirement is fail or partial
         = null,  when no [critical] has failed but at least one is unevaluated
         = true,  when every [critical] requirement is pass
accuracy = (pass + 0.5 * partial) / (requirements that are not unevaluated)
         = null, when every requirement is unevaluated
```

The order matters. A failure that was actually observed is not undone by some *other* item going unmeasured: once one `[critical]` is `fail`, "every critical is pass" is already impossible, so `success` is settled at `false`. `null` is reserved for the case where the unmeasured item is the only thing standing between the run and a `true`.

`unevaluated` is the requirement-level counterpart of the run-level `unevaluated` list: the item was not measured, so it is neither a success nor a failure.
It requires a `note` naming the missing evidence, and it is excluded from the accuracy denominator rather than scored as zero.
A `[critical]` item left unevaluated makes `success` unknowable — `null`, not `false` — but only while no other `[critical]` has already failed.
A run carrying any `unevaluated` verdict is not comparable to one that measured that item.

`scripts/check-evals.sh` recomputes both and rejects the file if the stored values disagree.
It also rejects the `REPLACE-ME` placeholders that `--result-stub` emits, so a skeleton cannot pass validation as though it were a completed run.

## Baseline and candidate

The two arms of a comparison. Which arm is "the candidate" is a property of the comparison, not of the file — today's `with-skill` run is the baseline for tomorrow's revision.
`candidate.kind` records only what the executor was given:

| `kind` | Meaning | `revision` |
|---|---|---|
| `with-skill` | the skill was given to the executor | required — which revision (`git:<sha>`, or a working-tree marker) |
| `without-skill` | the skill was withheld; the model's default behaviour | not allowed |

The baseline prompt withholds the skill and its name, and stops there.
It must not forbid anything the model would ordinarily do — telling it not to read instruction files or reference documents would suppress exactly the repository exploration that `facts-self-served`-style requirements measure, turning the comparison into *with skill* against *default minus repo exploration* and inflating the uplift.
Withholding the skill itself is the runner's job at the host boundary.

Both baselines fall out of this without more machinery:

- *Is the skill worth having?* — a `without-skill` run against the same corpus digest.
- *Did this revision improve things?* — a `with-skill` run whose `revision` is the older sha.

Checking out an old revision to produce that run is a manual step today.
The data model does not care how the revision got onto disk, only that the run says which one it was.

`SKILL.md`'s "Variant exploration" compares two uncommitted drafts (conservative vs exploratory).
Both are `with-skill`; distinguish them by putting the draft's identity in `revision` (e.g. `worktree:conservative`) rather than only in `label`, which nothing validates.

## Runner isolation contract

The corpus names no host, and `eval-render.sh` only avoids naming the skill.
Everything else that keeps the arms comparable belongs to the runner, and "the runner withholds the skill" turned out not to be one action but five invariants.
Each of the following was violated by an ad-hoc runner during the first real measurement of this corpus, and each violation was visible only because the tool-call transcript had been captured.

### Unloading a skill is not withholding it

A host switch that disables skills — Claude Code's `--safe-mode` or `--disable-slash-commands` — stops the skill from being *loaded*.
It does not remove the file.
`~/.claude/skills/<skill>/SKILL.md` stays readable, and an executor told to record "via `domain-modeling`" goes looking for it: one did, and read three files out of the installed skill directory.
The same path was open to the baseline arm for the skill actually under test.
Nothing but luck kept it shut.

Withholding means **unreachable through the filesystem**, not merely unloaded.
Point the host at an empty configuration directory, or run it in a filesystem sandbox.
Where neither is possible, say so in the run's `notes` and treat the baseline as provisional rather than pretending the boundary held.

### Only one candidate exists on disk at a time

Two arms' candidate files must never co-exist during a run, and a permission flag is not a substitute.
Claude Code's `--add-dir` grants *additional* access; under `--permission-mode bypassPermissions` it does not restrict reads at all.
Two executors reached the sibling arm's `SKILL.md` with `find` and read it — one of them the arm whose entire purpose was not to see it.

Materialise the candidate at a single neutral path for the duration of its own arm and delete it afterwards.
A directory holding only the arm being run cannot leak the arm that is not.

### Arm identity must not appear in anything the executor can observe

The executor sees its working directory, its git history and its branch.
Any of them can name the arm:

- a working tree at `.../work/<case>/tampered/` announces the arm to `pwd`
- a candidate at `skills/A/` beside `skills/B/` announces that there are two
- `git commit -m "tampered candidate"` announces the edit itself — an executor ran `git show HEAD`, found the commit, and reported the tampering back in its deliverable

Name the paths so they carry no arm information, and build a modified checkout so its history is indistinguishable from the intact one (amend onto the upstream commit rather than adding one on top).

### Dependencies are equalised across arms, not withheld

A requirement can only be about the candidate.
When the candidate delegates — `grilling` records "via `domain-modeling`" — whether that delegate is reachable changes what the executor is able to do, and if it varies between arms the comparison stops being about the candidate at all.

This is **not a corpus property**.
The corpus describes a scenario and a checklist; "this skill leans on that one" is a property of the skill text, which already says so in prose.
Nor is it a property of `candidate.revision`, which records which text was handed over.
It is a property of the environment the runner builds, and the invariant is symmetry: **every arm, the baseline included, gets the same delegates.**
The baseline withholds the candidate and nothing else — withholding its delegates as well would narrow the baseline below the model's default, the distortion "Baseline and candidate" already warns about.

So neither schema gains a field.
The asymmetry observed in the first measurement — one arm found `domain-modeling` on disk, two did not — came from chance filesystem discovery, not from a missing declaration, and a declaration would not have prevented it.
Record what the arms actually had in the run's `notes`.

### Audit the transcript before trusting the run

Every breach above was found by grepping the captured tool calls for the other arms' artefacts after the runs finished.
None of them was visible in the deliverables.
A runner that does not capture the transcript cannot check any of these invariants, which is a second reason to capture it — independent of grading the `tool-calls` requirements.

## Do not fold hosts together

The same edit to a skill can help one model and hurt another.
A single overall score would average that away, and the regression would never be seen.

So the comparison unit is `(case, host, model, candidate)`, and the rules are:

- Compare two run files only when `corpus.digest`, `host.id`, and `host.model` all match, they cover the same set of `case_id`s, and `candidate` differs.
- Equal case sets are not sufficient on their own: two runs with the same cases but different trial counts (`{1}` against `{1,2}`) are not comparable either, because the trial protocols differ. Match the trial set too, or say plainly that you are comparing single trials against an average.
- A run whose `host.model` is `"unknown"` is not comparable to anything.
- Do not average accuracy across hosts or across models. There is no field for it, and adding one is a schema change, not a convenience.
- "Improved" is a per-host, per-model statement. Phrase it that way: *Claude Code / opus-5: improved. Codex / gpt-5.4: regressed.* Never as one boolean.

The schema blocks the structured route to an aggregate; it cannot stop someone writing "candidate wins overall" into a free-text `notes`.
Discipline still applies where the validator ends.

Classifying per-host verdicts into all-host improvement, mixed, or host-specific regression is left to the reader for now.
The point of the format is that it keeps the evidence for that judgment intact.

## Running one

```sh
render="plugins/agent-instructions/skills/empirical-prompt-tuning/scripts/eval-render.sh"
corpus="plugins/critique/skills/grilling/evals/cases.json"
out=".dev/evals/grilling/claude-code/opus-5"
mkdir -p "$out"

# 1. render the execution prompt (host-independent, and free of the checklist)
bash "$render" --corpus "$corpus" --case storage-choice-median

# 2. hand it to a fresh executor on whatever host is being measured
#    (Claude Code: a new subagent via the Task tool; see SKILL.md's dispatch rule)

# 3. grade the deliverable with a separate evaluator
bash "$render" --corpus "$corpus" --case storage-choice-median --part judgment

# 4. start from the result skeleton, fill in the verdicts, host, model, tool_uses, duration
bash "$render" --corpus "$corpus" --case storage-choice-median --result-stub > "$out/run-1.json"

# 5. validate before trusting it
bash scripts/check-evals.sh "$out/run-1.json"
```

The baseline arm is the same five steps with `--candidate without-skill`, run under the isolation contract above.

`bash scripts/check-evals.sh` with no arguments validates every committed corpus; that is the form CI runs.

## Comparing runs

`scripts/eval-compare.sh`, next to `eval-render.sh`, puts two or more run files side by side:

```sh
compare="plugins/agent-instructions/skills/empirical-prompt-tuning/scripts/eval-compare.sh"
bash "$compare" "$out"/run-baseline.json "$out"/run-with.json "$out"/run-tampered.json
```

Its primary output is a **requirement-level delta matrix**, one row per `(case_id, trial, requirement_id)`, one column per arm, with the movement against a reference arm.
Accuracy, success, `tool_uses` and `duration_ms` follow as a secondary summary, and deliberately not first: in the first real measurement of this corpus, one arm read 0.750 against another's 0.833 — "the tampered candidate is better" — when the only requirement that had moved was a single non-`[critical]` item going `fail` to `partial`.
A number that summarises sixteen verdicts hides which of them changed, which is the one thing a regression check is for.

The reference defaults to the `without-skill` run when exactly one is given, and to the first argument otherwise; `--reference <file>` overrides it.

Before comparing anything, it enforces the preconditions from "Do not fold hosts together" and refuses the whole comparison — it does not silently drop the offending file:

- `corpus.digest`, `host.id` and `host.model` identical across every run
- `host.model` not `"unknown"`
- the same set of `(case_id, trial)` pairs in every run
- `candidate` distinct between **every pair** of runs, since a comparison of a candidate with itself is not one

Distinctness is the one precondition that is not an equality against a single anchor.
The others are: if every run matches the first on digest, host and case set, they match each other.
Distinctness does not transitively follow, so it is checked over all pairs — `A, B, B` passes an anchored check while carrying the same candidate twice.
Candidate identity is `(kind, revision)`.
A different `label` is not a different candidate, for the reason "Variant exploration" above gives for putting a draft's identity in `revision`: nothing validates `label`.
Two `without-skill` runs therefore always collide, `revision` being unavailable to them — which is correct, since two baselines are not a comparison.

That set equality is between the runs, not against the corpus.
Two runs covering one of three cases satisfy it, and a comparison of only the case you re-ran is a legitimate thing to want, so it is not refused.
What is refused is doing it quietly: the header reports coverage as `cases 1 / 3 in corpus` and names the cases that were not run, because a partial run that reads as a whole-corpus result is how a regression in an unrun case gets reported as absent.

It also runs `scripts/check-evals.sh` over its inputs first, because aggregating a run whose stored `success` disagrees with its verdicts prints the disagreement as though it were a measurement.
Run files are read-only to it.

Three further sections come from what the first measurement made obvious:

- **the same verdict in every arm**, keyed `(case_id, requirement_id)` — six of sixteen requirements, including three `[critical]` ones, never moved. That is a prompt to look, not a verdict: such an item may be a rule the model has outgrown (a skill-shrink candidate), a defect the skill leaves unfixed in every arm, or slack in the corpus. The tool does not classify them, because the three are indistinguishable from the verdicts alone.
- **surface / semantic disagreement**, counted per requirement over every observation — `surface: hit` with a `partial`/`fail` verdict, or `surface: miss` with `pass`. `SKILL.md` only describes the pattern being too narrow; a pattern that fires on a label without checking what follows it is the opposite failure, and one run cannot tell it from chance.
- **`tool_uses` across cases within one arm and one trial**, as raw values with min/max/range, feeding `SKILL.md`'s "one scenario at 3-5x the others" heuristic. That heuristic compares cases inside a single trial, so the rows are per `(arm, trial)` and nothing is computed across trials: pooling trial 1's 3 with trial 2's 15 turns run-to-run variation into what looks like a case skew. A run that did not record `tool_uses` prints `-`; the aggregator never substitutes a zero.

The same rule governs the first section: "identical in every arm" is decided per `(case_id, trial, requirement_id)` and the trial stays in the printed key.
Drop it and a requirement that every arm passed on trial 1 and every arm failed on trial 2 becomes two indistinguishable rows.
Across trials the aggregator only ever tallies observations — the surface/semantic counts — and never averages, so a variance summary stays an unmade decision.

## Deliberately not here

Trigger eval (`triggers.json`), blind A/B comparison of two outputs, a variance summary across trials, and any CI job that calls an LLM.
`eval-compare.sh` reports each trial as its own row and computes nothing across trials, so a variance summary remains an unmade decision rather than one made by accident.
Each of those wants its own format decision, and forcing them into this one now would make the corpus general before there is anything to generalise from.
`trial` is already in the result schema, so repeated trials can be recorded before any of that is designed.

Reusing this result envelope for trigger results looks plausible but is unverified: the run validator is written against `.cases`, `case_id`, and checklist requirements, so a trigger schema needs its own result shape rather than a reinterpretation of this one.
