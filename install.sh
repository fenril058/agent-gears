#!/usr/bin/env bash
#
# install.sh — context-engineering を単一ソースとして各エージェントへ symlink 配布する。
#
#   skills/<name>  -> ~/.claude/skills/<name>, ~/.codex/skills/<name>, ~/.agents/skills/<name>, ~/.copilot/skills/<name>
#   rules/always-on.md -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.copilot/copilot-instructions.md
#   agents/*.md    -> ~/.claude/agents/<file>   (Claude Code 固有)
#
# 冪等。既存 symlink は張り直す。実ファイル/実ディレクトリは .bak.<時刻> に退避してから張る。
#
# 使い方:
#   bash install.sh            実行
#   bash install.sh --dry-run  予定の表示のみ
#   bash install.sh --uninstall このリポジトリを指す symlink だけ外す
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
  --dry-run) DRY_RUN=1 ;;
  --uninstall) UNINSTALL=1 ;;
  *)
    echo "unknown option: $arg" >&2
    exit 2
    ;;
  esac
done

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
AGENTS_HOME="${AGENTS_HOME:-$HOME/.agents}"
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"

run() { if [ "$DRY_RUN" = 1 ]; then echo "  [dry-run] $*"; else eval "$*"; fi; }

# link SRC DEST — DEST を SRC への symlink にする(冪等・実ファイルは退避)
link() {
  local src="$1" dest="$2"
  local parent
  parent="$(dirname "$dest")"
  [ -d "$parent" ] || run "mkdir -p '$parent'"

  if [ -L "$dest" ]; then
    local cur
    cur="$(readlink "$dest")"
    if [ "$cur" = "$src" ]; then
      echo "  ok       $dest"
      return
    fi
    run "rm '$dest'"
  elif [ -e "$dest" ]; then
    local bak
    bak="$dest.bak.$(date +%Y%m%d%H%M%S)"
    echo "  backup   $dest -> $bak"
    run "mv '$dest' '$bak'"
  fi
  run "ln -s '$src' '$dest'"
  echo "  link     $dest -> $src"
}

# unlink DEST SRC — DEST が SRC を指す symlink のときだけ外す
unlink_if_ours() {
  local dest="$1" src="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    run "rm '$dest'"
    echo "  unlink   $dest"
  fi
}

# skill: plugins/<plugin>/skills/<name> と meta/<name>。agent定義: plugins/<plugin>/agents/<file>。
skills() {
  find "$REPO/plugins" -mindepth 3 -maxdepth 3 -type d -path '*/skills/*' 2>/dev/null
  find "$REPO/meta" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
}
agent_defs() { find "$REPO/plugins" -mindepth 3 -maxdepth 3 -type f -name '*.md' -path '*/agents/*' 2>/dev/null; }

# plan — このリポジトリが管理する link を "src<TAB>dest" で列挙する。
# install と uninstall はこの単一の対応表を共有する(配布先の二重記述を避ける)。
# hm-module.nix と同じ配布先集合になることは scripts/check-distribution.sh が検証する。
plan() {
  local d n f
  for d in $(skills); do
    n="$(basename "$d")"
    printf '%s\t%s\n' "$d" "$CLAUDE_HOME/skills/$n"
    printf '%s\t%s\n' "$d" "$CODEX_HOME/skills/$n"
    printf '%s\t%s\n' "$d" "$AGENTS_HOME/skills/$n"
    printf '%s\t%s\n' "$d" "$COPILOT_HOME/skills/$n"
  done
  printf '%s\t%s\n' "$REPO/rules/always-on.md" "$CLAUDE_HOME/CLAUDE.md"
  printf '%s\t%s\n' "$REPO/rules/always-on.md" "$CODEX_HOME/AGENTS.md"
  printf '%s\t%s\n' "$REPO/rules/always-on.md" "$COPILOT_HOME/copilot-instructions.md"
  for f in $(agent_defs); do
    n="$(basename "$f")"
    printf '%s\t%s\n' "$f" "$CLAUDE_HOME/agents/$n"
  done
}

if [ "$UNINSTALL" = 1 ]; then
  echo "Uninstalling symlinks pointing into $REPO ..."
  plan | while IFS=$'\t' read -r src dest; do
    unlink_if_ours "$dest" "$src"
  done
  echo "Done. Restart Claude Code / Codex to apply."
  exit 0
fi

echo "Installing from $REPO"
[ "$DRY_RUN" = 1 ] && echo "(dry-run: 変更は行いません)"

plan | while IFS=$'\t' read -r src dest; do
  link "$src" "$dest"
done

echo "Done. Restart Claude Code / Codex to pick up new skills."
