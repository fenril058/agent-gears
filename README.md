# agent-gears

トークン削減と効率的なエージェント運用のための、Claude Code・Codex 共用の
**skill / agent / 常時ルール** 一式。Claude には plugin マーケットプレイスとして、
Codex には skill として、自分の環境には home-manager で配布できる。

マーケットプレイス名: `fenril058-agent-skills`(`marketplace.json` の `name`)。

## なぜ

エージェント運用のコストの多くは、無駄な文脈の読み込みと、安価に回せる作業まで
高いモデルで処理することから来る。このリポジトリは次を仕組みにする。

1. **モデル委譲** — 機械的・量的な作業を安価モデルのサブエージェントへ落とす。
2. **広域探索の効率化** — fastcontext で意味的な探索を少ない手数で行う。
3. **Markdown の部分取得** — md2idx で大きな文書の必要な節だけ取る。
4. **未定義語の抑制** — 勝手な造語を使わせない常時ルール。

## 構成

```
.claude-plugin/marketplace.json   Claude 用マーケットプレイス定義(plugin 一覧)
plugins/
  context-engineering/            plugin: 文脈効率・トークン削減
    .claude-plugin/plugin.json
    skills/
      markdown-context/  大きな Markdown を md2idx で部分取得(主役)/ mq(補助)
      fast-search/       fastcontext での広域・意味的探索
      model-routing/     安価モデルのサブエージェントへの委譲ポリシー
      no-neologism/      未定義語・勝手造語の点検手順(核ルールは AGENTS.md)
    agents/
      search.md          コードベース探索・調査(Sonnet)
      bulk-edit.md       機械的・反復的な編集(Haiku)
  japanese-writing/               plugin: 日本語の文章規範
    .claude-plugin/plugin.json
    skills/
      japanese-tech-writing/  日本語技術文書の文章規範
      argument-gap-edit/      論証の筋を点検・再配置する編集
meta/
  empirical-prompt-tuning/        自作 skill の QA(第三者由来・非公開、下記)
AGENTS.md            常時ルール(個人設定)。各エージェントへ常時配線する最小限の不変則
install.sh           symlink 配布スクリプト(home-manager を使わない場合)
flake.nix / nix/     home-manager モジュール(宣言的配布)
```

このリポジトリは2つの性格を併せ持つ。**公開する skill/agent(`plugins/`)** と、
**個人のエージェント設定(`AGENTS.md` と配布配線)** である。前者はマーケットプレイス
として共有でき、後者は自分の `~/.claude` / `~/.codex` を構成する。

### 常時ルール vs skill

- **常時ルール(AGENTS.md → CLAUDE.md / AGENTS.md)**: 毎ターン読まれる。短い不変則だけ。
- **skill(`<plugin>/skills/<name>/SKILL.md`)**: `description` が今の作業に合致したときだけ
  読み込まれる。詳細手順はこちら。

### 外部 skill の扱い(meta/empirical-prompt-tuning)

