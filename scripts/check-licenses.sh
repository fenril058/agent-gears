#!/usr/bin/env bash
#
# check-licenses.sh — 外部由来 skill の帰属表示ファイルが正しい場所にあるかを検証する。
#
# 由来は tree から導出できない(どの skill がどの upstream 由来かはファイル配置に
# 現れない)ので、PROVENANCE.json が唯一の宣言元になる。ここでは宣言から
# 「あるべき LICENSE / NOTICE の集合」を組み立て、plugins/ 以下の実集合と突き合わせる。
#
# これが要るのは、shokai/agent-skills 由来の skill が複数 plugin に分散しており、
# plugin 単位の LICENSE を移動先に複製し忘れても他のどの CI も気づかないため。
# 逆向き(最後の1件を移した後に残る stale な LICENSE)も同じ差分で捕まる。
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
  plugin) echo "plugins/$p/$file" >>"$expected" ;;
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

# NOTICE(リポジトリ直下)は法的な帰属表示の一覧。宣言した出所が落ちていないかだけ見る。
for name in $(jq -r '.sources[].name' "$manifest"); do
  if ! grep -qF "$name" NOTICE; then
    echo "NG: 直下の NOTICE に '$name' の記載が無い" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

n_src="$(jq '.sources | length' "$manifest")"
n_skill="$(wc -l <"$seen" | tr -d ' ')"
n_file="$(printf '%s\n' "$want" | wc -l | tr -d ' ')"
echo "OK: 外部由来 ${n_skill} skill / ${n_src} 出所の帰属表示 ${n_file} ファイルが宣言どおり配置されている"
