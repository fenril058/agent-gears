#!/usr/bin/env bash
#
# eval-render.test.sh — eval-render.sh の単体テスト。
#
# 主眼は【v1 の描画が凍結されていること】である。
#
# 既存 measurement の固定条件は「trial 1 で実際に配られた prompt.txt と
# byte-identical か」で照合している(.dev/evals/.../CONDITIONS.txt)。
# renderer の v1 出力が1バイトでも動くと、その照合ができなくなり、過去の
# measurement は再現不能な記録になる。記録済みの run を v2 へ変換しない方針は、
# この再現性に依拠している。
#
# したがって v1 の3経路(実行プロンプト / 判定プロンプト / 結果雛形)を
# 固定値で押さえる。ここが落ちたときに直すべきは、原則としてテストではなく実装。
# v1 の描画を意図的に変えるなら、それは凍結の解除であり、過去の measurement を
# どう扱うかの決定を伴う。
#
# 必要: jq。CI では consistency job(nix shell nixpkgs#jq)から実行する。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

# plugin 名はハードコードしない(skill は plugin 間を移動しうる)。
RENDER="$(find plugins -path '*/skills/*/scripts/eval-render.sh' -print -quit)"
CORPUS="$(find plugins -path '*/skills/grilling/evals/cases.json' -print -quit)"
[ -n "$RENDER" ] || {
  echo "eval-render.sh が見つからない" >&2
  exit 1
}
[ -n "$CORPUS" ] || {
  echo "grilling の corpus が見つからない" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
n=0

CASE=storage-choice-median

# 候補ファイルのパスは実行プロンプトにそのまま載るので、比較の前に置き換える
# (置き換えないと temp ディレクトリ名で digest が毎回変わる)。
digest() { sed "s#$tmp/SKILL.md#<CANDIDATE>#g" | sha256sum | cut -c1-16; }

# frozen <label> <期待する digest> <実際の digest>
frozen() {
  n=$((n + 1))
  [ "$2" = "$3" ] && return 0
  echo "NG: [$1] v1 の描画が変わっている" >&2
  echo "  期待: $2" >&2
  echo "  実際: $3" >&2
  echo "  v1 は凍結されている。既存 measurement の実行プロンプトを再現できなくなるので、" >&2
  echo "  実装を戻すか、凍結解除の判断(過去 measurement の扱い)を先に決めること。" >&2
  fail=1
}

cp "$(dirname "$(dirname "$CORPUS")")/SKILL.md" "$tmp/SKILL.md"

frozen "v1 実行プロンプト(baseline)" e923ddba903c0779 \
  "$(bash "$RENDER" --corpus "$CORPUS" --case "$CASE" --candidate without-skill | digest)"
frozen "v1 実行プロンプト(with)" 6afb3486f8ced493 \
  "$(bash "$RENDER" --corpus "$CORPUS" --case "$CASE" --candidate with-skill \
    --candidate-file "$tmp/SKILL.md" | digest)"
frozen "v1 判定プロンプト" 01419cc3814e6765 \
  "$(bash "$RENDER" --corpus "$CORPUS" --case "$CASE" --part judgment | digest)"
frozen "v1 結果雛形" 14d8d800e191c373 \
  "$(bash "$RENDER" --corpus "$CORPUS" --case "$CASE" --result-stub | digest)"

# legacy alias。runner や過去の手順書が --skill-file を渡すので、同じ結果になること。
n=$((n + 1))
a="$(bash "$RENDER" --corpus "$CORPUS" --case "$CASE" --candidate with-skill --skill-file "$tmp/SKILL.md")"
b="$(bash "$RENDER" --corpus "$CORPUS" --case "$CASE" --candidate with-skill --candidate-file "$tmp/SKILL.md")"
[ "$a" = "$b" ] || {
  echo "NG: --skill-file と --candidate-file の結果が違う" >&2
  fail=1
}

# --- 世代の切り替え -----------------------------------------------------------
jq 'del(.skill) | .schema = "agent-gears/eval-cases@2"
    | .target = {kind: "rule-file", name: "always-on"}' "$CORPUS" >"$tmp/v2.json"

n=$((n + 1))
bash "$RENDER" --corpus "$tmp/v2.json" --case "$CASE" --result-stub |
  jq -e '.schema == "agent-gears/eval-run@2"
         and .corpus.target == {kind: "rule-file", name: "always-on"}
         and (.corpus | has("skill") | not)
         and .candidate.kind == "with-target"' >/dev/null || {
  echo "NG: v2 の結果雛形が v2 の語彙になっていない" >&2
  fail=1
}

# 世代をまたいだ語彙を受け付けない。受け付けると、対象の表し方が run と corpus で
# 食い違ったまま実行プロンプトが出る。
n=$((n + 1))
bash "$RENDER" --corpus "$tmp/v2.json" --case "$CASE" --candidate without-skill >/dev/null 2>&1 && {
  echo "NG: v2 corpus が v1 の candidate kind を受け付けた" >&2
  fail=1
}
n=$((n + 1))
bash "$RENDER" --corpus "$CORPUS" --case "$CASE" --candidate without-target >/dev/null 2>&1 && {
  echo "NG: v1 corpus が v2 の candidate kind を受け付けた" >&2
  fail=1
}

# --- 未知 schema は既定の世代へ落とさない -------------------------------------
# 「@2 以外は v1」と書くと、schema を書き損じた corpus や将来の世代が v1 として
# 黙って描画される。落ちるより悪い。
jq '.schema = "agent-gears/eval-cases@3"' "$CORPUS" >"$tmp/v3.json"
n=$((n + 1))
bash "$RENDER" --corpus "$tmp/v3.json" --case "$CASE" >/dev/null 2>&1 && {
  echo "NG: 未知の corpus schema が描画された" >&2
  fail=1
}
jq 'del(.schema)' "$CORPUS" >"$tmp/nos.json"
n=$((n + 1))
bash "$RENDER" --corpus "$tmp/nos.json" --case "$CASE" >/dev/null 2>&1 && {
  echo "NG: schema の無い corpus が描画された" >&2
  fail=1
}

if [ "$fail" = 0 ]; then
  echo "OK: eval-render.sh のテスト ${n} 件"
fi
exit "$fail"
