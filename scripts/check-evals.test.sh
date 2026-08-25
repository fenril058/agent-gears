#!/usr/bin/env bash
#
# check-evals.test.sh — scripts/check-evals.sh の単体テスト。
#
# ここで守りたいのは「壊れた corpus / 結果を本当に落とすか」である。合格側だけ見て
# いると、判定が丸ごと空回りしていても OK が出てしまう。特に success / accuracy の
# 検算は jq の中にあり、静かに壊れても誰も気づかない。
#
# 期待するエラーは【1行まるごと完全一致】で照合する。部分一致にすると
# "compute to 0.9" が "compute to 0.98" にも当たり、partial の重みを 0.5 から
# 0.9 に変えてもテストが通ってしまう(実際に踏んだ)。反証できない assert は
# assert ではない。
#
# 必要: jq。CI では consistency job(nix shell nixpkgs#jq)から実行する。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

CHECK="scripts/check-evals.sh"

# plugin 名はハードコードしない(skill は plugin 間を移動しうる)。
# 見つからなければ黙って合格せず落とす。
CORPUS="$(find plugins -path '*/skills/grilling/evals/cases.json' -print -quit)"
RENDER="$(find plugins -path '*/empirical-prompt-tuning/scripts/eval-render.sh' -print -quit)"
[ -n "$CORPUS" ] || {
  echo "grilling の corpus が見つからない" >&2
  exit 1
}
[ -n "$RENDER" ] || {
  echo "eval-render.sh が見つからない" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
n=0

# ok <label> <file> — 合格するはず。
ok() {
  local out
  n=$((n + 1))
  if out="$(bash "$CHECK" "$2" 2>&1)"; then return 0; fi
  echo "NG: [$1] は合格するはずが失格した" >&2
  printf '%s\n' "$out" >&2
  fail=1
}

# ng <label> <file> <期待する診断行(完全一致)> — 失格し、その行を出すはず。
ng() {
  local out
  n=$((n + 1))
  if out="$(bash "$CHECK" "$2" 2>&1)"; then
    echo "NG: [$1] は失格するはずが合格した" >&2
    fail=1
    return 0
  fi
  if ! printf '%s\n' "$out" | grep -qxF "  - $3"; then
    echo "NG: [$1] の診断行が想定と違う" >&2
    echo "  期待(完全一致): $3" >&2
    echo "  実際:" >&2
    printf '%s\n' "$out" >&2
    fail=1
  fi
}

# --- corpus ---------------------------------------------------------------
ok "同梱の corpus" "$CORPUS"

jq '.cases[0].requirements = [.cases[0].requirements[] | .critical = false]' \
  "$CORPUS" >"$tmp/no-critical.json"
ng "[critical] ゼロ" "$tmp/no-critical.json" \
  '$.cases[0].requirements: at least one requirement must have "critical": true (otherwise the success judgment is vacuous)'

jq '.cases[0].id = "Not_Kebab"' "$CORPUS" >"$tmp/bad-id.json"
ng "case id が kebab-case でない" "$tmp/bad-id.json" \
  '$.cases[0].id: must be kebab-case (stable across runs)'

jq '.cases[0].requirements[1].id = .cases[0].requirements[0].id' "$CORPUS" >"$tmp/dup-req.json"
ng "requirement id 重複" "$tmp/dup-req.json" \
  '$.cases[0].requirements: duplicate requirement id "one-question"'

jq '.cases[0].critcal = true' "$CORPUS" >"$tmp/typo.json"
ng "未知フィールド(集約スコアの侵入経路)" "$tmp/typo.json" \
  '$.cases[0]: unknown field "critcal"'

jq '.cases[0].requirements[0].surface = "a(b"' "$CORPUS" >"$tmp/bad-re.json"
ng "surface が ERE として不正" "$tmp/bad-re.json" \
  'surface pattern is not a valid ERE: a(b'

# SKILL.md の「シナリオは最低2つ」「要件は3〜7項目」を corpus 側で強制する。
jq '.cases = [.cases[0]]' "$CORPUS" >"$tmp/one-case.json"
ng "シナリオが1つだけ" "$tmp/one-case.json" \
  '$.cases: needs at least 2 scenarios (SKILL.md: "One scenario overfits. Minimum 2, ideally 3.")'

jq '.cases[0].requirements = [.cases[0].requirements[0,1]]' "$CORPUS" >"$tmp/two-reqs.json"
ng "要件が2項目しかない" "$tmp/two-reqs.json" \
  '$.cases[0].requirements: must hold 3 to 7 items (SKILL.md, Baseline preparation), found 2'

# 正規レイアウト上の corpus だけ skill 名を突き合わせる。
mkdir -p "$tmp/plugins/p/skills/grilling/evals"
jq '.skill = "not-grilling"' "$CORPUS" >"$tmp/plugins/p/skills/grilling/evals/cases.json"
ng "skill 名とディレクトリの不一致" "$tmp/plugins/p/skills/grilling/evals/cases.json" \
  '$.skill: "not-grilling" does not match the skill directory "grilling"'

cp "$CORPUS" "$tmp/loose-cases.json"
ok "正規 path 外の正しい corpus(偽陽性を出さない)" "$tmp/loose-cases.json"

# --- 実行結果 -------------------------------------------------------------
# 雛形は未記入のままでは通らない。埋めて初めて合格する。
bash "$RENDER" --corpus "$CORPUS" --case storage-choice-median --result-stub >"$tmp/stub.json"
ng "未記入の雛形" "$tmp/stub.json" \
  '$.run_id: still the REPLACE-ME placeholder from --result-stub'

jq '.run_id = "t" | .started_at = "2026-01-01T00:00:00Z"
    | .host.id = "test-host" | .host.model = "test-model"
    | .candidate.label = "t" | .candidate.revision = "git:0000000"
    | .results[0].requirements = [.results[0].requirements[] | .verdict = "pass"]
    | .results[0].success = true | .results[0].accuracy = 1' \
  "$tmp/stub.json" >"$tmp/run.json"
ok "全 pass の結果" "$tmp/run.json"

# [critical] が1つ落ちれば success は false でなければならない。
jq '.results[0].requirements[0].verdict = "fail" | .results[0].accuracy = 0.8' \
  "$tmp/run.json" >"$tmp/run-crit.json"
ng "[critical] 失敗なのに success=true" "$tmp/run-crit.json" \
  '$.results[0].success: true but [critical] verdicts say false (success is true only when every critical requirement is pass)'

# partial は 0.5 点。5項目中4 pass + 1 partial なら 0.9 でなければならない。
# 完全一致で照合するので、重みを変えると必ず落ちる。
jq '.results[0].requirements[4].verdict = "partial"' "$tmp/run.json" >"$tmp/run-acc.json"
ng "partial を数え損ねた accuracy" "$tmp/run-acc.json" \
  '$.results[0].accuracy: 1 but the verdicts compute to 0.9 (pass=1, partial=0.5, fail=0)'

jq '.corpus.digest = "sha256:0000"' "$tmp/run.json" >"$tmp/run-digest.json"
ng "corpus digest のずれ" "$tmp/run-digest.json" \
  "\$.corpus.digest: sha256:0000 but the corpus now hashes to sha256:$(sha256sum "$CORPUS" | cut -d' ' -f1) — results are only comparable within one corpus digest"

jq '.results[0].case_id = "no-such-case"' "$tmp/run.json" >"$tmp/run-case.json"
ng "存在しない case_id" "$tmp/run-case.json" \
  '$.results[0].case_id: "no-such-case" is not a case in grilling'"'"'s corpus'

jq 'del(.results[0].requirements[0])' "$tmp/run.json" >"$tmp/run-missing.json"
ng "requirement の報告漏れ" "$tmp/run-missing.json" \
  '$.results[0].requirements: ids must cover the case exactly — missing ["one-question"], unexpected []'

jq '.results[0].overall_score = 0.87' "$tmp/run.json" >"$tmp/run-agg.json"
ng "総合スコアの持ち込み" "$tmp/run-agg.json" \
  '$.results[0]: unknown field "overall_score"'

jq '.candidate.kind = "without-skill"' "$tmp/run.json" >"$tmp/run-kind.json"
ng "without-skill に revision" "$tmp/run-kind.json" \
  '$.candidate.revision: only meaningful when kind is "with-skill"'

jq 'del(.host.model)' "$tmp/run.json" >"$tmp/run-nomodel.json"
ng "host.model の欠落(model 固有 regression を隠す)" "$tmp/run-nomodel.json" \
  '$.host: missing "model"'

jq '.results[0].token_usage = {input: -7}' "$tmp/run.json" >"$tmp/run-tok.json"
ng "負の token 数" "$tmp/run-tok.json" \
  '$.results[0].token_usage.input: must be a non-negative integer'

jq 'del(.corpus.path)' "$tmp/run.json" >"$tmp/run-nopath.json"
ng "corpus.path が引けない" "$tmp/run-nopath.json" \
  '$.corpus.path: "<missing>" does not resolve to a corpus file (results cannot be validated without it)'

# 参照先 corpus を信用しない。[critical] ゼロの corpus を指せば
# 「全 fail なのに success=true」が空虚に真になってしまう。
mkdir -p "$tmp/plugins/q/skills/grilling/evals"
badc="$tmp/plugins/q/skills/grilling/evals/cases.json"
jq '.cases[0].requirements = [.cases[0].requirements[] | .critical = false]' "$CORPUS" >"$badc"
jq --arg p "$badc" --arg d "sha256:$(sha256sum "$badc" | cut -d' ' -f1)" \
  '.corpus.path = $p | .corpus.digest = $d
   | .results[0].requirements = [.results[0].requirements[] | .verdict = "fail"]
   | .results[0].success = true | .results[0].accuracy = 0' \
  "$tmp/run.json" >"$tmp/run-badcorpus.json"
ng "不正な corpus を参照する run" "$tmp/run-badcorpus.json" \
  '$.cases[0].requirements: at least one requirement must have "critical": true (otherwise the success judgment is vacuous)'

if [ "$fail" = 0 ]; then
  echo "OK: check-evals.sh のテスト ${n} 件"
fi
exit "$fail"
