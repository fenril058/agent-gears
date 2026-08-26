#!/usr/bin/env bash
#
# eval-compare.test.sh — eval-compare.sh の単体テスト。
#
# ここで守りたいのは2つある。
#
# 1. 比較不能な run を黙って混ぜないこと。digest / host.id / host.model /
#    model!=unknown / (case_id,trial) 集合 / candidate が異なること、の各条件は
#    どれか1つでも空回りすると「別モデルの結果を平均した表」が黙って出る。
#    期待する診断行は【1行まるごと完全一致】で照合する。部分一致にすると
#    条件を1つ落としても通ってしまう。
# 2. requirement 単位の movement が正しく出ること。accuracy だけ合っていても
#    差分行列が空回りしていたら、この道具の存在理由が無くなる。
#
# 表の桁幅は契約ではないので、行の照合前に空白を潰す(連続空白を1つにし、
# 行頭行末を落とす)。潰すのは空白だけで、
# verdict・surface・movement の中身は完全一致で見る。
#
# 必要: jq。CI では consistency job(nix shell nixpkgs#jq)から実行する。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../../.." && pwd)"
COMPARE="$HERE/eval-compare.sh"
RENDER="$HERE/eval-render.sh"

[ -f "$REPO/scripts/check-evals.sh" ] || {
  echo "リポジトリルートを取り違えている: $REPO" >&2
  exit 1
}
[ -f "$COMPARE" ] || {
  echo "eval-compare.sh が見つからない" >&2
  exit 1
}
[ -f "$RENDER" ] || {
  echo "eval-render.sh が見つからない" >&2
  exit 1
}

cd "$REPO" || exit 1

# plugin 名はハードコードしない(skill は plugin 間を移動しうる)。
CORPUS="$(find plugins -path '*/skills/grilling/evals/cases.json' -print -quit)"
[ -n "$CORPUS" ] || {
  echo "grilling の corpus が見つからない" >&2
  exit 1
}

tmp="$(mktemp -d)"
# digest mismatch の fixture だけは、corpus.path がリポジトリルートから解決できないと
# ならないのでリポジトリ内に置く。.dev/ は gitignore なので作業ツリーを汚さない。
mkdir -p "$REPO/.dev"
intmp="$(mktemp -d -p "$REPO/.dev")"
trap 'rm -rf "$tmp" "$intmp"' EXIT
fail=0
n=0

note() {
  echo "NG: $1" >&2
  fail=1
}

# --- fixture -----------------------------------------------------------------
stub() { bash "$RENDER" --corpus "$CORPUS" --case "$1" --result-stub; }

# A = reference (without-skill)。tool_uses / duration_ms を持つ。
# accuracy = (0 + 0.5 + 1 + 1 + 0) / 5 = 0.5、critical の one-question が fail なので success=false。
stub storage-choice-median >"$tmp/stub1.json"
stub repo-facts-looked-up-edge >"$tmp/stub2.json"
stub record-what-settles-edge >"$tmp/stub3.json"
jq '.run_id = "run-a" | .started_at = "2026-08-26T00:00:00Z"
  | .host = {id: "claude-code", model: "claude-sonnet-5"}
  | .candidate = {kind: "without-skill", label: "baseline"}
  | .results[0].tool_uses = 3 | .results[0].duration_ms = 1000
  | .results[0].success = false | .results[0].accuracy = 0.5
  | .results[0].requirements = [
      {id: "one-question", verdict: "fail"},
      {id: "recommendation-attached", verdict: "partial", surface: "hit"},
      {id: "no-implementation", verdict: "pass"},
      {id: "asks-a-decision", verdict: "pass"},
      {id: "interview-continues", verdict: "fail"}]' "$tmp/stub1.json" >"$tmp/a.json"

# B = candidate (with-skill)。tool_uses / duration_ms を【持たない】。
# accuracy = (1 + 0 + 1 + 0 + 0.5) / 5 = 0.5、critical の recommendation-attached が fail なので success=false。
jq '.run_id = "run-b" | .started_at = "2026-08-26T00:00:00Z"
  | .host = {id: "claude-code", model: "claude-sonnet-5"}
  | .candidate = {kind: "with-skill", label: "candidate", revision: "git:deadbee"}
  | .results[0].success = false | .results[0].accuracy = 0.5
  | .results[0].requirements = [
      {id: "one-question", verdict: "pass"},
      {id: "recommendation-attached", verdict: "fail", surface: "hit"},
      {id: "no-implementation", verdict: "pass"},
      {id: "asks-a-decision", verdict: "fail"},
      {id: "interview-continues", verdict: "partial"}]' "$tmp/stub1.json" >"$tmp/b.json"

