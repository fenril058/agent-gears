#!/usr/bin/env bash
#
# check-skill-spec.sh — 各 skill が agentskills.io のオープン標準に準拠するか、
# 公式リファレンスバリデータ skills-ref で検証する。
#
# 仕様: https://agentskills.io/specification
# skills-ref が name/description の制約・name とディレクトリ名一致・必須フィールド・
# 仕様外フィールドの拒否を検証する。SKILL-ja.md 等の付随ファイルは対象外。
#
# ただし Claude Code は agentskills 標準をトップレベルフィールドで独自拡張しており
# (argument-hint 等)、skills-ref はそれらを "Unexpected fields" として一律エラーにする。
# skills-ref にはこれをマスクするオプションが無い(ALLOWED_FIELDS はハードコード)。
# この配布物の主対象は Claude Code なので、既知の Claude 拡張フィールドだけは許容する:
# 失格の原因が「列挙フィールドが全て CLAUDE_EXT に含まれる Unexpected fields エラー
# ただ 1 本」のときだけ合格に読み替える。name 違反・description 欠落・未知フィールド等
# が 1 つでも混じれば失格のまま。
#
# 必要: skills-ref。CI・devShell では flake の packages.skills-ref で供給する。
#   ローカル単発の厳格チェックは: nix run .#skills-ref -- validate <skill-dir>
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

# CLAUDE_EXT と tolerable() の定義本体。scripts/check-skill-spec-tolerable.test.sh も
# 同じ定義を source してテストする(挙動が乖離しないよう定義を一本化してある)。
# shellcheck source=lib/tolerable.sh
source "$REPO/scripts/lib/tolerable.sh"

if ! command -v skills-ref >/dev/null 2>&1; then
  echo "NG: skills-ref が PATH に無い。CI なら flake の packages.skills-ref を供給すること" >&2
  echo "    例: nix shell .#skills-ref --command bash scripts/check-skill-spec.sh" >&2
  exit 1
fi

fail=0
count=0

# SKILL.md のあるディレクトリを skill として全走査(SKILL-ja.md は拾われない)。
while IFS= read -r skillmd; do
  count=$((count + 1))
  dir="$(dirname "$skillmd")"
  if out="$(skills-ref validate "$dir" 2>&1)"; then
    continue
  fi
  if tolerable "$out"; then
    echo "OK(Claude拡張許容): $dir :: $(printf '%s' "$out" | grep -o 'Unexpected fields[^.]*\.')" >&2
    continue
  fi
  printf '%s\n' "$out" >&2
  fail=1
done < <(find . -name SKILL.md -not -path './.git/*' | sort)

if [ "$fail" = 0 ]; then
  echo "OK: $count 件の skill が agentskills.io 仕様に準拠(skills-ref / Claude 拡張は許容)"
fi
exit "$fail"
