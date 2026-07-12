# shellcheck shell=bash
# tolerable.sh — check-skill-spec.sh の中核判定ロジック。テストのために独立ファイルへ
# 切り出してある(scripts/check-skill-spec.sh と scripts/check-skill-spec-tolerable.test.sh
# の両方から source される)。単体では実行しない、source 専用ライブラリ。
#
# Claude Code が解釈するトップレベル拡張フィールド(agentskills 標準外)。
# 出典: https://code.claude.com/docs/en/skills の Frontmatter reference。
CLAUDE_EXT=" when_to_use argument-hint arguments disable-model-invocation user-invocable disallowed-tools model effort context agent hooks paths shell "

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
