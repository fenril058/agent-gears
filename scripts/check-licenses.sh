#!/usr/bin/env bash
#
# check-licenses.sh — 外部由来 skill の帰属表示ファイルが正しい場所にあるかを検証する。
#
# 由来は tree から導出できない(どの skill がどの upstream 由来かはファイル配置に
# 現れない)ので、PROVENANCE.json が唯一の宣言元になる。ここでは宣言から
# 「あるべき LICENSE / NOTICE の集合」を組み立て、plugins/ 以下の実集合と突き合わせる。
#
# plugin 単位の帰属表示は単一 plugin の LICENSE / NOTICE に集約し、skill 単位の
# 帰属表示は各 skill に残す。この配置からの欠落と stale なファイルを同じ差分で捕まえる。
#
# 配置だけでは足りない。scope=plugin では複数の source が同じファイルに写像されるので、
# ファイルさえ残っていれば特定 source の許諾文や出典表示が丸ごと消えても通ってしまう(#91)。
# そこで source ごとに marker(集約先に literal で現れる識別子)の残存も見る。marker の
# 正本は PROVENANCE.json ただ1つで、帰属表示ファイル側がそれに従う。
#
# 検査が保証する範囲は狭い。marker が言えるのは「その識別子が集約先に残っている」まで
# で、許諾文の本文が正しいことまでは言えない(見出しだけ残して本文を消せば通る)。
# scope=skill も、source とファイルが 1 対 1 なのでファイルの欠落は配置の検査に現れるが、
# 中身は見ていない。本文の妥当性は人間の review の担当で、ここは回帰検出だけを受け持つ。
#
# 壊れた宣言に対しては fail closed にする。record を組み立てられない、field がずれる、
# marker が一意に効かない、といった場合は「検査できなかった」ではなく失格として扱う。
#
# 必要: jq。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
manifest="PROVENANCE.json"
fail=0

if [ ! -f "$manifest" ]; then
  echo "NG: $manifest が無い" >&2
  exit 1
fi

expected="$(mktemp)"
seen="$(mktemp)"
rec_skill="$(mktemp)"
rec_src="$(mktemp)"
trap 'rm -f "$expected" "$seen" "$rec_skill" "$rec_src"' EXIT

# jq -> bash の record は1行1件、フィールドの区切りは US (0x1f)。
#
# タブ区切り(@tsv + IFS=$'\t')は使えない。タブは IFS 空白なので read が連続する
# 空フィールドを1個に畳み、宣言漏れのフィールドがあると後続の値がずれて別の意味で
# 読まれる(それでいて何も報告されない)。US は IFS 空白ではないので空フィールドが
# そのまま残る。
#
# 区切り自体が値に入るとやはりずれるので、US を含む制御文字と文字列でない値は jq 側で
# error にして checker ごと落とす。黙って field がずれるより落ちた方が安全。
# shellcheck disable=SC2016  # $who / $name は jq の引数。shell に展開させない。
jq_field_guard='
def field($who; $name):
  if . == null then ""
  elif type != "string" then
    error("PROVENANCE.json: \($who) の \($name) が文字列でない")
  elif test("[[:cntrl:]]") then
    error("PROVENANCE.json: \($who) の \($name) に制御文字が含まれる(record の区切りが壊れる)")
  else . end;
'

# jq の出力は process substitution ではなくファイルへ落とす。process substitution だと
# jq の終了 status がどこにも現れず、jq が途中で abort しても while ループが0行読んで
# 正常終了し、検査が丸ごと no-op のまま OK が出る(fail open)。
gen_records() {
  local out="$1" filter="$2"
  if ! jq -r "$jq_field_guard $filter" "$manifest" >"$out"; then
    echo "NG: PROVENANCE.json から record を組み立てられない(上の jq のエラーを参照)" >&2
    exit 1
  fi
}

# shellcheck disable=SC2016  # $s / $id などは jq の変数。shell に展開させない。
gen_records "$rec_skill" '
  .sources[] as $s
  | ($s.id | field("source"; "id")) as $id
  | ($s.scope | field($id; "scope")) as $scope
  | ($s.file | field($id; "file")) as $file
  | $s.skills[]
  | field($id; "skills[]") as $skill
  | [$id, $scope, $file, $skill]
  | join("\u001f")'

# shellcheck disable=SC2016  # $s / $id などは jq の変数。shell に展開させない。
gen_records "$rec_src" '
  .sources[] as $s
  | ($s.id | field("source"; "id")) as $id
  | [$id, ($s.marker | field($id; "marker")), ($s.scope | field($id; "scope"))]
  | join("\u001f")'

# skill 名 -> それを含む plugin 名。skill 名は配布先のベース名でもあり一意でなければならない。
declare -A skill_plugin=()
dup_skills=""
for d in plugins/*/skills/*/; do
  [ -d "$d" ] || continue
  s="$(basename "$d")"
  p="$(basename "$(dirname "$(dirname "$d")")")"
  if [ -n "${skill_plugin[$s]:-}" ]; then
    dup_skills+="  $s (${skill_plugin[$s]}, $p)"$'\n'
  fi
  skill_plugin[$s]="$p"
done
if [ -n "$dup_skills" ]; then
  echo "NG: skill 名が重複している(配布先が平坦なので一意でなければならない)" >&2
  printf '%s' "$dup_skills" >&2
  fail=1
fi

# 宣言から期待集合を組み立てる。併せて、宣言された skill の実在と重複登録も見る。
#
# source id -> その source の集約先 path(改行区切り)。marker の検査先に使う。
declare -A agg_targets=()

