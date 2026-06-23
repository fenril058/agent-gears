# context-engineering

トークン削減と効率的なエージェント運用のための **skill + 常時ルール** の単一ソース。
このリポジトリを編集すると、`install.sh` の symlink を通じて Claude Code・Codex・
共有スキルストアへ一括で反映される。

## なぜ

エージェント運用のコストの多くは、無駄な文脈の読み込みと、安価に回せる作業まで
高いモデルで処理することから来る。このリポジトリは次の4つを仕組みにする。

1. **モデル委譲** — 機械的・量的な作業を安価モデルのサブエージェントへ落とす。
2. **広域探索の効率化** — fastcontext で意味的な探索を少ない手数で行う。
3. **Markdown の部分取得** — md2idx で大きな文書の必要な節だけ取る。
4. **未定義語の抑制** — 勝手な造語を使わせない常時ルール。

## 構成

```
AGENTS.md            常時ルール(単一ソース)。全エージェントが常に従う最小限の不変則
skills/              必要なときだけ読み込まれる on-demand スキル
  markdown-context/  大きな Markdown を md2idx で部分取得(主役)/ mq(補助)
  fast-search/       fastcontext での広域・意味的探索
  model-routing/     安価モデルのサブエージェントへの委譲ポリシー
  no-neologism/      未定義語・勝手造語の点検手順(核ルールは AGENTS.md)
  japanese-tech-writing/  日本語技術文書の文章規範
  argument-gap-edit/      論証の筋を点検・再配置する編集
meta/                skill 自体を対象にするメタスキル(自作 skill の QA)
  empirical-prompt-tuning/  skill/プロンプトを実行者に走らせ実測で反復改善
agents/              Claude Code 用 安価モデル サブエージェント定義
  search.md          コードベース探索・調査(Sonnet)
  bulk-edit.md       機械的・反復的な編集(Haiku)
install.sh           symlink 配布スクリプト(skills/ と meta/ を配布)
```

`meta/` の skill も `skills/` と同様に各エージェントへ配布される。
skill を作った/直した直後に `empirical-prompt-tuning` をかけて、description が
狙ったタイミングで発火するか・本体が想定どおり振る舞うかを実測で締める。

### 外部 skill の取り込み

`meta/empirical-prompt-tuning` は [mizchi/skills](https://github.com/mizchi/skills/tree/main/meta/empirical-prompt-tuning)
由来。本リポジトリは日本語で統一しているため、有効な `SKILL.md` を日本語版
(上流の `SKILL-ja.md`)とし、上流の英語版を `SKILL-en.md` として参照用に併置した。
更新するときは上流の対応ファイルから取り直す。

### 常時ルール vs skill

- **常時ルール(AGENTS.md / CLAUDE.md)**: 毎ターン読まれる。短い不変則だけを置く。
- **skill**: `description` が今の作業に合致したときだけ読み込まれる。詳細手順はこちら。

「常に効かせたい最小限」は常時ルールへ、「必要時の詳しい手順」は skill へ、と分ける。

## 前提ツール

- [fastcontext](https://github.com/microsoft/fastcontext) — 広域・意味的探索
- [md2idx](https://github.com/oubakiou/md2idx) — Markdown を索引+節に変換(`npm i -g md2idx`)
- [mq](https://mqlang.org/) — Markdown 構造クエリ(補助)

## インストール

```bash
bash install.sh --dry-run   # 張る予定を確認
bash install.sh             # 実行
```

配布先(単一ソース = このリポジトリ):

| 対象 | Claude Code | Codex | 共有ストア |
|------|-------------|-------|-----------|
| skills/<name> | `~/.claude/skills/` | `~/.codex/skills/` | `~/.agents/skills/` |
| AGENTS.md | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | — |
| agents/*.md | `~/.claude/agents/` | (非対応) | — |

- 冪等。既存 symlink は張り直し、実ファイルは `.bak.<時刻>` に退避してから張る。
- 外すときは `bash install.sh --uninstall`(このリポジトリを指す symlink だけ外す)。
- **反映には Claude Code / Codex の再起動が必要。**

## Nix / home-manager

`install.sh` の宣言的な代替として home-manager モジュールを同梱する。
`flake.nix` の `homeManagerModules.default` を imports に足すと、skills/meta/agents/
常時ルールを各エージェントへ symlink 配布する。

home-manager の flake に取り込む例:

```nix
{
  inputs.context-engineering.url = "github:fenril058/context-engineering";

  # home.nix 側
  imports = [ inputs.context-engineering.homeManagerModules.default ];

  programs.context-engineering = {
    enable = true;
    # 作業ツリーへの絶対パス。既存 skill の編集が再ビルドなしで即反映される
    repoPath = "/home/ril/ghq/github.com/fenril058/context-engineering";
  };
}
```

オプション(既定値):

| オプション | 既定 | 意味 |
|---|---|---|
| `repoPath` | `null` | 作業ツリーの絶対パス(`mutable = true` のとき必須) |
| `mutable` | `true` | `true`=作業ツリーへの out-of-store symlink(編集即反映)。`false`=flake ソース(store)を直接配布(完全宣言的・反映には switch) |
| `claude.enable` | `true` | `~/.claude` へ配布 |
| `codex.enable` | `true` | `~/.codex` へ配布 |
| `sharedStore.enable` | `true` | `~/.agents/skills` へ配布 |
| `rules.enable` | `true` | `AGENTS.md` を `CLAUDE.md` / `AGENTS.md` として配布 |
| `agentDefs.enable` | `true` | `agents/*.md` を `~/.claude/agents` へ配布(Claude Code 固有) |

- 既定の `mutable = true` は本リポジトリの「編集が即反映」の思想に合わせたもの。
  完全に純粋な宣言運用にしたいなら `mutable = false`(ただし skill 編集の反映に
  `home-manager switch` が要る)。
- skill の**追加・削除**を反映するには、どちらのモードでも flake 更新 + `switch` が要る
  (配布対象の名前は flake ソースから列挙されるため)。
- 配布先に install.sh の手動 symlink が残っていると衝突する。home-manager 運用へ移る
  ときは `bash install.sh --uninstall` で先に外すか、`home-manager switch -b backup` を使う。
- 周辺ツール: `nix develop` で `jq` / `nodejs`(`npx md2idx` 用)が入る。
  `mq` / `fastcontext` は nixpkgs 外のため別途導入する。

## エージェントへの伝わり方

- **skill**: 3者とも同じ `SKILL.md`(YAML frontmatter の `name` / `description`)形式。
  `description` の「いつ使うか」が自動ロードの判定に使われるので、用途を具体的に書く。
- **常時ルール**: Claude は `CLAUDE.md`、Codex は `AGENTS.md` を読む。中身は同一ファイル。
- **モデル委譲**: agent 定義(`model:`)は Claude Code 固有。Claude Code は
  メインのモデルを自動切替できないため、`model-routing` skill の方針に従って
  Task/Agent ツールで安価サブエージェントへ委譲する。Codex は本 skill の方針 +
  Codex 自身のモデル設定で同等を達成する。

## 新しい skill を足すとき

1. `skills/<name>/SKILL.md` を作る(frontmatter に `name` と用途の具体的な `description`)。
2. 常時効かせたい最小限の不変則があれば `AGENTS.md` に1行追記する。
3. `bash install.sh` を実行し、各エージェントを再起動する。
