#!/usr/bin/env bash
#
# install-stale-links.test.sh — install.sh が削除済み skill / agent 定義の残骸を外すことの
# 回帰テスト(#63)。
#
# plan() と obsolete_plan() は「現存する」skill から配布先を組み立てるため、リポジトリから
# 消えた skill の link はどちらの表にも現れず、通常実行でも --uninstall でも残っていた。
#
# 配布先4つを一時ディレクトリに向けて install.sh を実際に実行し、symlink の残り方を直接
# 見る。REPO は install.sh 自身の位置から決まるので実リポジトリを指すが、書き込みは
# CLAUDE_HOME / CODEX_HOME / AGENTS_HOME / COPILOT_HOME の配下だけに起きる。
# ケース5・6 は install.sh を一時リポジトリへコピーし、そこで skill の追加と削除を行う。
#
# 注意: 説明文に $ を書かない。shfmt がエスケープ済みの二重引用符を単引用符へ畳み、
# ubuntu 同梱の shellcheck が SC2016 で落とす(ローカルの新しい shellcheck は通る)。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0
count=0

# 現役の skill を1つ選ぶ。名前はハードコードしない(skill は増減し plugin 間を移動する)。
live_skill="$(find "$REPO/plugins" -mindepth 3 -maxdepth 3 -type d -path '*/skills/*' | sort | head -1)"
if [ -z "$live_skill" ]; then
  echo "NG: 現役の skill が1つも見つからない(テストの前提が壊れている)" >&2
  exit 1
fi
live_name="$(basename "$live_skill")"

# ケース5・6 で一時リポジトリへ置く skill。
tmp_name="zz-install-stale-links-test"

tmp="$(mktemp -d)"
fixture_repo="$(mktemp -d)"
tmp_skill="$fixture_repo/plugins/test/skills/$tmp_name"
cp "$REPO/install.sh" "$fixture_repo/install.sh"

export CLAUDE_HOME="$tmp/claude"
export CODEX_HOME="$tmp/codex"
export AGENTS_HOME="$tmp/agents"
export COPILOT_HOME="$tmp/copilot"

trap 'rm -rf "$tmp" "$fixture_repo"' EXIT INT TERM

# 残骸と、外してはならない対照を配布先に置く。
setup() {
  rm -rf "$tmp"
  mkdir -p "$CLAUDE_HOME/skills" "$AGENTS_HOME/skills" "$COPILOT_HOME/skills" \
    "$CODEX_HOME/skills" "$CLAUDE_HOME/agents" "$tmp/elsewhere"

  # 外れるべきもの: リポジトリ配下の実在しない path を指す = 削除済み skill / agent の残骸。
  ln -s "$REPO/plugins/gone-plugin/skills/gone-skill" "$CLAUDE_HOME/skills/gone-skill"
  ln -s "$REPO/plugins/gone-plugin/skills/gone-skill" "$AGENTS_HOME/skills/gone-skill"
  ln -s "$REPO/plugins/gone-plugin/skills/gone-skill" "$COPILOT_HOME/skills/gone-skill"
  ln -s "$REPO/plugins/gone-plugin/skills/gone-skill" "$CODEX_HOME/skills/gone-skill"
  ln -s "$REPO/plugins/gone-plugin/agents/gone.md" "$CLAUDE_HOME/agents/gone.md"

  # 残るべきもの: 参照先がリポジトリ配下でない = 利用者自身が張った link。
  ln -s "$tmp/elsewhere" "$CLAUDE_HOME/skills/user-own"
  ln -s "$tmp/nowhere" "$CLAUDE_HOME/skills/user-dangling"
}

# 一時 skill を fixture に置く。install.sh の skills() は SKILL.md を見ないが、
# 中途半端なディレクトリを残さないよう本文も置く。
make_tmp_skill() {
  mkdir -p "$tmp_skill"
  printf -- '---\nname: %s\ndescription: 回帰テスト用の一時 skill。テスト終了時に消える。\n---\n' \
    "$tmp_name" >"$tmp_skill/SKILL.md"
}

assert_gone() {
  local desc="$1" path="$2"
  count=$((count + 1))
  if [ -L "$path" ]; then
    echo "NG: $desc — $path が残っている(-> $(readlink "$path"))" >&2
    fail=1
  fi
}

assert_kept() {
  local desc="$1" path="$2"
  count=$((count + 1))
  if [ ! -L "$path" ]; then
    echo "NG: $desc — $path が無い" >&2
    fail=1
  fi
}

