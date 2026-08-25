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

# ng_scan <label> <走査ルート> <期待する診断行> — 引数なし実行(走査モード)で失格するはず。
ng_scan() {
  local out
  n=$((n + 1))
  if out="$(EVALS_SCAN_ROOT="$2" bash "$CHECK" 2>&1)"; then
    echo "NG: [$1] は失格するはずが合格した" >&2
    fail=1
    return 0
  fi
  if ! printf '%s\n' "$out" | grep -qxF "  - $3"; then
    echo "NG: [$1] の診断行が想定と違う" >&2
    echo "  期待(完全一致): $3" >&2
    printf '%s\n' "$out" >&2
    fail=1
  fi
}

# ok_scan <label> <走査ルート> — 引数なし実行で合格するはず。
ok_scan() {
  local out
  n=$((n + 1))
  if out="$(EVALS_SCAN_ROOT="$2" bash "$CHECK" 2>&1)"; then return 0; fi
  echo "NG: [$1] は合格するはずが失格した" >&2
  printf '%s\n' "$out" >&2
  fail=1
}

# absent <label> <文字列> <本文> — 本文に現れてはいけない。
absent() {
  n=$((n + 1))
  if printf '%s' "$3" | grep -qiF -- "$2"; then
    echo "NG: [$1] に \"$2\" が漏れている" >&2
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
  '$.results[0].success: true but the verdicts say false (false as soon as any critical requirement is fail or partial; null only when no critical has failed and at least one is unevaluated; true when every critical is pass)'

# partial は 0.5 点。5項目中4 pass + 1 partial なら 0.9 でなければならない。
# 完全一致で照合するので、重みを変えると必ず落ちる。
jq '.results[0].requirements[4].verdict = "partial"' "$tmp/run.json" >"$tmp/run-acc.json"
ng "partial を数え損ねた accuracy" "$tmp/run-acc.json" \
  '$.results[0].accuracy: 1 but the verdicts compute to 0.9 (pass=1, partial=0.5, fail=0; unevaluated items are excluded from the denominator)'

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

# --- 実行プロンプトの隔離 -------------------------------------------------
# ここが漏れると baseline が checklist をそのまま実装でき、uplift が測れなくなる。
# skill 名も出さない(候補の正体を教えると host 側の skill 自動読み込みを誘発しうる)。
skill_name="$(jq -r '.skill' "$CORPUS")"
while IFS= read -r cid; do
  for cand in with-skill without-skill; do
    prompt="$(bash "$RENDER" --corpus "$CORPUS" --case "$cid" --candidate "$cand")"
    while IFS= read -r rid; do
      absent "実行プロンプト($cid/$cand)に要件 id" "$rid" "$prompt"
    done < <(jq -r --arg c "$cid" '.cases[] | select(.id == $c) | .requirements[].id' "$CORPUS")
    while IFS= read -r rtext; do
      absent "実行プロンプト($cid/$cand)に要件本文" "${rtext:0:40}" "$prompt"
    done < <(jq -r --arg c "$cid" '.cases[] | select(.id == $c) | .requirements[].text' "$CORPUS")
  done
  # baseline は対象 skill を名指ししない。with-skill は SKILL.md を読ませる必要があるので対象外。
  base="$(bash "$RENDER" --corpus "$CORPUS" --case "$cid" --candidate without-skill)"
  absent "baseline プロンプト($cid)に skill 名" "$skill_name" "$base"
done < <(jq -r '.cases[].id' "$CORPUS")

# 採点プロンプト側には要件が載っていなければ意味がない(隔離のやりすぎ検出)。
judg="$(bash "$RENDER" --corpus "$CORPUS" --case storage-choice-median --part judgment)"
n=$((n + 1))
if ! printf '%s' "$judg" | grep -qF 'one-question'; then
  echo "NG: [採点プロンプト] に要件が載っていない" >&2
  fail=1
fi

# --- 走査モード(evals/ の中身) -------------------------------------------
scan="$tmp/scan"
mkdir -p "$scan/p/skills/grilling/evals"
cp "$CORPUS" "$scan/p/skills/grilling/evals/cases.json"
ok_scan "正規レイアウトの走査" "$scan"

cp "$CORPUS" "$scan/p/skills/grilling/evals/cases.json.bak"
ng_scan "evals/ 直下の退避ファイル" "$scan" \
  'unexpected file under evals/; the corpus must be exactly <skill>/evals/cases.json'
rm -f "$scan/p/skills/grilling/evals/cases.json.bak"

ln -s cases.json "$scan/p/skills/grilling/evals/cases.json.link"
ng_scan "evals/ 直下の symlink" "$scan" \
  'symlinks are not allowed under evals/; the corpus must be a regular file'
rm -f "$scan/p/skills/grilling/evals/cases.json.link"

mkdir -p "$scan/p/skills/grilling/evals/nested/evals"
cp "$CORPUS" "$scan/p/skills/grilling/evals/nested/evals/cases.json"
ng_scan "深すぎる evals/" "$scan" \
  'evals/ must sit at <plugin>/skills/<skill>/evals, not nested deeper'
rm -rf "$scan/p/skills/grilling/evals/nested"

ok_scan "掃除後は再び合格" "$scan"

# --- corpus の上限・制御文字 ----------------------------------------------
jq '.cases[0].requirements = [.cases[0].requirements[0]] + .cases[0].requirements
    + [.cases[0].requirements[1,2]]' "$CORPUS" >"$tmp/many-reqs.json" 2>/dev/null || true
jq '.cases[0].requirements = (.cases[0].requirements + .cases[0].requirements)
    | .cases[0].requirements = [.cases[0].requirements[] | .] ' "$CORPUS" |
  jq '.cases[0].requirements = (.cases[0].requirements | to_entries | map(.value.id = "r\(.key)" | .value))' \
    >"$tmp/many-reqs.json"
ng "要件が8項目以上" "$tmp/many-reqs.json" \
  '$.cases[0].requirements: must hold 3 to 7 items (SKILL.md, Baseline preparation), found 10'

jq '.cases[0].requirements[0].surface = "a\u0000b"' "$CORPUS" >"$tmp/cntrl.json"
ng "surface に制御文字" "$tmp/cntrl.json" \
  '$.cases[0].requirements[0].surface: must not contain control characters'

# REPLACE-ME は雛形が出すフィールドだけを見る。corpus 側の id 等は巻き込まない。
jq '.cases[0].requirements[0].id = "REPLACE-ME"' "$CORPUS" >"$tmp/rid.json"
ok "corpus の id が REPLACE-ME(予約していない名前空間)" "$tmp/rid.json"

jq '.host.id = "REPLACE-ME"' "$tmp/run.json" >"$tmp/run-ph.json"
ng "host.id が未記入のまま" "$tmp/run-ph.json" \
  '$.host.id: still the REPLACE-ME placeholder from --result-stub'

# --- 観測証拠と surface ------------------------------------------------------
# 実行時の振る舞いでしか判定できない要件は、採点プロンプトに判定元が出ていなければ
# judge が成果物の自己申告を証拠として受け取ってしまう。
judg2="$(bash "$RENDER" --corpus "$CORPUS" --case repo-facts-looked-up-edge --part judgment)"
n=$((n + 1))
if ! printf '%s' "$judg2" | grep -qF 'judge from: tool-calls'; then
  echo "NG: [採点プロンプト] に judge from: tool-calls が出ていない" >&2
  fail=1
fi
n=$((n + 1))
if ! printf '%s' "$judg2" | grep -qF 'A claim is not evidence.'; then
  echo "NG: [採点プロンプト] に自己申告禁止の規則が無い" >&2
  fail=1
fi
for slot in 'Observed tool calls' 'File changes observed'; do
  n=$((n + 1))
  if ! printf '%s' "$judg2" | grep -qF "$slot"; then
    echo "NG: [採点プロンプト] に観測欄 '$slot' が無い" >&2
    fail=1
  fi
done
# 実行プロンプト側には観測欄も判定元も出さない(実行者に採点軸を教えない)。
exec2="$(bash "$RENDER" --corpus "$CORPUS" --case repo-facts-looked-up-edge)"
absent "実行プロンプトに判定元" "judge from:" "$exec2"
absent "実行プロンプトに観測欄" "Observed tool calls" "$exec2"

jq '.cases[0].requirements[0].evidence = "vibes"' "$CORPUS" >"$tmp/ev.json"
ng "evidence の値が不正" "$tmp/ev.json" \
  '$.cases[0].requirements[0].evidence: must be one of deliverable / tool-calls / file-state'

# corpus に surface があるのに結果が報告しないと、surface 測定を丸ごと落とせる。
jq '.results[0].requirements = [.results[0].requirements[] | del(.surface)]' \
  "$tmp/run.json" >"$tmp/run-nosurface.json"
ng "surface の報告漏れ" "$tmp/run-nosurface.json" \
  '$.results[0].requirements: recommendation-attached declares a surface pattern in the corpus, so its result must report surface: hit|miss'

# --- 判定不能(unevaluated)-------------------------------------------------
# 採点側が「証拠が無いので判定できない」と言えることと、それを result schema が
# 受け取れることは別。受け取れないと、偽の pass/fail を書くしかなくなる。
jq '.results[0].requirements[0].verdict = "unevaluated"
    | .results[0].requirements[0].note = "tool-call transcript not captured"
    | .results[0].success = null
    | .results[0].accuracy = 1' "$tmp/run.json" >"$tmp/run-unev.json"
ok "critical が未判定なら success=null / accuracy は残りで計算" "$tmp/run-unev.json"

jq '.results[0].requirements[0].verdict = "unevaluated"
    | .results[0].requirements[0].note = "n"
    | .results[0].success = true' "$tmp/run.json" >"$tmp/run-unev-true.json"
ng "critical が未判定なのに success=true" "$tmp/run-unev-true.json" \
  '$.results[0].success: true but the verdicts say null (false as soon as any critical requirement is fail or partial; null only when no critical has failed and at least one is unevaluated; true when every critical is pass)'

jq '.results[0].requirements[0].verdict = "unevaluated"
    | .results[0].success = null | .results[0].accuracy = 1' "$tmp/run.json" >"$tmp/run-unev-nonote.json"
ng "未判定なのに理由が無い" "$tmp/run-unev-nonote.json" \
  '$.results[0].requirements[0]: verdict is unevaluated, so "note" must say what evidence was missing'

# 未判定は accuracy の分母から外れる。5件中1件が未判定で残り4件 pass なら 1。
jq '.results[0].requirements[0].verdict = "unevaluated"
    | .results[0].requirements[0].note = "n"
    | .results[0].success = null | .results[0].accuracy = 0.8' "$tmp/run.json" >"$tmp/run-unev-acc.json"
ng "未判定を分母に残した accuracy" "$tmp/run-unev-acc.json" \
  '$.results[0].accuracy: 0.8 but the verdicts compute to 1 (pass=1, partial=0.5, fail=0; unevaluated items are excluded from the denominator)'

jq '.results[0].requirements = [.results[0].requirements[] | .verdict = "unevaluated" | .note = "n"]
    | .results[0].success = null | .results[0].accuracy = null' "$tmp/run.json" >"$tmp/run-allunev.json"
ok "全件未判定なら accuracy=null" "$tmp/run-allunev.json"

jq '.results[0].requirements = [.results[0].requirements[] | .verdict = "unevaluated" | .note = "n"]
    | .results[0].success = null | .results[0].accuracy = 0' "$tmp/run.json" >"$tmp/run-allunev-num.json"
ng "全件未判定なのに accuracy に数値" "$tmp/run-allunev-num.json" \
  '$.results[0].accuracy: 0 but every requirement is unevaluated, so accuracy must be null'

# --- baseline を default より狭めない ---------------------------------------
# repo の文書を読む行動そのものを禁じると、それを測っている要件の uplift が膨らむ。
base2="$(bash "$RENDER" --corpus "$CORPUS" --case repo-facts-looked-up-edge --candidate without-skill)"
for banned in 'instruction file' 'reference document' 'Do not load'; do
  absent "baseline プロンプトの過剰な禁止" "$banned" "$base2"
done

# verdict の enum。ここが空回りすると任意の文字列が verdict として通る。
jq '.results[0].requirements[0].verdict = "totally-bogus"
    | .results[0].success = false | .results[0].accuracy = 0.8' "$tmp/run.json" >"$tmp/run-bogus.json"
ng "verdict が enum 外" "$tmp/run-bogus.json" \
  '$.results[0].requirements[0].verdict: must be one of pass / fail / partial / unevaluated'

# 証拠の粒度。path 一覧やツール名だけでは「何が書かれたか」を問う要件を判定できない。
judg3="$(bash "$RENDER" --corpus "$CORPUS" --case record-what-settles-edge --part judgment)"
for phrase in 'A bare list of tool names is not enough' 'AND the relevant content or diff'; do
  n=$((n + 1))
  if ! printf '%s' "$judg3" | grep -qF "$phrase"; then
    echo "NG: [採点プロンプト] に証拠の粒度指定が無い: $phrase" >&2
    fail=1
  fi
done

# --- core metric を落とせないこと -------------------------------------------
# 全 pass の run でも accuracy を null にしたり消したりできると、
# 「全件未判定のときだけ null」という形式定義と矛盾し、主要指標を丸ごと失える。
jq '.results[0].accuracy = null' "$tmp/run.json" >"$tmp/run-accnull.json"
ng "判定済みなのに accuracy=null" "$tmp/run-accnull.json" \
  '$.results[0].accuracy: null but 5 requirement(s) were judged, so accuracy must be the number 1'

jq 'del(.results[0].accuracy)' "$tmp/run.json" >"$tmp/run-accdel.json"
ng "accuracy フィールドの欠落" "$tmp/run-accdel.json" \
  '$.results[0]: missing "accuracy"'

jq 'del(.results[0].success)' "$tmp/run.json" >"$tmp/run-sucdel.json"
ng "success フィールドの欠落" "$tmp/run-sucdel.json" \
  '$.results[0]: missing "success"'

# critical が未判定で expected が null のときも、欠落と明示 null を区別する。
jq '.results[0].requirements[0].verdict = "unevaluated"
    | .results[0].requirements[0].note = "n"
    | del(.results[0].success) | .results[0].accuracy = 1' "$tmp/run.json" >"$tmp/run-sucdel2.json"
ng "expected=null でも success の欠落は許さない" "$tmp/run-sucdel2.json" \
  '$.results[0]: missing "success"'

# 採点プロンプトの出力契約が unevaluated を許していないと、strict な evaluator ほど
# 「証拠が無ければ unevaluated と報告せよ」という直前の指示と矛盾する。
n=$((n + 1))
if ! printf '%s' "$judg2" | grep -qF 'pass|partial|fail|unevaluated'; then
  echo "NG: [採点プロンプト] の出力契約が unevaluated を許していない" >&2
  fail=1
fi

# --- 既知の failure は unevaluated に隠れない -------------------------------
# critical A=fail / B=unevaluated のとき、A が観測できている以上「全 critical が
# pass」は論理的に不可能なので success は確定して false。ここを
# 「unevaluated が1つでもあれば null」で先に判定すると、既知の失敗が消える。
mix='.results[0].requirements[0].verdict = "fail"
     | .results[0].requirements[2].verdict = "unevaluated"
     | .results[0].requirements[2].note = "file-state not captured"
     | .results[0].accuracy = 0.75'
jq "$mix | .results[0].success = null" "$tmp/run.json" >"$tmp/run-mix-null.json"
ng "既知の critical fail が unevaluated に隠れる" "$tmp/run-mix-null.json" \
  '$.results[0].success: null but the verdicts say false (false as soon as any critical requirement is fail or partial; null only when no critical has failed and at least one is unevaluated; true when every critical is pass)'

jq "$mix | .results[0].success = false" "$tmp/run.json" >"$tmp/run-mix-false.json"
ok "fail + unevaluated 混在なら success=false" "$tmp/run-mix-false.json"

# partial も「pass でない」ので同じ扱い。
jq '.results[0].requirements[0].verdict = "partial"
    | .results[0].requirements[2].verdict = "unevaluated"
    | .results[0].requirements[2].note = "n"
    | .results[0].success = null | .results[0].accuracy = 0.875' "$tmp/run.json" >"$tmp/run-mix-part.json"
ng "critical partial が unevaluated に隠れる" "$tmp/run-mix-part.json" \
  '$.results[0].success: null but the verdicts say false (false as soon as any critical requirement is fail or partial; null only when no critical has failed and at least one is unevaluated; true when every critical is pass)'

if [ "$fail" = 0 ]; then
  echo "OK: check-evals.sh のテスト ${n} 件"
fi
exit "$fail"