# --- 正常系 ------------------------------------------------------------------
out=""
if ! out="$(bash "$COMPARE" "$tmp/a.json" "$tmp/b.json" 2>"$tmp/err")"; then
  note "正常な比較が失格した"
  cat "$tmp/err" >&2
fi
out="$(printf '%s\n' "$out" | tr -s ' ' | sed 's/^ *//; s/ *$//')"

# line <label> <期待する行(空白正規化後の完全一致)>
line() {
  n=$((n + 1))
  printf '%s\n' "$out" | grep -qxF "$2" && return 0
  note "[$1] の行が出ていない"
  echo "  期待(完全一致): $2" >&2
}

# nline <label> <出てはいけない行>
nline() {
  n=$((n + 1))
  printf '%s\n' "$out" | grep -qxF "$2" || return 0
  note "[$1] が出てはいけないのに出ている"
  echo "  出てはいけない行: $2" >&2
}

# --- requirement 単位の movement ---------------------------------------------
line "fail->pass" \
  "storage-choice-median 1 one-question * fail pass #2 fail->pass"
line "pass->fail" \
  "storage-choice-median 1 asks-a-decision pass fail #2 pass->fail"
line "fail->partial" \
  "storage-choice-median 1 interview-continues fail partial #2 fail->partial"
line "partial->fail は surface 付きで出る" \
  "storage-choice-median 1 recommendation-attached * partial/hit fail/hit #2 partial/hit->fail/hit"
# 動いていない requirement に movement を書かない(空欄)。
line "movement 無しの行" \
  "storage-choice-median 1 no-implementation * pass pass"
nline "動いていないのに movement が出る" \
  "storage-choice-median 1 no-implementation * pass pass #2 pass->pass"

# --- 全 arm 同一 verdict -----------------------------------------------------
line "全 arm 同一(critical)" \
  "storage-choice-median 1 no-implementation pass [critical]"
nline "動いた requirement が全 arm 同一に混ざる" \
  "storage-choice-median 1 one-question fail [critical]"

# --- surface / semantic の食い違い -------------------------------------------
# A は hit+partial、B は hit+fail。どちらも surface hit なのに semantic が pass でない。
line "surface hit なのに semantic が pass でない組を数える" \
  "storage-choice-median / recommendation-attached 2 hit+fail x1, hit+partial x1"

# --- secondary summary と tool_uses の欠損 ------------------------------------
line "tool_uses / duration_ms がある arm" \
  "storage-choice-median 1 #1* false 0.5 3 1000"
line "無い arm は捏造せず - にする" \
  "storage-choice-median 1 #2 false 0.5 - -"
line "tool_uses の case 間まとめ(記録あり)" \
  "#1* trial 1 3 min 3 max 3 range 0"
line "tool_uses の case 間まとめ(記録なし)" \
  "#2 trial 1 - (tool_uses 未記録)"

# --- corpus の網羅性 ---------------------------------------------------------
# case 集合の一致は run どうしの相対比較でしかない。corpus に3 case あって1 case しか
# 走っていなくても両者は「一致」する。拒否はしないが、黙って corpus 全体の比較に
# 見せてはいけない。fixture は storage-choice-median 1件だけなので partial 側。
line "走った case 数を corpus の総数と並べて出す" \
  "cases 1 / 3 in corpus trials {1}"
line "走っていない case を名指しする" \
  "PARTIAL CORPUS — not run: repo-facts-looked-up-edge, record-what-settles-edge"

# 全 case を走らせた比較では PARTIAL を出さない(出ると狼少年になる)。
n=$((n + 1))
full_a="$tmp/full-a.json"
full_b="$tmp/full-b.json"
jq --slurpfile s2 "$tmp/stub2.json" --slurpfile s3 "$tmp/stub3.json" \
  '.results += [$s2[0].results[0], $s3[0].results[0]]' "$tmp/a.json" >"$full_a"
jq --slurpfile s2 "$tmp/stub2.json" --slurpfile s3 "$tmp/stub3.json" \
  '.results += [$s2[0].results[0], $s3[0].results[0]]' "$tmp/b.json" >"$full_b"
