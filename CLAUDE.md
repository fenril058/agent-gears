このリポジトリの編集で間違えやすい点(更新の追従漏れ):

- `SKILL.md`(英語=正本)を直したら `SKILL-ja.md` も手動で追従。
  例外: `japanese-writing` は日本語 `SKILL.md` が正本／`TEMPLATE.md` は日本語のまま。
  各 `SKILL.md` は agentskills.io 仕様に準拠(公式 `skills-ref` で検証)。
  CI の `scripts/check-skill-spec.sh`(flake の `packages.skills-ref` を使う)が検証する。
  skills-ref は Claude 拡張フィールド(argument-hint 等)を一律エラーにするが、スクリプト側で
  既知の Claude 拡張(`CLAUDE_EXT`)のみの Unexpected fields エラーは合格に読み替える。
  未知フィールドや name/description 違反は失格。Claude 拡張フィールドを増やしたら CLAUDE_EXT も追従。
  skills-ref 本体の nix 定義は `nix/skills-ref.nix`(由来: yasunori0418/skills, MIT)。
- 配布は `install.sh`(命令的)と `nix/hm-module.nix`(宣言的)の2系統。
  両者は skill/agent をディレクトリ構成から自動列挙するので名前の追従は要らない。
  配布先(`~/.claude` 等)やレイアウト規約を変えたら両方直す。
  配布先集合の一致は CI の `scripts/check-distribution.sh` が検証する。
- plugin の `name`/`version`/`keywords` は `marketplace.json` と各 `plugin.json` に重複。
  一致は CI の `scripts/check-plugin-meta.sh` が検証する。
  `description` は粒度が違う(marketplace=詳細／plugin.json=短縮)ので手動。
- 常時ルールは `rules/always-on.md` に不変則だけ。手順は skill 側へ。
- `agent-collaboration`(MIT)/ `japanese-writing`(public domain)/ `meta`(MIT) は外部由来。
  `LICENSE` / `NOTICE` を消さない。`meta` は upstream から取り直す。

手順は README:「構成」「常時ルール vs skill」「SKILL.md の言語」「配布方法」「新しい skill を足すとき」。

nix の落とし穴:

- 補助スクリプトや `nix eval` で `<nixpkgs>` / NIX_PATH に依存しない。
  `<nixpkgs>` の解決は各自の nix.conf(`nix-path` / `extra-nix-path`)頼みで、CI の最小 nix には無く落ちる。
  nixpkgs は flake から引く(例: `builtins.getFlake` の `inputs.nixpkgs`)。

Markdownの整形ルール:

- 一文ごとに改行し、段落の区切りは空行で示す。
