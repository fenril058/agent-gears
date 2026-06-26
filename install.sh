#!/usr/bin/env bash
#
# install.sh — context-engineering を単一ソースとして各エージェントへ symlink 配布する。
#
#   skills/<name>  -> ~/.claude/skills/<name>, ~/.codex/skills/<name>, ~/.agents/skills/<name>
#   rules/always-on.md -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md
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
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
AGENTS_HOME="${AGENTS_HOME:-$HOME/.agents}"

run() { if [ "$DRY_RUN" = 1 ]; then echo "  [dry-run] $*"; else eval "$*"; fi; }

# link SRC DEST — DEST を SRC への symlink にする(冪等・実ファイルは退避)
link() {
  local src="$1" dest="$2"
  local parent; parent="$(dirname "$dest")"
  [ -d "$parent" ] || run "mkdir -p '$parent'"

  if [ -L "$dest" ]; then
    local cur; cur="$(readlink "$dest")"
    if [ "$cur" = "$src" ]; then echo "  ok       $dest"; return; fi
    run "rm '$dest'"
  elif [ -e "$dest" ]; then
    local bak; bak="$dest.bak.$(date +%Y%m%d%H%M%S)"
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
    run "rm '$dest'"; echo "  unlink   $dest"
  fi
}

# skill: plugins/<plugin>/skills/<name> と meta/<name>。agent定義: plugins/<plugin>/agents/<file>。
skills() {
  find "$REPO/plugins" -mindepth 3 -maxdepth 3 -type d -path '*/skills/*' 2>/dev/null
  find "$REPO/meta" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
}
agent_defs() { find "$REPO/plugins" -mindepth 3 -maxdepth 3 -type f -name '*.md' -path '*/agents/*' 2>/dev/null; }

if [ "$UNINSTALL" = 1 ]; then
  echo "Uninstalling symlinks pointing into $REPO ..."
  for d in $(skills); do n="$(basename "$d")"
    unlink_if_ours "$CLAUDE_HOME/skills/$n" "$d"
    unlink_if_ours "$CODEX_HOME/skills/$n" "$d"
    unlink_if_ours "$AGENTS_HOME/skills/$n" "$d"
  done
  for f in $(agent_defs); do n="$(basename "$f")"
    unlink_if_ours "$CLAUDE_HOME/agents/$n" "$f"
  done
  unlink_if_ours "$CLAUDE_HOME/CLAUDE.md" "$REPO/rules/always-on.md"
  unlink_if_ours "$CODEX_HOME/AGENTS.md"  "$REPO/rules/always-on.md"
  echo "Done. Restart Claude Code / Codex to apply."
  exit 0
fi

echo "Installing from $REPO"
[ "$DRY_RUN" = 1 ] && echo "(dry-run: 変更は行いません)"

echo "Skills:"
for d in $(skills); do n="$(basename "$d")"
  link "$d" "$CLAUDE_HOME/skills/$n"
  link "$d" "$CODEX_HOME/skills/$n"
  link "$d" "$AGENTS_HOME/skills/$n"
done

echo "Always-on rules:"
link "$REPO/rules/always-on.md" "$CLAUDE_HOME/CLAUDE.md"
link "$REPO/rules/always-on.md" "$CODEX_HOME/AGENTS.md"

echo "Agent definitions (Claude Code):"
for f in $(agent_defs); do n="$(basename "$f")"
  link "$f" "$CLAUDE_HOME/agents/$n"
done

echo "Done. Restart Claude Code / Codex to pick up new skills."
