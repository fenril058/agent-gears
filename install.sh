#!/usr/bin/env bash
#
# install.sh — context-engineering を単一ソースとして各エージェントへ symlink 配布する。
#
#   skills/<name>  -> ~/.claude/skills/<name>, ~/.agents/skills/<name>, ~/.copilot/skills/<name>
#   rules/always-on.md -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.copilot/copilot-instructions.md
#   rules/claude.md    -> ~/.claude/rules/agent-gears.md
#   agents/*.md    -> ~/.claude/agents/<file>   (Claude Code 固有)
#
# 冪等。既存 symlink は張り直す。実ファイル/実ディレクトリは .bak.<時刻> に退避してから張る。
# リポジトリから消えた skill / agent 定義が残した dangling symlink も外す。
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

# skill: plugins/<plugin>/skills/<name>。agent定義: plugins/<plugin>/agents/<file>。
skills() {
  find "$REPO/plugins" -mindepth 3 -maxdepth 3 -type d -path '*/skills/*' 2>/dev/null
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
    printf '%s\t%s\n' "$d" "$AGENTS_HOME/skills/$n"
    printf '%s\t%s\n' "$d" "$COPILOT_HOME/skills/$n"
  done
  printf '%s\t%s\n' "$REPO/rules/always-on.md" "$CLAUDE_HOME/CLAUDE.md"
  printf '%s\t%s\n' "$REPO/rules/claude.md" "$CLAUDE_HOME/rules/agent-gears.md"
  printf '%s\t%s\n' "$REPO/rules/always-on.md" "$CODEX_HOME/AGENTS.md"
  printf '%s\t%s\n' "$REPO/rules/always-on.md" "$COPILOT_HOME/copilot-instructions.md"
  for f in $(agent_defs); do
    n="$(basename "$f")"
    printf '%s\t%s\n' "$f" "$CLAUDE_HOME/agents/$n"
  done
}

# obsolete_plan — 旧版が作成した、現在は使わない link を列挙する。
obsolete_plan() {
  local d n
  for d in $(skills); do
    n="$(basename "$d")"
    printf '%s\t%s\n' "$d" "$CODEX_HOME/skills/$n"
  done
}

remove_obsolete_links() {
  obsolete_plan | while IFS=$'\t' read -r src dest; do
    unlink_if_ours "$dest" "$src"
  done
}

# 配布先ディレクトリ — このリポジトリが「名前ごとに1本」link を張る場所。
# 末尾の2つは現役の配布先ではないが、旧版が張った残骸を探すために走査する。
link_dirs() {
  printf '%s\n' \
    "$CLAUDE_HOME/skills" \
    "$AGENTS_HOME/skills" \
    "$COPILOT_HOME/skills" \
    "$CLAUDE_HOME/agents" \
    "$CODEX_HOME/skills"
}

# remove_stale_links — 配布先に残る、$REPO 配下の実在しない path を指す symlink を外す。
#
# plan() と obsolete_plan() は「現存する」skill / agent 定義から配布先を組み立てるので、
# リポジトリから消えたものの link はどちらの表にも現れず、通常実行でも --uninstall でも
# 外れない。ここだけは対応表ではなく配布先側から走査する。
#
# 「このリポジトリを指す symlink だけ外す」契約は保つ。参照先が $REPO 配下でない link は
# 利用者のものとして触らず、$REPO 配下でも実体があれば現役として残す。よって外れるのは
# 参照先を失った link だけで、これは既に何も読み込ませていない。
remove_stale_links() {
  local dir dest target
  while IFS= read -r dir; do
    [ -d "$dir" ] || continue
    for dest in "$dir"/*; do
      [ -L "$dest" ] || continue
      target="$(readlink "$dest")"
      case "$target" in
      "$REPO"/*) ;;
      *) continue ;;
      esac
      if [ -e "$target" ]; then
        continue
      fi
      run "rm '$dest'"
      echo "  stale    $dest -> $target"
    done
  done < <(link_dirs)
}

if [ "$UNINSTALL" = 1 ]; then
  echo "Uninstalling symlinks pointing into $REPO ..."
  plan | while IFS=$'\t' read -r src dest; do
    unlink_if_ours "$dest" "$src"
  done
  remove_obsolete_links
  remove_stale_links
  echo "Done. Restart Claude Code / Codex to apply."
  exit 0
fi

echo "Installing from $REPO"
[ "$DRY_RUN" = 1 ] && echo "(dry-run: 変更は行いません)"

remove_obsolete_links
remove_stale_links
plan | while IFS=$'\t' read -r src dest; do
  link "$src" "$dest"
done

echo "Done. Restart Claude Code / Codex to pick up new skills."