# 1. 通常実行 — 残骸を外し、現役の link を張り、利用者の link には触らない。
setup
bash "$REPO/install.sh" >/dev/null
assert_gone "通常実行: 残骸(~/.claude/skills)" "$CLAUDE_HOME/skills/gone-skill"
assert_gone "通常実行: 残骸(~/.agents/skills)" "$AGENTS_HOME/skills/gone-skill"
assert_gone "通常実行: 残骸(~/.copilot/skills)" "$COPILOT_HOME/skills/gone-skill"
assert_gone "通常実行: 残骸(旧配布先 ~/.codex/skills)" "$CODEX_HOME/skills/gone-skill"
assert_gone "通常実行: 残骸(agent 定義)" "$CLAUDE_HOME/agents/gone.md"
assert_kept "通常実行: 利用者の link(参照先あり)" "$CLAUDE_HOME/skills/user-own"
assert_kept "通常実行: 利用者の link(参照先なし・リポジトリ外)" "$CLAUDE_HOME/skills/user-dangling"
assert_kept "通常実行: 現役 skill($live_name)" "$CLAUDE_HOME/skills/$live_name"

# 2. --uninstall — 残骸も外れ、利用者の link は残る。
setup
bash "$REPO/install.sh" --uninstall >/dev/null
assert_gone "--uninstall: 残骸(~/.claude/skills)" "$CLAUDE_HOME/skills/gone-skill"
assert_gone "--uninstall: 残骸(~/.agents/skills)" "$AGENTS_HOME/skills/gone-skill"
assert_gone "--uninstall: 残骸(~/.copilot/skills)" "$COPILOT_HOME/skills/gone-skill"
assert_gone "--uninstall: 残骸(旧配布先 ~/.codex/skills)" "$CODEX_HOME/skills/gone-skill"
assert_gone "--uninstall: 残骸(agent 定義)" "$CLAUDE_HOME/agents/gone.md"
assert_kept "--uninstall: 利用者の link(参照先あり)" "$CLAUDE_HOME/skills/user-own"
assert_kept "--uninstall: 利用者の link(参照先なし・リポジトリ外)" "$CLAUDE_HOME/skills/user-dangling"

# 3. install の後の --uninstall — 現役の link も外れる(従来の契約の回帰確認)。
setup
bash "$REPO/install.sh" >/dev/null
bash "$REPO/install.sh" --uninstall >/dev/null
assert_gone "install 後の --uninstall: 現役 skill($live_name)" "$CLAUDE_HOME/skills/$live_name"
assert_gone "install 後の --uninstall: rules" "$CLAUDE_HOME/CLAUDE.md"
assert_kept "install 後の --uninstall: 利用者の link" "$CLAUDE_HOME/skills/user-own"

# 4. --dry-run — 何も消さない。
setup
bash "$REPO/install.sh" --dry-run >/dev/null
assert_kept "--dry-run: 残骸を消さない" "$CLAUDE_HOME/skills/gone-skill"
assert_kept "--dry-run: 利用者の link を消さない" "$CLAUDE_HOME/skills/user-own"

# 5. issue #63 の再現手順そのもの(通常実行)。
#
# 1〜4 は残骸を手で作るので、install.sh が「実際に張る」link の綴りと remove_stale_links が
# 照合する綴りが一致していることまでは確かめられない。ここでは一時 skill をリポジトリに
# 置いて install.sh に張らせ、skill を消してから再実行する。
setup
make_tmp_skill
bash "$fixture_repo/install.sh" >/dev/null
assert_kept "再現手順: 一時 skill の link が張られる" "$CLAUDE_HOME/skills/$tmp_name"
rm -rf "$tmp_skill"
bash "$fixture_repo/install.sh" >/dev/null
assert_gone "再現手順(通常実行): 削除後の残骸(~/.claude/skills)" "$CLAUDE_HOME/skills/$tmp_name"
assert_gone "再現手順(通常実行): 削除後の残骸(~/.agents/skills)" "$AGENTS_HOME/skills/$tmp_name"
assert_gone "再現手順(通常実行): 削除後の残骸(~/.copilot/skills)" "$COPILOT_HOME/skills/$tmp_name"

# 6. issue #63 の再現手順そのもの(--uninstall)。
setup
make_tmp_skill
bash "$fixture_repo/install.sh" >/dev/null
rm -rf "$tmp_skill"
bash "$fixture_repo/install.sh" --uninstall >/dev/null
assert_gone "再現手順(--uninstall): 削除後の残骸(~/.claude/skills)" "$CLAUDE_HOME/skills/$tmp_name"
assert_gone "再現手順(--uninstall): 削除後の残骸(~/.agents/skills)" "$AGENTS_HOME/skills/$tmp_name"
assert_gone "再現手順(--uninstall): 削除後の残骸(~/.copilot/skills)" "$COPILOT_HOME/skills/$tmp_name"

if [ "$fail" = 0 ]; then
  echo "OK: $count 件の install.sh 残骸掃除テストに合格"
fi
exit "$fail"
