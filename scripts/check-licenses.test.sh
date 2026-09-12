#!/usr/bin/env bash
#
# check-licenses.test.sh — 集約した帰属表示を source ごとに検証することの回帰テスト(#91)。
#
# scope=plugin の source は複数が同じ LICENSE / NOTICE に写像されるため、配置の検査
# (path の存在)は特定 source の許諾文や出典表示が丸ごと消えても通ってしまう。ここでは
# 実際の PROVENANCE.json と帰属表示ファイルを一時 tree に写し、source 単位の欠落を作って
# check-licenses.sh が落ちること、しかも欠けた source の marker を挙げて落ちることを見る。
#
# 併せて、空白を含む marker が1件として扱われること(単語分割で部分一致に緩まないこと)も
# 見る。緩んだ実装では k16shikano gist が k16shikano と gist の2件になり、どちらも別の
# 文脈で見つかるので検査が通ってしまう。
#
# fixture は skill ディレクトリの骨組み(空ディレクトリ)と、実際の LICENSE / NOTICE /
# PROVENANCE.json / 直下 NOTICE。skill の中身は検査対象でないので写さない。
#
# 必要: jq(check-licenses.sh と同じ)。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0
count=0

fixture="$(mktemp -d)"
out="$(mktemp)"
trap 'rm -rf "$fixture" "$out"' EXIT INT TERM

# PROVENANCE.json の marker を id で引く。テスト側に literal を二重に書かないため。
marker_of() {
  jq -r --arg id "$1" '.sources[] | select(.id == $id) | .marker' "$REPO/PROVENANCE.json"
}

build_fixture() {
  rm -rf "${fixture:?}"
  mkdir -p "$fixture/scripts"
  cp "$REPO/scripts/check-licenses.sh" "$fixture/scripts/check-licenses.sh"
  cp "$REPO/PROVENANCE.json" "$REPO/NOTICE" "$fixture/"
  local d f
  while IFS= read -r d; do
    mkdir -p "$fixture/$d"
  done < <(cd "$REPO" && find plugins -mindepth 3 -maxdepth 3 -type d -path '*/skills/*')
  while IFS= read -r f; do
    mkdir -p "$fixture/$(dirname "$f")"
    cp "$REPO/$f" "$fixture/$f"
  done < <(cd "$REPO" && find plugins -type f \( -name LICENSE -o -name NOTICE \))
}

# fixture の PROVENANCE.json を jq で書き換える。
edit_manifest() {
  jq "$1" "$fixture/PROVENANCE.json" >"$fixture/PROVENANCE.json.new"
  mv "$fixture/PROVENANCE.json.new" "$fixture/PROVENANCE.json"
}

# assert_check <説明> <期待:pass|fail> [出力に含まれるべき文字列]
#
# 落ちること自体は弱い主張(別の理由でも落ちる)なので、失敗を期待するケースでは
# 出力に現れるべき marker まで見る。
assert_check() {
  local desc="$1" want="$2" needle="${3:-}" got=pass
  count=$((count + 1))
  bash "$fixture/scripts/check-licenses.sh" >"$out" 2>&1 || got=fail
  if [ "$got" != "$want" ]; then
    echo "NG: $desc — want=$want got=$got" >&2
    sed 's/^/    /' "$out" >&2
    fail=1
    return
  fi
  if [ -n "$needle" ] && ! grep -qF -- "$needle" "$out"; then
    echo "NG: $desc — 出力に '$needle' が無い(別の理由で落ちている)" >&2
    sed 's/^/    /' "$out" >&2
    fail=1
  fi
}

# 前提が崩れるとテストが無言で骨抜きになるので、fixture の作り直しごとに明示する。
assert_precondition() {
  local desc="$1"
  shift
  count=$((count + 1))
  if ! "$@"; then
    echo "NG: テストの前提が壊れている — $desc" >&2
    fail=1
  fi
}

# 0. 現行 tree がそのまま通る。
count=$((count + 1))
if ! bash "$REPO/scripts/check-licenses.sh" >"$out" 2>&1; then
  echo "NG: 現行 tree で check-licenses.sh が落ちる" >&2
  sed 's/^/    /' "$out" >&2
  fail=1
fi

# 1. fixture そのものも通る(以降の失敗が「fixture が壊れている」ではないことの土台)。
build_fixture
assert_check "無傷の fixture" pass

