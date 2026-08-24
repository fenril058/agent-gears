# Persistent eval corpus

`empirical-prompt-tuning` measures an instruction by running it, but a measurement that lives only in the conversation cannot be repeated.
This file defines the on-disk form of that measurement, so the same scenarios and the same fixed checklist can be re-run later, against a different host, a different model, or a different revision of the skill.

Nothing here changes the evaluation semantics.
The checklist, the `[critical]` rule, and the accuracy formula are the ones defined in `SKILL.md`; this is only their persistent encoding.

## Layering

```text
eval corpus            evals/cases.json — scenarios and the fixed checklist. No host in it.
      |
runner interface       scripts/eval-render.sh — corpus -> executor prompt, and the result skeleton.
      |
host execution         Claude Code Task tool / Codex / Copilot. Lives outside this repo's data.
```

The corpus is the shared part.
A case never names a tool, an agent type, a CLI flag, or a model.
Everything that differs between hosts — how an executor is dispatched, how `tool_uses` is read, whether token counts exist at all — belongs to the runner, and lands in the result file as metadata rather than in the corpus.

## Where it lives

```text
plugins/<plugin>/skills/<skill>/evals/cases.json   the corpus, committed
.dev/evals/<skill>/<host>/<model>/<run-id>.json    results, not committed (.dev/ is gitignored)
```

The corpus travels with the skill, so it is distributed to `~/.claude/skills/<skill>/evals/` along with everything else in the directory.
That is harmless; no agent loads it.

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

| Field | Rule |
|---|---|
| `skill` | must equal the skill directory name |
| `cases[].id` | kebab-case, unique, and stable — results reference it, so renaming an id orphans every result already recorded |
| `cases[].scenario` | the situation; `cases[].prompt` is what the user actually types |
| `cases[].tags` | free-form. Conventions in use: `median`, `edge`, `hold-out` (the overfitting check in `SKILL.md`) |
| `requirements[].id` | unique within the case; results report verdicts by this id |
| `requirements[].critical` | required boolean. At least one `true` per case, or the success judgment is vacuous |
| `requirements[].surface` | optional ERE for the surface half of the surface/semantic pair. Include both the Japanese and English spellings in one alternation |

Requirement text is written in English, matching the English-canonical rule for instructions.
`prompt` is written in whatever language the user would really use.

Unknown fields are rejected.
That is not pedantry: it is what stops a cross-host aggregate score from being quietly added to the format later (see "Do not fold hosts together").

## `agent-gears/eval-run@1`

One file is one `(corpus, host, model, candidate)` combination.
That is deliberate — the tuple is the unit of comparison, and giving it its own file means there is nowhere to write a number that spans two of them.

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

- `corpus.digest` is `sha256:` over the corpus file. Two runs are comparable only if the digest matches; editing a case invalidates every earlier result against it, and the digest is what makes that visible.
- `host.model` and `host.version` are optional, because not every host reports them.
- `tool_uses`, `duration_ms`, `retries`, `token_usage` are optional for the same reason. `token_usage` is recorded only where the host provides it; it is never required, and its absence is not a failure.
- `issues[].phase` is one of `understanding` / `planning` / `execution` / `formatting`, the trace phases from `SKILL.md`.
- `unevaluated` carries the honest-reporting escape hatch from `SKILL.md`: an axis that could not be measured is named here rather than narrated into a fake pass.
- `verdict` is `pass` / `fail` / `partial`, and `success` / `accuracy` are derived from the verdicts, not asserted independently:

```text
success  = every [critical] requirement is pass
accuracy = (pass + 0.5 * partial) / requirement count
```

`scripts/check-evals.sh` recomputes both and rejects the file if the stored values disagree.

## Baseline and candidate

`candidate.kind` distinguishes the two things being compared:

| `kind` | Meaning | `revision` |
|---|---|---|
| `with-skill` | the skill was given to the executor | required — which revision (`git:<sha>`, or a working-tree marker) |
| `without-skill` | the skill was withheld; the model's default behaviour | not allowed |

Both baselines the issue asks for fall out of this without more machinery:

- *without skill* — a `without-skill` run against the same corpus digest.
- *previous skill revision* — a `with-skill` run whose `revision` is the older sha.

Checking out an old revision to produce that run is a manual step today.
The data model does not care how the revision got onto disk, only that the run says which one it was.

## Do not fold hosts together

The same edit to a skill can help one model and hurt another.
A single overall score would average that away, and the regression would never be seen.

So the comparison unit is `(case, host, model, candidate)`, and the rules are:

- Compare two run files only when `corpus.digest`, `host.id`, and `host.model` all match and `candidate` differs.
- Do not average accuracy across hosts or across models. There is no field for it, and adding one is a schema change, not a convenience.
- "Improved" is a per-host, per-model statement. Phrase it that way: *Claude Code / opus-5: improved. Codex / gpt-5.4: regressed.* Never as one boolean.

Classifying those per-host verdicts into all-host improvement, mixed, or host-specific regression is left to the reader for now.
The point of the format is that it keeps the evidence for that judgment intact.

## Running one

```sh
render="plugins/agent-instructions/skills/empirical-prompt-tuning/scripts/eval-render.sh"
corpus="plugins/critique/skills/grilling/evals/cases.json"

# 1. render the executor prompt (host-independent)
bash "$render" --corpus "$corpus" --case storage-choice-median

# 2. hand it to a fresh executor on whatever host is being measured
#    (Claude Code: a new subagent via the Task tool; see SKILL.md's dispatch rule)

# 3. start from the result skeleton, fill in verdicts, host, model, tool_uses, duration
bash "$render" --corpus "$corpus" --case storage-choice-median --result-stub \
  > .dev/evals/grilling/claude-code/opus-5/run-1.json

# 4. validate before trusting it
bash scripts/check-evals.sh .dev/evals/grilling/claude-code/opus-5/run-1.json
```

The baseline arm is the same three steps with `--candidate without-skill`.

`bash scripts/check-evals.sh` with no arguments validates every committed corpus; that is the form CI runs.

## Deliberately not here

Trigger eval (`triggers.json`), blind A/B comparison of two outputs, a variance summary across trials, and any CI job that calls an LLM.
Each of those wants its own format decision, and forcing them into this one now would make the corpus general before there is anything to generalise from.
`trial` is already in the result schema, so repeated trials can be recorded before any of that is designed.