while IFS=$'\x1f' read -r id scope file skill; do
  if [ -z "$skill" ]; then
    echo "NG: PROVENANCE.json の $id の skills に空の要素がある" >&2
    fail=1
    continue
  fi
  if [ -z "$file" ]; then
    echo "NG: PROVENANCE.json の $id に file が無い(帰属表示ファイル名が決まらない)" >&2
    fail=1
    continue
  fi
  if grep -qxF "$skill" "$seen"; then
    echo "NG: $skill が PROVENANCE.json の複数の source に登録されている(直近: $id)" >&2
    fail=1
  fi
  echo "$skill" >>"$seen"

  p="${skill_plugin[$skill]:-}"
  if [ -z "$p" ]; then
    echo "NG: PROVENANCE.json の $id が挙げる skill '$skill' が plugins/ に無い" >&2
    fail=1
    continue
  fi

  # scope の妥当性は source 単位で見る(skills が空の source も取りこぼさないため)。
  # ここでは既知の scope の path だけを組み立てる。
  case "$scope" in
  plugin)
    echo "plugins/$p/$file" >>"$expected"
    # id が空の source は source 単位の検査が失格にする。ここでは subscript を壊さない。
    if [ -n "$id" ]; then
      agg_targets[$id]+="plugins/$p/$file"$'\n'
    fi
    ;;
  skill) echo "plugins/$p/skills/$skill/$file" >>"$expected" ;;
  esac
done <"$rec_skill"

# 実集合: plugins/ 以下の LICENSE / NOTICE すべて。宣言で説明できないものは失格。
actual="$(find plugins -type f \( -name LICENSE -o -name NOTICE \) | sort -u)"
want="$(sort -u "$expected")"

if [ "$want" != "$actual" ]; then
  echo "NG: 帰属表示ファイルが PROVENANCE.json の宣言と不一致" >&2
  echo "     '<' = 宣言されているのに実ファイルが無い(移動先への複製漏れ)" >&2
  echo "     '>' = 実ファイルがあるのに宣言が無い(未登録の取り込み、または移動後の残骸)" >&2
  diff <(printf '%s\n' "$want") <(printf '%s\n' "$actual") >&2 || true
  fail=1
fi

# source ごとの検査。id と marker が識別子として成立しているかを見てから、marker の残存を
# 見る。検査先は、リポジトリ直下の NOTICE(法的な帰属表示の一覧)と、scope=plugin なら
# 集約先の LICENSE / NOTICE。
declare -A marker_owner=()
declare -A id_seen=()
while IFS=$'\x1f' read -r id marker scope; do
  if [ -z "$id" ]; then
    echo "NG: PROVENANCE.json に id の無い source がある" >&2
    fail=1
    continue
  fi
  if [ -n "${id_seen[$id]:-}" ]; then
    echo "NG: source id '$id' が PROVENANCE.json で重複している(集約先の対応づけが壊れる)" >&2
    fail=1
  fi
  id_seen[$id]=1

  case "$scope" in
  plugin | skill) ;;
  *)
    echo "NG: $id の scope が不正: '$scope'(plugin か skill)" >&2
    fail=1
    ;;
  esac

  # 空文字と空白のみは marker にできない(どのファイルにも当たり、検査が無力化する)。
  if [ -z "${marker//[[:space:]]/}" ]; then
    echo "NG: PROVENANCE.json の $id に使える marker が無い(未宣言、または空白のみ)" >&2
    fail=1
    continue
  fi

  # 完全一致の重複だけでなく、包含関係も失格。残存確認は grep の部分一致なので、長い側の
  # literal が短い側の marker を含んでいると、短い側の帰属表示がゼロでも grep が当たる。
  for other in "${!marker_owner[@]}"; do
    if [ "$marker" = "$other" ]; then
      echo "NG: marker '$marker' が ${marker_owner[$other]} と $id で重複している(片方の欠落をもう片方が隠す)" >&2
      fail=1
    elif [[ $marker == *"$other"* || $other == *"$marker"* ]]; then
      echo "NG: marker '$marker'($id)と '$other'(${marker_owner[$other]})が包含関係にある(短い側の欠落を長い側が隠す)" >&2
      fail=1
    fi
  done
  marker_owner[$marker]="$id"

  if ! grep -qF -- "$marker" NOTICE; then
    echo "NG: 直下の NOTICE に $id の marker '$marker' が無い" >&2
    fail=1
  fi

  [ "$scope" = "plugin" ] || continue

  targets="$(printf '%s' "${agg_targets[$id]:-}" | sort -u)"
  if [ -z "$targets" ]; then
    echo "NG: $id(scope: plugin)の集約先が決まらない(skills が空か、plugins/ に無い)" >&2
    fail=1
    continue
  fi
  while IFS= read -r target; do
    # ファイル自体の欠落は配置の検査が報告済み。ここでは中身だけを見る。
    [ -f "$target" ] || continue
    if ! grep -qF -- "$marker" "$target"; then
      echo "NG: $target に $id の marker '$marker' が無い(集約先から帰属表示が落ちている)" >&2
      fail=1
    fi
  done <<<"$targets"
done <"$rec_src"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

n_src="$(jq '.sources | length' "$manifest")"
n_skill="$(wc -l <"$seen" | tr -d ' ')"
n_file="$(printf '%s\n' "$want" | wc -l | tr -d ' ')"
echo "OK: 外部由来 ${n_skill} skill / ${n_src} 出所の帰属表示 ${n_file} ファイルが宣言どおり配置され、各出所の marker も集約先に残っている"
