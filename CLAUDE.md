このリポジトリの編集で間違えやすい点(ドリフト):

- `SKILL.md`(英語=正本)を直したら `SKILL-ja.md` も手動で追従。
  例外: `japanese-writing` は日本語 `SKILL.md` が正本／`TEMPLATE.md` は日本語のまま。
- 配布の仕組みは `install.sh` と `nix/hm-module.nix` の2系統。参照名やレイアウトを
  変えたら両方(install.sh の `--uninstall` 節も)直す。
- plugin の description は `marketplace.json` と各 `plugin.json` に重複。両方更新。
- 常時ルールは `rules/always-on.md` に不変則だけ。手順は skill 側へ。
- `agent-collaboration`(MIT)/ `japanese-writing`(public domain)/ `meta`(MIT) は
  外部由来。`LICENSE` / `NOTICE` を消さない。`meta` は upstream から取り直す。

手順は README:「構成」「常時ルール vs skill」「SKILL.md の言語」「配布方法」
「新しい skill を足すとき」。