fullout="$(bash "$COMPARE" "$full_a" "$full_b" | tr -s ' ' | sed 's/^ *//; s/ *$//')"
printf '%s\n' "$fullout" | grep -qxF "cases 3 / 3 in corpus trials {1}" ||
  note "全 case を走らせた比較で網羅数が 3 / 3 にならない"
n=$((n + 1))
printf '%s\n' "$fullout" | grep -q "PARTIAL CORPUS" &&
  note "全 case を走らせたのに PARTIAL CORPUS が出る"

# --- reference の既定と上書き ------------------------------------------------
n=$((n + 1))
rev="$(bash "$COMPARE" "$tmp/b.json" "$tmp/a.json" | tr -s ' ' | sed 's/^ *//; s/ *$//')"
printf '%s\n' "$rev" | grep -qxF "#2* without-skill baseline" ||
  note "引数順に関わらず without-skill が既定の reference にならない"
n=$((n + 1))
ovr="$(bash "$COMPARE" "$tmp/a.json" "$tmp/b.json" --reference "$tmp/b.json" | tr -s ' ' | sed 's/^ *//; s/ *$//')"
printf '%s\n' "$ovr" | grep -qxF "storage-choice-median 1 one-question * fail pass #1 pass->fail" ||
  note "--reference で movement の向きが反転しない"

# --- 複数 trial: trial をまたいだ計算をしない --------------------------------
# trial 1 は tool_uses 3・no-implementation が両 arm pass、
# trial 2 は tool_uses 30・全要件が両 arm fail。
# trial を混ぜると (a) tool_uses の幅が 3..30 になり case 間スキューに化け、
# (b) same verdict の表に区別できない2行が出る。
twotrial='.results[0].tool_uses = 3
  | .results += [(.results[0] | .trial = 2 | .tool_uses = 30 | .accuracy = 0
                  | .requirements = [.requirements[] | .verdict = "fail"])]'
jq "$twotrial" "$tmp/a.json" >"$tmp/a-2t.json"
jq "$twotrial" "$tmp/b.json" >"$tmp/b-2t.json"
two="$(bash "$COMPARE" "$tmp/a-2t.json" "$tmp/b-2t.json" | tr -s ' ' | sed 's/^ *//; s/ *$//')"

tline() {
  n=$((n + 1))
  printf '%s\n' "$two" | grep -qxF "$2" && return 0
  note "[$1] の行が出ていない"
  echo "  期待(完全一致): $2" >&2
}
ntline() {
  n=$((n + 1))
  printf '%s\n' "$two" | grep -qxF "$2" || return 0
  note "[$1] が出てはいけないのに出ている"
  echo "  出てはいけない行: $2" >&2
}

tline "tool_uses は trial ごとに集計する(trial 1)" "#1* trial 1 3 min 3 max 3 range 0"
tline "tool_uses は trial ごとに集計する(trial 2)" "#1* trial 2 30 min 30 max 30 range 0"
ntline "tool_uses が trial をまたいで幅を作る" "#1* 3, 30 min 3 max 30 range 27"

tline "same verdict は trial を表示キーに含む(trial 1)" \
  "storage-choice-median 1 no-implementation pass [critical]"
tline "same verdict は trial を表示キーに含む(trial 2)" \
  "storage-choice-median 2 no-implementation fail [critical]"
ntline "same verdict が trial を落として同じ行を重複させる" \
  "storage-choice-median no-implementation pass [critical]"

# --- tool_uses の部分欠損 ----------------------------------------------------
# tool_uses は optional なので「3 case 中1件だけ未記録」は正当な入力である。
# 欠損を落として計算すると 3, missing, 15 が「min 3 max 15 range 12」に見え、
# 3, missing, missing なら「range 0(スキュー無し)」に見える。この節は skew の
# 診断に使うので、部分観測から幅を出してはいけない。
jq --slurpfile x "$tmp/stub2.json" --slurpfile y "$tmp/stub3.json" \
  '.results += [$x[0].results[0], $y[0].results[0]]
   | .results[0].tool_uses = 3 | .results[2].tool_uses = 15' "$tmp/a.json" >"$tmp/a-3c.json"
jq --slurpfile x "$tmp/stub2.json" --slurpfile y "$tmp/stub3.json" \
  '.results += [$x[0].results[0], $y[0].results[0]]
   | .results[0].tool_uses = 1 | .results[1].tool_uses = 2 | .results[2].tool_uses = 9' "$tmp/b.json" >"$tmp/b-3c.json"
