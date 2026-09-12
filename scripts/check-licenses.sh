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
# scope=skill は source とファイルが 1 対 1 なので、欠落は配置の検査に現れる。
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
expected="$(mktemp)"
seen="$(mktemp)"
trap 'rm -f "$expected" "$seen"' EXIT

# source id -> その source の集約先 path(改行区切り)。marker の検査先に使う。
declare -A agg_targets=()

while IFS=$'\t' read -r id scope file skill; do
  [ -n "$skill" ] || continue
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

  case "$scope" in
  plugin)
    echo "plugins/$p/$file" >>"$expected"
    agg_targets[$id]+="plugins/$p/$file"$'\n'
    ;;
  skill) echo "plugins/$p/skills/$skill/$file" >>"$expected" ;;
  *)
    echo "NG: $id の scope が不正: '$scope'(plugin か skill)" >&2
    fail=1
    ;;
  esac
done < <(jq -r '.sources[] | . as $s | $s.skills[] | [$s.id, $s.scope, $s.file, .] | @tsv' "$manifest")

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

# source ごとに marker の残存を見る。検査先は、リポジトリ直下の NOTICE(法的な帰属表示の
# 一覧)と、scope=plugin なら集約先の LICENSE / NOTICE。
#
# marker は1フィールドとして読むので、空白を含んでも1件のまま扱う($(jq ...) を for に
# 渡すと単語分割で別々の文字列になり、部分一致でも通ってしまう)。区切りは US (0x1f)。
# タブだと read が IFS 空白として空フィールドを畳み、marker 未宣言のときに後続フィールドが
# ずれて別の文字列を marker と誤認する。改行・タブ入りの marker は jq 側で "" に倒す。
declare -A marker_owner=()
while IFS=$'\x1f' read -r id marker scope; do
  if [ -z "$marker" ]; then
    echo "NG: PROVENANCE.json の $id に使える marker が無い(未宣言、または改行・タブを含む)" >&2
    fail=1
    continue
  fi
  if [ -n "${marker_owner[$marker]:-}" ]; then
    echo "NG: marker '$marker' が ${marker_owner[$marker]} と $id で重複している(片方の欠落をもう片方が隠す)" >&2
    fail=1
  fi
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
done < <(jq -r '
  .sources[]
  | [ .id
    , (.marker | if type == "string" and (test("[\n\t]") | not) then . else "" end)
    , (.scope // "")
    ]
  | join("\u001f")' "$manifest")

if [ "$fail" -ne 0 ]; then
  exit 1
fi

n_src="$(jq '.sources | length' "$manifest")"
n_skill="$(wc -l <"$seen" | tr -d ' ')"
n_file="$(printf '%s\n' "$want" | wc -l | tr -d ' ')"
echo "OK: 外部由来 ${n_skill} skill / ${n_src} 出所の帰属表示 ${n_file} ファイルが宣言どおり配置され、各出所の marker も集約先に残っている"