# 2. shokai の許諾文を集約 LICENSE から削除 → 失格。
#    集約 LICENSE は yasunori0418 の見出しを境に2節あり、前半が shokai の MIT 許諾文。
#    ファイル自体は残るので、配置の検査だけでは気づけない。
build_fixture
awk -v m="$(marker_of yasunori0418)" 'index($0, m) { keep = 1 } keep' \
  "$REPO/plugins/agent-gears/LICENSE" >"$fixture/plugins/agent-gears/LICENSE"
assert_precondition "shokai の節を落としても集約 LICENSE は残る" \
  test -s "$fixture/plugins/agent-gears/LICENSE"
assert_check "集約 LICENSE から shokai の許諾文が消えている" fail \
  "marker '$(marker_of shokai)'"

# 3. yasunori0418 の許諾文を集約 LICENSE から削除 → 失格(issue #91 の実測ケース)。
build_fixture
awk -v m="$(marker_of yasunori0418)" 'index($0, m) { stop = 1 } !stop' \
  "$REPO/plugins/agent-gears/LICENSE" >"$fixture/plugins/agent-gears/LICENSE"
assert_precondition "yasunori0418 の節を落としても shokai の許諾文は残る" \
  grep -qF -- "$(marker_of shokai)" "$fixture/plugins/agent-gears/LICENSE"
assert_check "集約 LICENSE から yasunori0418 の許諾文が消えている" fail \
  "marker '$(marker_of yasunori0418)'"

# 4. k16shikano の出典表示を集約 NOTICE から削除 → 失格。
build_fixture
grep -vF -- "$(marker_of k16shikano)" "$REPO/plugins/agent-gears/NOTICE" \
  >"$fixture/plugins/agent-gears/NOTICE"
assert_precondition "出典表示を落としても集約 NOTICE は残る" \
  test -s "$fixture/plugins/agent-gears/NOTICE"
assert_check "集約 NOTICE から k16shikano の出典表示が消えている" fail \
  "marker '$(marker_of k16shikano)'"

# 5. 直下 NOTICE から出所の記載を削除 → 失格。scope=skill の source も対象であること。
build_fixture
grep -vF -- "$(marker_of mizchi)" "$REPO/NOTICE" >"$fixture/NOTICE"
assert_check "直下 NOTICE から mizchi の記載が消えている" fail \
  "marker '$(marker_of mizchi)'"

# 6. 空白を含む marker を1件として扱う。
#    "k16shikano gist" はどの帰属表示ファイルにも literal では現れないが、k16shikano と
#    gist は別々に現れる。単語分割する実装はこれを通してしまう。
build_fixture
ws_marker="k16shikano gist"
edit_manifest "(.sources[] | select(.id == \"k16shikano\") | .marker) = \"$ws_marker\""
for word in k16shikano gist; do
  for f in "$fixture/NOTICE" "$fixture/plugins/agent-gears/NOTICE"; do
    assert_precondition "'$word' 単体は $(basename "$(dirname "$f")")/NOTICE に現れる" \
      grep -qF -- "$word" "$f"
  done
done
count=$((count + 1))
if grep -qF -- "$ws_marker" "$fixture/NOTICE"; then
  echo "NG: テストの前提が壊れている — '$ws_marker' が直下 NOTICE に literal で現れる" >&2
  fail=1
fi
assert_check "空白を含む marker が部分一致で通らない" fail "marker '$ws_marker'"

# 7. 空白を含む marker が literal で揃っていれば通る(6 の裏。空白そのものを嫌う実装や、
#    marker を壊して読む実装だとここが落ちる)。
build_fixture
ws_marker="k16shikano の gist"
edit_manifest "(.sources[] | select(.id == \"k16shikano\") | .marker) = \"$ws_marker\""
assert_precondition "'$ws_marker' は集約 NOTICE に literal で現れる" \
  grep -qF -- "$ws_marker" "$fixture/plugins/agent-gears/NOTICE"
printf '\n出典: %s\n' "$ws_marker" >>"$fixture/NOTICE"
assert_check "空白を含む marker が literal で揃っている" pass

# 8. marker の宣言漏れ → 失格(検査できない source を黙って見逃さない)。
build_fixture
edit_manifest 'del(.sources[] | select(.id == "shokai") | .marker)'
assert_check "shokai の marker が宣言されていない" fail "marker が無い"

# 9. marker の重複 → 失格(片方の欠落をもう片方が隠す)。
build_fixture
edit_manifest "(.sources[] | select(.id == \"mizchi\") | .marker) = \"$(marker_of shokai)\""
assert_check "mizchi と shokai の marker が重複している" fail "重複"

if [ "$fail" = 0 ]; then
  echo "OK: $count 件の帰属表示検査テストに合格"
fi
exit "$fail"