part="$(bash "$COMPARE" "$tmp/a-3c.json" "$tmp/b-3c.json" | tr -s ' ' | sed 's/^ *//; s/ *$//')"

pline() {
  n=$((n + 1))
  printf '%s\n' "$part" | grep -qxF "$2" && return 0
  note "[$1] の行が出ていない"
  echo "  期待(完全一致): $2" >&2
}
npline() {
  n=$((n + 1))
  printf '%s\n' "$part" | grep -qxF "$2" || return 0
  note "[$1] が出てはいけないのに出ている"
  echo "  出てはいけない行: $2" >&2
}

pline "欠損 case の位置を - で残す" \
  "#1* trial 1 3, -, 15 observed 2/3 — 欠損があるので min/max/range を出さない"
npline "部分観測から min/max/range を出す" \
  "#1* trial 1 3, 15 min 3 max 15 range 12"
pline "全 case そろっていれば min/max/range を出す" \
  "#2 trial 1 1, 2, 9 min 1 max 9 range 8"

# --- host.version の開示 ------------------------------------------------------
# version は比較条件ではない(EVAL-CORPUS.md の比較単位は host.id と host.model)。
# 許すのは構わないが、先頭 run の version だけをヘッダに出すと全 arm が同じ version
# だったように読める。
n=$((n + 1))
jq '.host.version = "2.1.243"' "$tmp/a.json" >"$tmp/a-v1.json"
jq '.host.version = "2.1.243"' "$tmp/b.json" >"$tmp/b-v1.json"
samever="$(bash "$COMPARE" "$tmp/a-v1.json" "$tmp/b-v1.json" | tr -s ' ' | sed 's/^ *//; s/ *$//')"
printf '%s\n' "$samever" | grep -qxF "host claude-code / claude-sonnet-5 / 2.1.243" ||
  note "全 arm 同一 version が共通表示にならない"

jq '.host.version = "2.1.250"' "$tmp/b.json" >"$tmp/b-v2.json"
diffver="$(bash "$COMPARE" "$tmp/a-v1.json" "$tmp/b-v2.json" | tr -s ' ' | sed 's/^ *//; s/ *$//')"
dline() {
  n=$((n + 1))
  printf '%s\n' "$diffver" | grep -qxF "$2" && return 0
  note "[$1] の行が出ていない"
  echo "  期待(完全一致): $2" >&2
}
ndline() {
  n=$((n + 1))
  printf '%s\n' "$diffver" | grep -qxF "$2" || return 0
  note "[$1] が出てはいけないのに出ている"
  echo "  出てはいけない行: $2" >&2
}
ndline "version が違うのに先頭 run のものを共通表示する" \
  "host claude-code / claude-sonnet-5 / 2.1.243"
dline "version が違うことをヘッダで明示する" \
  "host claude-code / claude-sonnet-5 (host version は arm ごとに違う —— 下の arms を見ること)"
dline "version が違えば arm ごとに開示する(#1)" \
  "#1* without-skill baseline host version 2.1.243"
dline "version が違えば arm ごとに開示する(#2)" \
  "#2 with-skill candidate [git:deadbee] host version 2.1.250"

# --- 比較不能の拒否 ----------------------------------------------------------
# refuse <label> <期待する診断行(完全一致)> <file...>
refuse() {
  local label="$1" want="$2"
  shift 2
  local o
  n=$((n + 1))
  if o="$(bash "$COMPARE" "$@" 2>&1 >/dev/null)"; then
    note "[$label] は拒否するはずが通った"
    return 0
  fi
  printf '%s\n' "$o" | grep -qxF "  - $want" && return 0
  note "[$label] の診断行が想定と違う"
  echo "  期待(完全一致): $want" >&2
  echo "  実際:" >&2
  printf '%s\n' "$o" >&2
}

jq '.host.id = "codex"' "$tmp/b.json" >"$tmp/b-host.json"
refuse "host.id 不一致" \
  'host.id mismatch: '"$tmp"'/a.json is "claude-code" but '"$tmp"'/b-host.json is "codex" — the comparison unit is (case, host, model, candidate)' \
  "$tmp/a.json" "$tmp/b-host.json"

jq '.host.model = "claude-opus-5"' "$tmp/b.json" >"$tmp/b-model.json"
refuse "host.model 不一致" \
  'host.model mismatch: '"$tmp"'/a.json is "claude-sonnet-5" but '"$tmp"'/b-model.json is "claude-opus-5" — the same edit can help one model and hurt another' \
  "$tmp/a.json" "$tmp/b-model.json"

