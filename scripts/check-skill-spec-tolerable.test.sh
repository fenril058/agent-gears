#!/usr/bin/env bash
#
# check-skill-spec-tolerable.test.sh — scripts/lib/tolerable.sh の単体テスト。
#
# skills-ref の実際の出力サンプル(nix run .#skills-ref -- validate で採取した文言)を
# 固定入力として tolerable() に流し、期待通りの合否になるかを検証する。skills-ref
# 自体は呼ばない(nix 不要、CI の shellcheck job のように素の bash だけで動く)。
#
# skills-ref のエラー文言が変わると tolerable() は無言で壊れる(全許容 or 全拒否に
# 倒れる)ため、その回帰を検出するのがこのテストの役割。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/tolerable.sh
source "$REPO/scripts/lib/tolerable.sh"

fail=0
count=0

# assert_tolerable <説明> <期待:pass|fail> <skills-ref 出力>
assert_tolerable() {
  local desc="$1" want="$2" out="$3"
  count=$((count + 1))
  local got
  if tolerable "$out"; then got=pass; else got=fail; fi
  if [ "$got" != "$want" ]; then
    echo "NG: $desc — want=$want got=$got" >&2
    echo "  input:" >&2
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    fail=1
  fi
}

# 単一の Claude 拡張フィールドのみ → 許容。
assert_tolerable "拡張フィールド1つ(model)のみ" pass \
  "Validation failed for foo:
  - Unexpected fields in frontmatter: model. Only ['allowed-tools', 'compatibility', 'description', 'license', 'metadata', 'name'] are allowed."

# 複数の Claude 拡張フィールドが全て許容リストに含まれる → 許容。
assert_tolerable "拡張フィールド2つ(bad-field, model)で両方拡張リストに無い" fail \
  "Validation failed for foo:
  - Unexpected fields in frontmatter: bad-field, model. Only ['allowed-tools', 'compatibility', 'description', 'license', 'metadata', 'name'] are allowed."

# 拡張リストに含まれるフィールドが複数 → 許容。
assert_tolerable "拡張フィールド2つ(argument-hint, model)は両方拡張リストにある" pass \
  "Validation failed for foo:
  - Unexpected fields in frontmatter: argument-hint, model. Only ['allowed-tools', 'compatibility', 'description', 'license', 'metadata', 'name'] are allowed."

# Unexpected fields 以外のエラーが混じる → 拒否。
assert_tolerable "拡張フィールド + 名前違反が同時発生" fail \
  "Validation failed for foo:
  - Unexpected fields in frontmatter: model. Only ['allowed-tools', 'compatibility', 'description', 'license', 'metadata', 'name'] are allowed.
  - Skill name 'Bad Name!' must be lowercase
  - Skill name 'Bad Name!' contains invalid characters. Only letters, digits, and hyphens are allowed.
  - Directory name 'foo' must match skill name 'Bad Name!'"

# Unexpected fields エラーではない単独エラー → 拒否。
assert_tolerable "name 違反のみ(Unexpected fields ではない)" fail \
  "Validation failed for foo:
  - Skill name 'Bad Name!' must be lowercase"

# エラーなし(空出力)→ 拒否(そもそも tolerable() は失格時のみ呼ばれる想定だが、
# 誤って呼ばれても許容側に倒れないことを確認する)。
assert_tolerable "エラー行が無い" fail \
  "Validation failed for foo:"

if [ "$fail" = 0 ]; then
  echo "OK: $count 件の tolerable() テストに合格"
fi
exit "$fail"