`meta/empirical-prompt-tuning` は [mizchi/skills](https://github.com/mizchi/skills/tree/main/meta/empirical-prompt-tuning)
由来で、**ライセンス表記が無い(全権利留保)**。そのため `marketplace.json` には載せず
**公開 plugin に含めない**。自分の環境へは home-manager / install.sh で配布する(個人利用)。
有効な `SKILL.md` は日本語版(上流 `SKILL-ja.md`)、英語版は `SKILL-en.md` として併置。
更新は上流から取り直す。自作 skill を作った/直した直後に、これで実測 QA をかける。

## 前提ツール

- [fastcontext](https://github.com/microsoft/fastcontext) — 広域・意味的探索。
  OpenAI 互換 API がバックエンドで、環境変数 `API_KEY`(or `OPENAI_API_KEY`)/ `MODEL` /
  `BASE_URL` が要る(未設定だと `Missing credentials` で落ちる)。鍵はコミットせず
  各自設定する。未設定時は `fast-search` skill のフォールバック(Explore / Grep+Read)で代替。
- [md2idx](https://github.com/oubakiou/md2idx) — Markdown を索引+節に変換(`npm i -g md2idx`)
- [mq](https://mqlang.org/) — Markdown 構造クエリ(補助)

## 配布方法

用途に応じて3経路。中身(`SKILL.md` ディレクトリ)は共通で、経路は併用できる。

### 1. Claude — plugin マーケットプレイス

```
/plugin marketplace add fenril058/agent-gears
/plugin install context-engineering@fenril058-agent-skills
/plugin install japanese-writing@fenril058-agent-skills
```

plugin 内の `skills/` と `agents/` が自動で読み込まれる。

### 2. Codex — skill-installer

Codex の `skill-installer` で GitHub の skill ディレクトリを `$CODEX_HOME/skills` へ導入する。

```
install-skill-from-github.py --repo fenril058/agent-gears --path plugins/context-engineering/skills/markdown-context
```

(`agents/` は Claude 固有のため Codex では扱わない。)

### 3. 自分の環境 — home-manager(クロスエージェント宣言配布)

skills/agents/常時ルールを `~/.claude`・`~/.codex`・共有ストアへ一括 symlink する。
Claude を plugin 経由にするなら `claude.enable = false` にして重複を避けられる。

```nix
{
  inputs.agent-gears.url = "github:fenril058/agent-gears";

  imports = [ inputs.agent-gears.homeManagerModules.default ];

  programs.agent-gears = {
    enable = true;
    repoPath = "/home/ril/ghq/github.com/fenril058/agent-gears";  # 作業ツリー(編集即反映)
  };
}
```

| オプション | 既定 | 意味 |
|---|---|---|
| `repoPath` | `null` | 作業ツリーの絶対パス(`mutable = true` のとき必須) |
| `mutable` | `true` | `true`=作業ツリーへの out-of-store symlink(編集即反映)。`false`=flake ソース(store)を直接配布 |
| `claude.enable` | `true` | `~/.claude` へ配布(plugin 経由にするなら `false`) |
| `codex.enable` | `true` | `~/.codex` へ配布 |
| `sharedStore.enable` | `true` | `~/.agents/skills` へ配布 |
| `rules.enable` | `true` | `AGENTS.md` を `CLAUDE.md` / `AGENTS.md` として配布 |
| `agentDefs.enable` | `true` | `plugins/*/agents/*.md` を `~/.claude/agents` へ配布(Claude 固有) |

- skill の**追加・削除**の反映には flake 更新 + `home-manager switch` が要る
  (配布対象は flake ソースから列挙)。既存 skill の編集は `mutable = true` なら即反映。
- 配布対象は `plugins/*/skills/*`・`plugins/*/agents/*`・`meta/*`。

### 4. home-manager を使わない場合 — install.sh

```bash
bash install.sh --dry-run   # 張る予定を確認
bash install.sh             # 実行(冪等。実ファイルは .bak.<時刻> に退避)
bash install.sh --uninstall # このリポジトリを指す symlink だけ外す
```

配布先:

| 対象 | Claude Code | Codex | 共有ストア |
|------|-------------|-------|-----------|
| 各 skill | `~/.claude/skills/` | `~/.codex/skills/` | `~/.agents/skills/` |
| AGENTS.md | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | — |
| agents/*.md | `~/.claude/agents/` | (非対応) | — |

**反映には Claude Code / Codex の再起動が必要。**

## エージェントへの伝わり方

- **skill**: 3者とも同じ `SKILL.md`(frontmatter の `name` / `description`)形式。
  `description` の「いつ使うか」が自動ロードの判定に使われるので、用途を具体的に書く。
- **常時ルール**: Claude は `CLAUDE.md`、Codex は `AGENTS.md` を読む。中身は同一(`AGENTS.md`)。
- **モデル委譲**: agent 定義(`model:`)は Claude 固有。Claude はメインのモデルを自動切替
  できないため、`model-routing` skill に従い Task/Agent ツールで安価サブエージェントへ委譲する。
  Codex は本 skill の方針 + Codex 自身のモデル設定で同等を達成する。

## 新しい skill を足すとき

1. `plugins/<plugin>/skills/<name>/SKILL.md` を作る(frontmatter に `name` と具体的な `description`)。
2. 常時効かせたい最小限の不変則があれば `AGENTS.md` に1行追記する。
3. 公開するなら `marketplace.json` の該当 plugin に含まれることを確認(skills/ 配下は自動検出)。
4. `home-manager switch`(または `bash install.sh`)で配布し、各エージェントを再起動する。
5. 重要 skill は `meta/empirical-prompt-tuning` で実測 QA をかける。
