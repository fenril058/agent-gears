#!/usr/bin/env bash
#
# eval-render.sh — eval corpus の1 case を、実行用または採点用のプロンプトへ展開する。
#
# ここが corpus と host の境界である。corpus(cases.json)は host に依存しない
# scenario と requirements だけを持ち、この script がそれを本文に起こす。
# 誰に渡すか(Claude Code の Task tool / Codex / Copilot)は呼び出し側の仕事で、
# corpus にも この script にも host 固有の起動方法を書かない。
#
# 実行と採点を分ける理由:
#   requirements を実行者に見せると、baseline(--candidate without-skill)が
#   checklist をそのまま実装できてしまう。skill の核心的な期待動作を評価側から
#   教えることになるので、uplift が過小評価され with-skill との比較が壊れる。
#   よって実行プロンプトに checklist は入れない。採点は成果物を見た別の
#   evaluator が --part judgment のプロンプトで行う。
#
# 使い方:
#   eval-render.sh --corpus <cases.json> --case <case-id> [options]
#     --candidate with-skill|without-skill  既定 with-skill
#     --part execution|judgment             既定 execution
#     --skill-file <path>   with-skill のとき実行者に読ませる指示(既定: corpus の
#                           2階層上の SKILL.md)
#     --result-stub         プロンプトの代わりに、結果 JSON の雛形を出す
#                           (scripts/check-evals.sh が検証できる形)
#
# 必要: jq。git があれば corpus path をリポジトリルート相対で記録する(無い場合は
# 渡されたパスをそのまま書くので、検証時に解決できる形で渡すこと)。
set -euo pipefail

corpus=""
case_id=""
candidate=""
part="execution"
skill_file=""
stub=0

die() {
  echo "eval-render: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
eval-render.sh --corpus <cases.json> --case <case-id> [options]

  --candidate with-skill|without-skill  既定 with-skill
  --part execution|judgment             既定 execution
  --skill-file <path>                   with-skill のとき読ませる指示
  --result-stub                         結果 JSON の雛形を出す

実行プロンプト(--part execution)に requirements は入らない。
採点は --part judgment のプロンプトで、成果物を見た別 evaluator が行う。
USAGE
}

# 値を取る option は、値が実在することを確かめてから shift する。
need_value() {
  [ "$2" -ge 2 ] || die "$1 needs a value"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --corpus)
    need_value "$1" "$#"
    corpus="$2"
    shift 2
    ;;
  --case)
    need_value "$1" "$#"
    case_id="$2"
    shift 2
    ;;
  --candidate)
    need_value "$1" "$#"
    candidate="$2"
    shift 2
    ;;
  --part)
    need_value "$1" "$#"
    part="$2"
    shift 2
    ;;
  --candidate-file | --skill-file)
    need_value "$1" "$#"
    skill_file="$2"
    shift 2
    ;;
  --result-stub)
    stub=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *) die "unknown option: $1" ;;
  esac
done

[ -n "$corpus" ] || die "--corpus is required"
[ -n "$case_id" ] || die "--case is required"
[ -f "$corpus" ] || die "corpus not found: $corpus"
case "$part" in
execution | judgment) ;;
*) die "--part must be execution or judgment" ;;
esac

# corpus の世代を読む。v1 は対象を裸の .skill で持ち、v2 は .target = {kind, name}。
# 語彙(候補 kind、結果 schema)は世代ごとに違うので、ここで揃える。
# v1 の描画結果は1バイトも変えない —— 既存 measurement の実行プロンプトを
# 再現できなくなると、固定条件の照合ができなくなる。
case "$(jq -r '.schema // empty' "$corpus")" in
"agent-gears/eval-cases@2")
  gen=2
  run_schema="agent-gears/eval-run@2"
  with_kind="with-target"
  without_kind="without-target"
  target_json="$(jq -c '.target' "$corpus")"
  ;;
*)
  gen=1
  run_schema="agent-gears/eval-run@1"
  with_kind="with-skill"
  without_kind="without-skill"
  skill_name="$(jq -r '.skill' "$corpus")"
  ;;
