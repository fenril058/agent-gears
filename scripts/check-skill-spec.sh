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

# Claude Code が解釈するトップレベル拡張フィールド(agentskills 標準外)。
# 出典: https://code.claude.com/docs/en/skills の Frontmatter reference。
CLAUDE_EXT=" when_to_use argument-hint arguments disable-model-invocation user-invocable disallowed-tools model effort context agent hooks paths shell "

if ! command -v skills-ref >/dev/null 2>&1; then
  echo "NG: skills-ref が PATH に無い。CI なら flake の packages.skills-ref を供給すること" >&2
  echo "    例: nix shell .#skills-ref --command bash scripts/check-skill-spec.sh" >&2
  exit 1
fi

fail=0
count=0

# 失格出力が「Claude 拡張のみの Unexpected fields エラー 1 本」なら true。
tolerable() {
  local out="$1"
  # `  - ` で始まるエラー行を集める。
  local errline
  local errlines=()
  while IFS= read -r errline; do
    case "$errline" in
    "  - "*) errlines+=("${errline#  - }") ;;
    esac
  done <<<"$out"

  # 許容するのはエラーがちょうど 1 本のときだけ(他の違反が混じれば失格)。
  [ "${#errlines[@]}" -eq 1 ] || return 1

  local msg="${errlines[0]}"
  case "$msg" in
  "Unexpected fields in frontmatter: "*) ;;
  *) return 1 ;;
  esac

  # "Unexpected fields in frontmatter: a, b. Only [...] are allowed." から a, b を取り出す。
  local fields="${msg#Unexpected fields in frontmatter: }"
  fields="${fields%%. Only *}"

  # カンマ区切りの各フィールドが全て CLAUDE_EXT に含まれるか。
  local IFS=','
  local raw f
  for raw in $fields; do
    f="$(printf '%s' "$raw" | tr -d '[:space:]')"
    [ -z "$f" ] && continue
    case "$CLAUDE_EXT" in
    *" $f "*) ;;
    *) return 1 ;;
    esac
  done
  return 0
}

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