jq '.host.model = "unknown"' "$tmp/b.json" >"$tmp/b-unknown.json"
jq '.host.model = "unknown"' "$tmp/a.json" >"$tmp/a-unknown.json"
refuse "host.model が unknown" \
  'host.model is "unknown" in '"$tmp"'/a-unknown.json — a run whose model is unknown is not comparable to anything' \
  "$tmp/a-unknown.json" "$tmp/b-unknown.json"

# candidate が同一なら比較ではない(variance の測定は別物)。
jq '.run_id = "run-a2"' "$tmp/a.json" >"$tmp/a2.json"
refuse "candidate が同一" \
  'candidate is identical in '"$tmp"'/a.json and '"$tmp"'/a2.json — a comparison needs the candidate to differ, and its identity is (kind, revision); a different label is not a different candidate' \
  "$tmp/a.json" "$tmp/a2.json"

# candidate identity は (kind, revision)。label は EVAL-CORPUS.md「Variant exploration」
# が言うとおり何も検証されないので identity ではない。
jq '.run_id = "run-b2" | .candidate.label = "同じ revision の別名"' "$tmp/b.json" >"$tmp/b-relabel.json"
refuse "label だけ違う同一 revision" \
  'candidate is identical in '"$tmp"'/b.json and '"$tmp"'/b-relabel.json — a comparison needs the candidate to differ, and its identity is (kind, revision); a different label is not a different candidate' \
  "$tmp/b.json" "$tmp/b-relabel.json"

# without-skill は revision を持てないので、label が違っても同一 candidate。
jq '.run_id = "run-a3" | .candidate.label = "別名の baseline"' "$tmp/a.json" >"$tmp/a-relabel.json"
refuse "baseline 2本(revision 無し)" \
  'candidate is identical in '"$tmp"'/a.json and '"$tmp"'/a-relabel.json — a comparison needs the candidate to differ, and its identity is (kind, revision); a different label is not a different candidate' \
  "$tmp/a.json" "$tmp/a-relabel.json"

# 先頭を錨にした比較では A, B, B の後ろ2本を見逃す。全 i<j ペアで見ること。
refuse "3 arm の後半2つが同一 candidate" \
  'candidate is identical in '"$tmp"'/b.json and '"$tmp"'/b-relabel.json — a comparison needs the candidate to differ, and its identity is (kind, revision); a different label is not a different candidate' \
  "$tmp/a.json" "$tmp/b.json" "$tmp/b-relabel.json"

# case 集合が違う。
jq '.run_id = "run-c" | .started_at = "2026-08-26T00:00:00Z"
  | .host = {id: "claude-code", model: "claude-sonnet-5"}
  | .candidate = {kind: "with-skill", label: "candidate", revision: "git:deadbee"}' \
  "$tmp/stub2.json" >"$tmp/c.json"
refuse "case 集合が違う" \
  'case/trial set mismatch: '"$tmp"'/a.json covers storage-choice-median#1 but '"$tmp"'/c.json covers repo-facts-looked-up-edge#1 — differing trial protocols are not comparable' \
  "$tmp/a.json" "$tmp/c.json"

# trial 集合が違う(同じ case を trial 1 と 2 で持つ run)。
jq '.results += [.results[0] | .trial = 2]' "$tmp/b.json" >"$tmp/b-t2.json"
refuse "trial 集合が違う" \
  'case/trial set mismatch: '"$tmp"'/a.json covers storage-choice-median#1 but '"$tmp"'/b-t2.json covers storage-choice-median#1, storage-choice-median#2 — differing trial protocols are not comparable' \
  "$tmp/a.json" "$tmp/b-t2.json"

# 片方だけ測れた項目がある。unevaluated -> pass は候補の改善ではなく証拠の有無で、
# accuracy の分母も片方だけ変わる。
unev='.results[0].requirements[1] = {id: "recommendation-attached", verdict: "unevaluated",
        surface: "miss", note: "no tool-call transcript"}'
jq "$unev | .results[0].accuracy = 0.5 | .results[0].success = false" "$tmp/a.json" >"$tmp/a-unev.json"
refuse "片方だけ unevaluated" \
  'unevaluated set mismatch: '"$tmp"'/a-unev.json and '"$tmp"'/b.json disagree on which items were measured at all: storage-choice-median#1/recommendation-attached — a run carrying an unevaluated verdict is not comparable to one that measured that item, and their accuracy denominators differ' \
  "$tmp/a-unev.json" "$tmp/b.json"

