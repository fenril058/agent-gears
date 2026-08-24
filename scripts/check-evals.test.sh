#!/usr/bin/env bash
#
# check-evals.test.sh — scripts/check-evals.sh の単体テスト。
#
# ここで守りたいのは「壊れた corpus / 結果を本当に落とすか」である。合格側だけ見て
# いると、判定が丸ごと空回りしていても OK が出てしまう。特に success / accuracy の
# 検算は jq の中にあり、静かに壊れても誰も気づかない。
#
# 必要: jq。CI では consistency job(nix shell nixpkgs#jq)から実行する。
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

CHECK="scripts/check-evals.sh"
CORPUS="plugins/critique/skills/grilling/evals/cases.json"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
n=0

# ok <label> <file> — 合格するはず。
ok() {
  n=$((n + 1))
  if out="$(bash "$CHECK" "$2" 2>&1)"; then return 0; fi
  echo "NG: [$1] は合格するはずが失格した" >&2
  printf '%s\n' "$out" >&2
  fail=1
}

# ng <label> <file> <期待するエラー文の一部> — 失格し、その理由を挙げるはず。
ng() {
  n=$((n + 1))
  local out
  if out="$(bash "$CHECK" "$2" 2>&1)"; then
    echo "NG: [$1] は失格するはずが合格した" >&2
    fail=1
    return 0
  fi
  if ! printf '%s' "$out" | grep -qF -- "$3"; then
    echo "NG: [$1] の失格理由が想定と違う(期待: '$3')" >&2
    printf '%s\n' "$out" >&2
    fail=1
  fi
}

# --- corpus ---------------------------------------------------------------
ok "同梱の corpus" "$CORPUS"

jq '.cases[0].requirements = [.cases[0].requirements[] | .critical = false]' \
  "$CORPUS" >"$tmp/no-critical.json"
ng "[critical] ゼロ" "$tmp/no-critical.json" 'at least one requirement must have "critical": true'

jq '.cases[0].id = "Not_Kebab"' "$CORPUS" >"$tmp/bad-id.json"
ng "case id が kebab-case でない" "$tmp/bad-id.json" 'must be kebab-case'

jq '.cases[0].requirements[1].id = .cases[0].requirements[0].id' "$CORPUS" >"$tmp/dup-req.json"
ng "requirement id 重複" "$tmp/dup-req.json" 'duplicate requirement id'

jq '.cases[0].critcal = true' "$CORPUS" >"$tmp/typo.json"
ng "未知フィールド(集約スコアの侵入経路)" "$tmp/typo.json" 'unknown field "critcal"'

jq '.skill = "not-grilling"' "$CORPUS" >"$tmp/wrong-skill.json"
ng "skill 名とディレクトリの不一致" "$tmp/wrong-skill.json" 'does not match the skill directory'

jq '.cases[0].requirements[0].surface = "a(b"' "$CORPUS" >"$tmp/bad-re.json"
ng "surface が ERE として不正" "$tmp/bad-re.json" 'not a valid ERE'

# --- 実行結果 -------------------------------------------------------------
# 雛形から「全 pass」の結果を組み立てる(success=true / accuracy=1)。
render="plugins/agent-instructions/skills/empirical-prompt-tuning/scripts/eval-render.sh"
bash "$render" --corpus "$CORPUS" --case storage-choice-median --result-stub |
  jq '.run_id = "t" | .host.id = "test-host" | .host.model = "test-model"
      | .candidate.label = "t" | .candidate.revision = "git:0000000"
      | .results[0].requirements = [.results[0].requirements[] | .verdict = "pass"]
      | .results[0].success = true | .results[0].accuracy = 1' >"$tmp/run.json"
ok "全 pass の結果" "$tmp/run.json"

# [critical] が1つ落ちれば success は false でなければならない。
jq '.results[0].requirements[0].verdict = "fail" | .results[0].accuracy = 0.8' \
  "$tmp/run.json" >"$tmp/run-crit.json"
ng "[critical] 失敗なのに success=true" "$tmp/run-crit.json" '[critical] verdicts say false'

# partial は 0.5 点。0.9 でなければならない。
jq '.results[0].requirements[4].verdict = "partial"' "$tmp/run.json" >"$tmp/run-acc.json"
ng "partial を数え損ねた accuracy" "$tmp/run-acc.json" 'the verdicts compute to 0.9'

jq '.corpus.digest = "sha256:0000"' "$tmp/run.json" >"$tmp/run-digest.json"
ng "corpus digest のずれ" "$tmp/run-digest.json" 'results are only comparable within one corpus digest'

jq '.results[0].case_id = "no-such-case"' "$tmp/run.json" >"$tmp/run-case.json"
ng "存在しない case_id" "$tmp/run-case.json" 'is not a case in'

jq 'del(.results[0].requirements[0])' "$tmp/run.json" >"$tmp/run-missing.json"
ng "requirement の報告漏れ" "$tmp/run-missing.json" 'ids must cover the case exactly'

jq '.results[0].overall_score = 0.87' "$tmp/run.json" >"$tmp/run-agg.json"
ng "総合スコアの持ち込み" "$tmp/run-agg.json" 'unknown field "overall_score"'

jq '.candidate.kind = "without-skill"' "$tmp/run.json" >"$tmp/run-kind.json"
ng "without-skill に revision" "$tmp/run-kind.json" 'only meaningful when kind is "with-skill"'

jq 'del(.corpus.path)' "$tmp/run.json" >"$tmp/run-nopath.json"
ng "corpus.path が引けない" "$tmp/run-nopath.json" 'does not resolve to a corpus file'

if [ "$fail" = 0 ]; then
  echo "OK: check-evals.sh のテスト ${n} 件"
fi
exit "$fail"