esac
[ -n "$candidate" ] || candidate="$with_kind"
case "$candidate" in
"$with_kind" | "$without_kind") ;;
*) die "--candidate must be $with_kind or $without_kind (corpus is eval-cases@$gen)" ;;
esac
c="$(jq -c --arg id "$case_id" '.cases[] | select(.id == $id)' "$corpus")"
[ -n "$c" ] || die "case \"$case_id\" is not in $corpus"

# 結果に載せる corpus path は、その corpus を含む git リポジトリのルート相対にする。
# check-evals.sh はリポジトリルートで解決するので、絶対パスや呼び出し元相対の
# パスを書くと、別ディレクトリから render した結果が検証できなくなる。
corpus_ref() {
  local dir abs root
  dir="$(cd "$(dirname "$corpus")" && pwd)"
  abs="$dir/$(basename "$corpus")"
  root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$root" ] && [ "${abs#"$root"/}" != "$abs" ]; then
    printf '%s' "${abs#"$root"/}"
  else
    printf '%s' "$corpus"
  fi
}

if [ "$stub" = 1 ]; then
  # 結果側の雛形。REPLACE-ME は check-evals.sh が失格にするので、埋めるまで
  # 「検証を通った」状態にはならない。
  jq -n --arg skill "${skill_name:-}" --argjson target "${target_json:-null}" \
    --arg path "$(corpus_ref)" --arg schema "$run_schema" --arg withKind "$with_kind" \
    --arg digest "sha256:$(sha256sum "$corpus" | cut -d' ' -f1)" \
    --arg case_id "$case_id" --arg kind "$candidate" --argjson c "$c" '
    {
      schema: $schema,
      run_id: "REPLACE-ME",
      started_at: "REPLACE-ME",
      corpus: (if $target == null
               then {skill: $skill, path: $path, digest: $digest}
               else {target: $target, path: $path, digest: $digest} end),
      host: {id: "REPLACE-ME", model: "REPLACE-ME"},
      candidate: ({kind: $kind, label: "REPLACE-ME"}
                  + (if $kind == $withKind then {revision: "REPLACE-ME"} else {} end)),
      results: [{
        case_id: $case_id,
        trial: 1,
        success: false,
        accuracy: 0,
        requirements: [$c.requirements[]
          | {id: .id, verdict: "fail"}
            + (if .surface then {surface: "miss"} else {} end)],
        issues: [],
        discretionary: [],
        unevaluated: []
      }]
    }'
  exit 0
fi

if [ "$part" = "judgment" ]; then
  # 採点プロンプト。成果物を見てから requirements を当てる。実行者には渡さない。
  printf 'You are grading a transcript against a fixed checklist. You did not produce it.\n\n'
  printf '## Scenario the executor was placed in\n\n%s\n\n' "$(jq -r '.scenario' <<<"$c")"
  printf '## User message it was given\n\n%s\n\n' "$(jq -r '.prompt' <<<"$c")"
  cat <<'DELIVERABLE'
## Deliverable to grade

<paste the executor's full output here>

## Observed tool calls

<paste the tool-call transcript here: for each call, the tool name, the target path or
command, and the result. A bare list of tool names is not enough to settle an item.
Write "not captured" if the runner did not record it.>

## File changes observed

<paste each created / modified / deleted path AND the relevant content or diff. A path
list alone settles only "was anything written"; items about what was written need the
content. Write "none observed" if nothing changed, or "not captured" if the runner did
not record it.>

DELIVERABLE
  printf '## Requirements checklist\n\n'
  jq -r '.requirements | to_entries[]
    | "\(.key + 1). \(if .value.critical then "[critical] " else "" end)`\(.value.id)` — \(.value.text)"
      + (if .value.surface then "\n   - surface pattern (informational, judge meaning too): /\(.value.surface)/" else "" end)
      + (if (.value.evidence // "deliverable") != "deliverable"
         then "\n   - judge from: \(.value.evidence) — the deliverable alone cannot settle this item" else "" end)' <<<"$c"
  printf '\n'
  cat <<'RULES'
## Judgment rules

Defined in empirical-prompt-tuning, "Workflow 4 / Instruction-side measurements":

- Each item is `pass`, `partial`, or `fail`.
- Where a surface pattern is given, judge the surface (did the token appear) and the
  meaning separately. Semantic pass with surface miss means the pattern is too narrow —
  report it, do not fail the item for spelling.
- Do not reward intent. Grade only what actually happened.
- **A claim is not evidence.** For an item marked `judge from: tool-calls` or
  `judge from: file-state`, the deliverable saying it read a file, wrote a glossary entry,
  or created an ADR proves nothing. Judge it from the observed tool calls or file changes.
- If the evidence an item needs was not captured, do not guess and do not give it the
  benefit of the doubt. Report `unjudgeable — <what was missing>` for that item; the caller
  records it under `unevaluated` instead of inventing a verdict.

## Report structure

For each requirement id, one line: `<id>: pass|partial|fail|unevaluated (surface: hit|miss) — reason`.

`unevaluated` is not a verdict about the work — it means the evidence needed to judge the
item was not available. Use it only for that, and make the reason name the missing
evidence ("no tool-call transcript", "file contents not captured"). Never use it to avoid
a hard call on evidence you do have.

Then, if any item is not `pass`, one line naming which `[critical]` item dropped or went
unevaluated.

Do not compute success or accuracy. The caller derives both from your verdicts.
RULES
  exit 0
fi

# --- 実行プロンプト。requirements は入れない ---------------------------------
if [ "$candidate" = "$with_kind" ]; then
  if [ -z "$skill_file" ]; then
    skill_file="$(dirname "$(dirname "$corpus")")/SKILL.md"
  fi
  [ -f "$skill_file" ] || die "candidate file not found: $skill_file (pass --candidate-file)"
  target="Read \`$skill_file\` in full and follow it."
else
  # baseline では対象 skill の名前も出さない。名指しすると executor に候補の正体を
  # 教えることになり、host 側の skill 自動読み込みを誘発しうる。
  #
  # ただし禁止をこれ以上広げない。「instruction file を読むな」まで書くと、
  # repository の文書を読む行動そのもの(facts-self-served が測っている当のもの)を
  # 封じてしまい、比較が «with skill» 対 «default» ではなく
  # «with skill» 対 «default から repo 探索を奪ったもの» になる。uplift が
  # 人工的に膨らむ方向の汚染である。skill を渡さないことは runner の仕事で、
  # prompt 側は名指ししないことだけを引き受ける。
  target="None. No target-specific instruction is provided for this scenario. Work as you normally would, using whatever the environment makes available to you."
fi

printf 'You are an executor handling the scenario below with a blank slate.\n\n'
printf '## Target prompt\n\n%s\n\n' "$target"
printf '## Scenario\n\n%s\n\n' "$(jq -r '.scenario' <<<"$c")"
printf '## User message\n\n%s\n\n' "$(jq -r '.prompt' <<<"$c")"

cat <<'TASK'
## Task

Handle the user message under the scenario above and produce the deliverable.
You are not told what the deliverable will be graded on; do the work as you judge best.
On completion, respond with the report structure below.

## Report structure

- Deliverable: <the artifact itself, or an execution summary>
- Trace (tag OK / stuck / skipped per phase, one-line reason when not OK; a single
  `Trace: all OK` line is enough when all four are OK):
  Understanding / Planning / Execution / Formatting
- Unclear points (structured): for each, three lines — Issue / Cause / General Fix Rule,
  plus which phase it originated in.
- Discretionary fill-ins: decisions the instruction did not fix, which you filled in yourself.
- Retries: how many times you redid the same decision, and why.
TASK

cat <<FOOTER

The caller grades this deliverable separately (\`eval-render.sh --part judgment\`) and
records the run as \`$run_schema\` (\`--result-stub\` prints the skeleton),
adding the host/model metadata plus tool_uses / duration that only the caller can observe.
FOOTER