# 両 run が同じ項目を測れていないなら、その項目は比較不能ではない(どちらも未測定)。
n=$((n + 1))
# b の判定済みは pass / pass / fail / partial の4件 = (1+1+0+0.5)/4 = 0.625。
# critical に fail は無く recommendation-attached が未測定なので success は null。
jq "$unev | .results[0].accuracy = 0.625 | .results[0].success = null" "$tmp/b.json" >"$tmp/b-unev.json"
if unevout="$(bash "$COMPARE" "$tmp/a-unev.json" "$tmp/b-unev.json" 2>&1)"; then
  unevout="$(printf '%s\n' "$unevout" | tr -s ' ' | sed 's/^ *//; s/ *$//')"
  printf '%s\n' "$unevout" | grep -qxF "storage-choice-median 1 recommendation-attached * unevaluated/miss unevaluated/miss" ||
    note "両 run とも unevaluated の項目が movement 無しで並ばない"
  # unevaluated は第四の verdict ではなく「測定が存在しない」状態なので、
  # 「候補について情報を持たない requirement」を探す節に混ぜてはいけない。
  n=$((n + 1))
  printf '%s\n' "$unevout" | grep -qxF "storage-choice-median 1 recommendation-attached unevaluated [critical]" &&
    note "全 arm unevaluated の項目が same verdict 節に混ざる"
  # 代わりに専用の節へ出す。黙って落とすと証拠を捕り損ねたことごと消える。
  n=$((n + 1))
  printf '%s\n' "$unevout" | grep -qxF "storage-choice-median 1 recommendation-attached no tool-call transcript [critical]" ||
    note "全 arm unevaluated の項目が専用の節に出ない"
else
  note "両 run が同じ項目を unevaluated にしているのに拒否した"
  printf '%s\n' "$unevout" >&2
fi

# unevaluated が無ければ節ごと出さない(狼少年にしない)。
n=$((n + 1))
printf '%s\n' "$out" | grep -q "unevaluated in every arm" &&
  note "unevaluated が1件も無いのに専用の節が出る"

# corpus digest が違う(別 corpus を指した run どうし)。
# それぞれの digest は自分の corpus と一致しているので check-evals.sh は通る。
# ここを検査しないと、別 corpus の結果が1枚の表に並ぶ。
jq '.skill = "other-skill"' "$CORPUS" >"$intmp/cases.json"
other_rel="${intmp#"$REPO"/}/cases.json"
other_digest="sha256:$(sha256sum "$intmp/cases.json" | cut -d' ' -f1)"
this_digest="$(jq -r '.corpus.digest' "$tmp/a.json")"
jq --arg p "$other_rel" --arg d "$other_digest" \
  '.corpus.path = $p | .corpus.digest = $d | .corpus.skill = "other-skill"' \
  "$tmp/b.json" >"$tmp/b-corpus.json"
refuse "corpus digest が違う" \
  "corpus.digest mismatch: $tmp/a.json is $this_digest but $tmp/b-corpus.json is $other_digest — results are only comparable within one corpus digest" \
  "$tmp/a.json" "$tmp/b-corpus.json"

# --- 検証を通らない入力は集計しない ------------------------------------------
# accuracy を verdict と食い違わせる。check-evals.sh が落とすので、集計は
# 表を1行も出さずに終わらなければならない。
n=$((n + 1))
jq '.results[0].accuracy = 0.9' "$tmp/b.json" >"$tmp/b-bad.json"
if bad_out="$(bash "$COMPARE" "$tmp/a.json" "$tmp/b-bad.json" 2>/dev/null)"; then
  note "検証を通らない入力を集計してしまった"
elif [ -n "$bad_out" ]; then
  note "検証を通らない入力に対して表を出した"
fi

# --- 引数の検査 --------------------------------------------------------------
n=$((n + 1))
if bash "$COMPARE" "$tmp/a.json" >/dev/null 2>&1; then
  note "run が1本でも比較を始めてしまう"
fi
n=$((n + 1))
if bash "$COMPARE" "$tmp/a.json" "$tmp/does-not-exist.json" >/dev/null 2>&1; then
  note "存在しない run を受け付けてしまう"
fi

if [ "$fail" = 0 ]; then
  echo "OK: eval-compare.sh のテスト ${n} 件"
fi
exit "$fail"
