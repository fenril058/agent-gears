#!/usr/bin/env bash
#
# eval-render.sh — eval corpus の1 case を、executor に渡すプロンプトへ展開する。
#
# ここが corpus と host の境界である。corpus(cases.json)は host に依存しない
# scenario と requirements だけを持ち、この script が empirical-prompt-tuning の
# 「subagent invocation contract」に沿った本文を stdout に出す。
# それを誰に渡すか(Claude Code の Task tool / Codex / Copilot)は呼び出し側の仕事で、
# corpus にも この script にも host 固有の起動方法を書かない。
#
# 使い方:
#   eval-render.sh --corpus <cases.json> --case <case-id> [options]
#     --candidate with-skill|without-skill  既定 with-skill
#     --skill-file <path>   with-skill のとき executor に読ませる指示(既定: corpus の
#                           2階層上の SKILL.md)
#     --result-stub         プロンプトの代わりに、結果 JSON の雛形を出す
#                           (scripts/check-evals.sh が検証できる形)
#
# 必要: jq。
set -euo pipefail

corpus=""
case_id=""
candidate="with-skill"
skill_file=""
stub=0

die() {
  echo "eval-render: $*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --corpus)
    corpus="${2:-}"
    shift 2
    ;;
  --case)
    case_id="${2:-}"
    shift 2
    ;;
  --candidate)
    candidate="${2:-}"
    shift 2
    ;;
  --skill-file)
    skill_file="${2:-}"
    shift 2
    ;;
  --result-stub)
    stub=1
    shift
    ;;
  -h | --help)
    sed -n '3,20p' "$0"
    exit 0
    ;;
  *) die "unknown option: $1" ;;
  esac
done

[ -n "$corpus" ] || die "--corpus is required"
[ -n "$case_id" ] || die "--case is required"
[ -f "$corpus" ] || die "corpus not found: $corpus"
case "$candidate" in
with-skill | without-skill) ;;
*) die "--candidate must be with-skill or without-skill" ;;
esac

skill_name="$(jq -r '.skill' "$corpus")"
c="$(jq -c --arg id "$case_id" '.cases[] | select(.id == $id)' "$corpus")"
[ -n "$c" ] || die "case \"$case_id\" is not in $corpus"

if [ "$stub" = 1 ]; then
  # 結果側の雛形。verdict は書き込まれるまで fail、success/accuracy は
  # verdict から計算し直すこと(check-evals.sh が検算する)。
  jq -n --arg skill "$skill_name" --arg path "$corpus" \
    --arg digest "sha256:$(sha256sum "$corpus" | cut -d' ' -f1)" \
    --arg case_id "$case_id" --arg kind "$candidate" --argjson c "$c" '
    {
      schema: "agent-gears/eval-run@1",
      run_id: "REPLACE-ME",
      started_at: "REPLACE-ME",
      corpus: {skill: $skill, path: $path, digest: $digest},
      host: {id: "REPLACE-ME", model: "REPLACE-ME"},
      candidate: ({kind: $kind, label: "REPLACE-ME"}
                  + (if $kind == "with-skill" then {revision: "REPLACE-ME"} else {} end)),
      results: [{
        case_id: $case_id,
        trial: 1,
        success: false,
        accuracy: 0,
        requirements: [$c.requirements[] | {id: .id, verdict: "fail"}],
        issues: [],
        discretionary: [],
        unevaluated: []
      }]
    }'
  exit 0
fi

if [ "$candidate" = "with-skill" ]; then
  if [ -z "$skill_file" ]; then
    skill_file="$(dirname "$(dirname "$corpus")")/SKILL.md"
  fi
  [ -f "$skill_file" ] || die "skill file not found: $skill_file (pass --skill-file)"
  target="Read \`$skill_file\` in full and follow it."
else
  target="None. This is the baseline run: no skill is provided. Handle the scenario however you would by default. Do not go looking for a skill named \"$skill_name\"."
fi

printf 'You are an executor handling the scenario below with a blank slate.\n\n'
printf '## Target prompt\n\n%s\n\n' "$target"
printf '## Scenario\n\n%s\n\n' "$(jq -r '.scenario' <<<"$c")"
printf '## User message\n\n%s\n\n' "$(jq -r '.prompt' <<<"$c")"

printf '## Requirements checklist (items the deliverable must satisfy)\n\n'
jq -r '.requirements | to_entries[]
  | "\(.key + 1). \(if .value.critical then "[critical] " else "" end)`\(.value.id)` — \(.value.text)"
    + (if .value.surface then "\n   - surface pattern (informational, judge meaning too): /\(.value.surface)/" else "" end)' <<<"$c"
printf '\n'
printf 'Judgment rules are defined in empirical-prompt-tuning, "Workflow 4 / Instruction-side measurements":\n'
printf 'each item is pass / partial / fail; the run counts as a success only when every [critical] item is pass.\n\n'

printf '## Task\n\n'
printf '1. Handle the user message under the scenario above, producing the deliverable.\n'
printf '2. On completion, respond with the report structure below.\n\n'

cat <<'REPORT'
## Report structure

- Deliverable: <artifact or execution summary>
- Requirement achievement: for each item id, pass / fail / partial with a one-line reason.
  Report ids exactly as listed above.
- Trace (tag OK / stuck / skipped per phase, one-line reason when not OK; a single
  `Trace: all OK` line is enough when all four are OK):
  Understanding / Planning / Execution / Formatting
- Unclear points (structured): for each, three lines — Issue / Cause / General Fix Rule,
  plus which phase it originated in.
- Discretionary fill-ins: decisions the instruction did not fix, which you filled in yourself.
- Retries: how many times you redid the same decision, and why.
REPORT

cat <<'FOOTER'

The caller records this against the case as `agent-gears/eval-run@1`
(`eval-render.sh --result-stub` prints the skeleton) and adds the host/model
metadata plus tool_uses / duration that only the caller can observe.
FOOTER
