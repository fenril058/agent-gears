このリポジトリの編集で間違えやすい点(更新の追従漏れ):

- `SKILL.md`(英語=正本)を直したら `SKILL-ja.md` も手動で追従。
  例外: `writing` の `japanese-tech-writing` / `argument-gap-edit` は日本語 `SKILL.md` が正本／`TEMPLATE.md` は日本語のまま。
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
  `marketplace.json` の `source` は `"./plugins/<name>"` 形式で書く。
  Claude Code は `"./"` 始まりの相対パスしか受け付けず、`"<name>"` だと一覧表示は通るのに
  `plugin install` が `source: Invalid input` で落ちる。
  `metadata.pluginRoot` は schema にはあるが解決時に使われないので当てにしない。
- 常時ルールは `rules/always-on.md` に不変則だけ。手順は skill 側へ。
- skill の eval corpus は `plugins/<plugin>/skills/<skill>/evals/cases.json`。
  形式定義は `agent-instructions/skills/empirical-prompt-tuning/EVAL-CORPUS.md` ただ1つ。
  CI の `scripts/check-evals.sh` が schema・`[critical]` の存在・結果ファイルの
  success/accuracy の検算まで見る(未知フィールドは失格)。
  case id と requirement id は既存の結果から参照されるのでリネームしない。text だけ直す。
  host/model をまたいだ総合スコアのフィールドを足さない。比較単位は
  `(case, host, model, candidate)` で、平均すると model 固有の regression が消える。
  LLM を呼ぶ評価自体は CI に入れない。
- repo-local 指示の正本はこの `AGENTS.md`。`CLAUDE.md` は `@AGENTS.md` で取り込むだけ、
  `.github/copilot-instructions.md` はこれへの symlink。全エージェント共通の内容はここに書く。
  `CLAUDE.md` に書いてよいのは Claude Code 固有の指示だけ(Codex は読まない)。
- 外部由来の skill は取り込んで改変する(上流を取り直す運用はしない)。
  由来の宣言元は `PROVENANCE.json` ただ1つ。新たに取り込んだらここに追記する。
  `LICENSE` / `NOTICE` を消さない。plugin 単位の `LICENSE`(shokai/agent-skills)は
  複数 plugin に分散するので、skill を動かしたら移動先への複製と移動元の残骸に注意。
  宣言と実ファイルの一致は CI の `scripts/check-licenses.sh` が検証する。

手順は README:「構成」「常時ルール vs skill」「SKILL.md の言語」「配布方法」「新しい skill を足すとき」。

コード整形(treefmt):

- フォーマッタの唯一の定義は `treefmt.nix`。`nix fmt` で一括整形、`nix flake check` の
  `checks.formatting` が未整形を落とす(CI の `nix` job が実行)。対象は `.nix`(nixpkgs-fmt)/
  `.go`(gofmt)/ `.sh`(shfmt)。shell のインデントは `.editorconfig`(space/2)に従う。
  `switch_case_indent` は treefmt 経由で効かず直接 shfmt と食い違うので `.editorconfig` に書かない。
  Markdown は「一文一行」規約と衝突するため対象外(手動整形)。
  対象言語を増やすときは `treefmt.nix` に programs を足す。

nix の落とし穴:

- 補助スクリプトや `nix eval` で `<nixpkgs>` / NIX_PATH に依存しない。
  `<nixpkgs>` の解決は各自の nix.conf(`nix-path` / `extra-nix-path`)頼みで、CI の最小 nix には無く落ちる。
  nixpkgs は flake から引く(例: `builtins.getFlake` の `inputs.nixpkgs`)。
