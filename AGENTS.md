このリポジトリの編集で間違えやすい点(更新の追従漏れ)。
手順の詳細は README の「構成」「常時ルール vs skill」「SKILL.md の言語」「配布方法」「既知の上流不具合と暫定回避」「新しい skill を足すとき」を見る。

## 正本と対応関係

repo-local 指示の正本はこの `AGENTS.md`。
`CLAUDE.md` は `@AGENTS.md` で取り込むだけ、`.github/copilot-instructions.md` はこれへの symlink。
Claude Code 固有の指示だけを `CLAUDE.md` に書く(Codex は読まない)。

常時ルール(`rules/always-on.md`)には不変則だけを書き、手順は skill 側へ置く。

覆しにくい決定は `docs/adr/` に記録する。
追記と supersede のみで、既存の ADR は書き換えない。
skill の A/B を始める前に `docs/adr/0001-evaluation-infrastructure-ownership.md` を読む。

## skill

`SKILL.md`(英語=正本)を直したら `SKILL-ja.md` も手動で追従する。
例外: `japanese-tech-writing` と `argument-gap-edit` は日本語 `SKILL.md` が正本、`TEMPLATE.md` は日本語のまま。

`SKILL.md` は agentskills.io 仕様に準拠する(CI: `scripts/check-skill-spec.sh`)。
Claude 拡張フィールド(argument-hint 等)を増やしたら、同スクリプトの `CLAUDE_EXT` も追従する。

外部由来の skill は取り込んで改変する(上流を取り直す運用はしない)。
由来の宣言元は `PROVENANCE.json` ただ1つで、追加・削除のたびに更新する。
plugin 単位の帰属表示は `plugins/agent-gears/LICENSE` / `NOTICE` に集約し、skill 単位の `LICENSE` は各 skill に残す。
各出所は `marker`(集約先に literal で現れる識別子)を `PROVENANCE.json` で宣言し、帰属表示ファイルがそれを含む(CI: `scripts/check-licenses.sh`、回帰テストは `scripts/check-licenses.test.sh`)。
marker が保証するのは識別子の残存までなので、許諾文の本文や skill 単位ファイルの中身が守られるとは文書に書かない。

## 配布

配布は `install.sh`(命令的)と `nix/hm-module.nix`(宣言的)の2系統で、配布先やレイアウト規約を変えたら両方直す(CI: `scripts/check-distribution.sh`)。
skill と agent はディレクトリ構成から自動列挙されるので、名前の追従は要らない。

単一 plugin の `name` / `version` / `keywords` は `.claude-plugin/marketplace.json` と `plugins/agent-gears/.claude-plugin/plugin.json` の両方にあり、一致は CI の `scripts/check-plugin-meta.sh` が検証する。
`description` は粒度が違う(marketplace=詳細 / plugin.json=短縮)ので手動で合わせる。
配布したい変更を入れたら両方の `version` を bump する(marketplace 経由の更新 pin なので、据え置くと install 済みの利用者へ届かない)。
`marketplace.json` の `source` は `"./plugins/<name>"` 形式で書く。
`"<name>"` だと一覧表示は通るのに `plugin install` が `source: Invalid input` で落ち、`metadata.pluginRoot` は解決時に使われないので当てにしない。

## Claude Code の Bash-first regression への暫定回避

回避は4箇所に分散し、役割が違うので撤去のしかたも違う。

- `rules/claude.md`「ファイル編集」節の dedicated `Read` の項(ADR 0002 の B) — 撤去必須
- README「既知の上流不具合と暫定回避」節 — 撤去必須
- `docs/claude-code-instruction-loading.md` — canary。撤去せず、何を撤去したか分かるよう更新する
- `docs/adr/0002-claude-code-bash-first-instruction-loading.md` — 書き換えず、supersede する ADR を足す

上流が直ったら、ADR 0002 の撤去条件を canary で満たすことを確認した上で、撤去必須の2つを同じ PR でまとめて外す(片方だけ残さない)。

## shellcheck とコード整形

CI の shellcheck(ubuntu 同梱版)とローカルの `nix shell nixpkgs#shellcheck` は版が違い、info レベル(SC2015 等)が食い違う。
`A && B || C` のような曖昧な構文を避けて書けば、どちらでも通る。

フォーマッタの唯一の定義は `treefmt.nix`。
`nix fmt` で一括整形し、`nix flake check` の `checks.formatting` が未整形を落とす。
対象言語を増やすときは `treefmt.nix` に programs を足す。
Markdown は「一文一行」規約と衝突するため対象外(手動整形)。
`switch_case_indent` は treefmt 経由で効かず直接 shfmt と食い違うので `.editorconfig` に書かない。

## nix

補助スクリプトや `nix eval` で `<nixpkgs>` / NIX_PATH に依存しない。
解決は各自の nix.conf 頼みで、CI の最小 nix には無く落ちる。
nixpkgs は flake から引く(例: `builtins.getFlake` の `inputs.nixpkgs`)。
