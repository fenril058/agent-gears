# agent-gears

Claude Code・Codex 共用の **skill / agent / 常時ルール** 一式。
Claude には plugin マーケットプレイスとして、Codex には skill として、自分の環境には home-manager で配布できる。

このリポジトリは2つの性格を併せ持つ。
**公開する skill/agent(`plugins/`)** と、**個人のエージェント設定(`rules/always-on.md` と、その symlink 配布の仕組み)** である。
前者はマーケットプレイスとして共有でき、後者は自分の `~/.claude` / `~/.codex` を構成する。
マーケットプレイス名は `fenril058-agent-skills`(`marketplace.json` の `name`)である。

リポジトリ直下の `CLAUDE.md` / `AGENTS.md` はこの両者とは別で、このリポジトリ自体を編集するエージェントへの repo-local 指示である。
こちらは配布はされない。

## 内容

このリポジトリは、領域の異なるエージェント向け skill を1か所に束ねて配布する。
現在は3つの plugin がある。

### context-engineering (文脈効率・トークン削減)

運用コストの多くは、無駄な文脈の読み込みと、安価に回せる作業まで高いモデルで処理することから来る。
これに対し:

1. **モデル委譲** — 機械的・量的な作業を安価モデルのサブエージェントへ落とす。
2. **広域探索の効率化** — fastcontext で意味的な探索を少ない手数で行う。
3. **Markdown の部分取得** — mdidx で大きな文書の必要な節だけ取る。
4. **未定義語の抑制** — 勝手な造語を使わせない常時ルール。

### japanese-writing (日本語の文章規範)

日本語の技術文書・書籍原稿で、整形・パラグラフライティング・論証の厳密さ・冗長の排除などの規範を skill 化し、執筆・推敲時に適用する。
論証の筋の点検と再配置を行う argument-gap-edit を含む。

### agent-collaboration (エージェント協調)

エージェント単独では精度に限界がある作業を、別エージェントとの相談や対話コンテキストの引き継ぎで補う。

- subagent-consultation: サブエージェントにセカンドオピニオンを求め、往復検証で精度を上げる。
- sanity-review: 対話コンテキスト・PR 概要欄・実装コードの整合性つまり「実装者の正気」を点検する PR レビュー報告書を作成する。結果ではなくプロセスをレビューする。
- library-update-review: 依存更新 PR のレビューを行う。
- conversation-context-export/import: ブランチ単位で設計判断・却下理由・制約を引き継ぐ。`.dev/contexts/` は作業ブランチに置き、PR とともに捨てる(main へは merge しない)揮発層。
- durable-knowledge-export: ブランチを越えて残す知見 (実測値・規約・システム横断の落とし穴) を、あれば GitHub wiki、無ければリポジトリ内 docs へ保存する。

## 構成

```
.claude-plugin/marketplace.json   Claude 用マーケットプレイス定義(plugin 一覧)
plugins/
  context-engineering/            plugin: 文脈効率・トークン削減
    .claude-plugin/plugin.json
    skills/
      markdown-context/  大きな Markdown を mdidx で部分取得(主役)/ mq(補助)
      fast-search/       fastcontext での広域・意味的探索
      model-routing/     安価モデルのサブエージェントへの委譲ポリシー
      no-neologism/      未定義語・勝手造語の点検手順(核ルールは rules/always-on.md)
    agents/
      search.md          コードベース探索・調査(Sonnet)
      bulk-edit.md       機械的・反復的な編集(Haiku)
  japanese-writing/               plugin: 日本語の文章規範
    .claude-plugin/plugin.json
    skills/
      japanese-tech-writing/  日本語技術文書の文章規範
      argument-gap-edit/      論証の筋を点検・再配置する編集
  agent-collaboration/            plugin: エージェント協調(一部 shokai/agent-skills 由来・MIT)
    .claude-plugin/plugin.json
    skills/
      subagent-consultation/      サブエージェントへのセカンドオピニオン(往復検証)
      sanity-review/              対話コンテキスト込みの PR レビュー報告書(+ TEMPLATE.md)
      conversation-context-export/ 揮発層: 文脈の書き出し(.dev/contexts/ + PR コメント、+ TEMPLATE.md)
      conversation-context-import/ 揮発層: 文脈の読み込み
      durable-knowledge-export/   永続層: ブランチを越える知見を wiki/リポジトリ内 docs へ(自作、+ TEMPLATE.md)
      library-update-review/      依存更新 PR のレビュー
meta/
  empirical-prompt-tuning/        自作 skill の QA(第三者由来・非公開、下記)
rules/always-on.md   常時ルール(個人設定)。`~/.claude/CLAUDE.md`・`~/.codex/AGENTS.md` へ symlink する最小限の不変則
CLAUDE.md / AGENTS.md このリポジトリで作業するエージェント向けの repo-local 指示(配布しない。AGENTS.md は CLAUDE.md への symlink)
install.sh           symlink 配布スクリプト(home-manager を使わない場合)
flake.nix / nix/     home-manager モジュール(宣言的配布)
scripts/             CI 用の整合チェック(配布2系統の配布先一致 / plugin メタの一致)
```

### 常時ルール vs skill

- **常時ルール(`rules/always-on.md` → CLAUDE.md / AGENTS.md)**: 毎ターン読まれる。短い不変則だけ。
- **skill(`<plugin>/skills/<name>/SKILL.md`)**: `description` が今の作業に合致したときだけ読み込まれる。詳細手順はこちら。

### SKILL.md の言語(英語正本 + 日本語ミラー)

トークナイザは CJK を不利に扱うため、同内容なら英語の方が約 3 割トークンが少ない(実測は wiki [SKILL-token-ja-en](../../wiki/SKILL-token-ja-en) 参照)。
そこで **指示が中心で言語中立な skill は英語版 `SKILL.md` を正本** とし、日本語は保守ミラー `SKILL-ja.md` として併置する(agentがロードするのは `SKILL.md` のみ)。

- **英語正本 + `SKILL-ja.md`**:
  - `context-engineering`(`model-routing` / `fast-search` / `markdown-context` / `no-neologism`)
  - `agent-collaboration`(全 skill)、
  - `meta/empirical-prompt-tuning`。
- **日本語 `SKILL.md` のまま**:
  - `japanese-writing`(`japanese-tech-writing` /  `argument-gap-edit`)。規範の中身・例文が日本語前提のため。
- **`TEMPLATE.md` は日本語のまま**:
  - `agent-collaboration` の `sanity-review` / `conversation-context-export` / `durable-knowledge-export`。
  これは GitHub に貼る/wiki・docs に残す成果物の雛形(出力)であり、指示本体(`SKILL.md`)のみ英語化する。
  出力は利用者の作業言語に従う。
- 編集は英語 `SKILL.md` を正、`SKILL-ja.md` は手動で追従させる(内容の乖離に注意)。

### 出典とライセンス

- **japanese-writing**(`japanese-tech-writing` / `argument-gap-edit`):
  - [k16shikano の gist](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d)由来。
  - ライセンスは[実質 public domain](https://gist.github.com/k16shikano/67625f2a7d96e3bbdfae8d571a936063)。
- **agent-collaboration**
  - `subagent-consultation` / `sanity-review` / `conversation-context-export` / `conversation-context-import` / `library-update-review`は[shokai/agent-skills](https://github.com/shokai/agent-skills) 由来。
    - ライセンスは **MIT**、`LICENSE` 参照。
    - 英語化のうえ取り込んだ。
    - upstream の `codex-consultation`(Codex CLI 相談)は取り込んでいない。
    - `sanity-review` の外部 Agent 相談は `subagent-consultation` →(失敗時)main 単独の 2 段フォールバックに書き換えてある。
  - `agent-collaboration` の `durable-knowledge-export` は **自作**。
    - 揮発層(`conversation-context-export`)の対として、ブランチを越える永続知見を、あればGitHub wiki、無ければリポジトリ内 docs(`docs/knowledge/`)へ書き出す。
- **meta/empirical-prompt-tuning**:
  - [mizchi/skills](https://github.com/mizchi/skills/tree/main/meta/empirical-prompt-tuning)由来。
  - 同 repo の方針(README)で「`LICENSE.txt` の無い skill は MIT」とされるため **MIT** (`meta/empirical-prompt-tuning/LICENSE` に明記)。
  - **有効な `SKILL.md` は英語版**、日本語ミラーを `SKILL-ja.md` として併置(upstream と同様)。
  - 更新は upstream から取り直す。
  - 自作 skill を作った/直した直後の実測 QA に使う **個人用ツール** のため、`marketplace.json` には載せず home-manager / install.sh で自環境にだけ配布する。
  - 併置の `NOTES-local.md` は upstream を触らずに運用追補を置くローカルノート
    - [waxa-eval](https://github.com/mizchi/skills/tree/main/meta/waxa-eval)由来・MIT の知見を session 内ループ向けに書き直したもの。
    - waxa CLI 本体は未導入。

## 前提ツール

- [fastcontext](https://github.com/microsoft/fastcontext) — 広域・意味的探索。
  - OpenAI 互換 API がバックエンドで、環境変数 `API_KEY`(or `OPENAI_API_KEY`)/ `MODEL` / `BASE_URL` が要る(未設定だと `Missing credentials` で落ちる)。
  - 鍵はコミットせず各自設定する。
  - 未設定時は `fast-search` skill のフォールバック(Explore / Grep+Read)で代替。
- mdidx — Markdown を索引+節に変換。本リポジトリ同梱の Go 実装。
  - [oubakiou/md2idx](https://github.com/oubakiou/md2idx)(MIT)の忠実な再実装で、出力はバイト互換。Node ランタイム/npm 依存を持たない単一バイナリ。
  - 導入は次のいずれか。いずれも Nix が prebuilt の Go コンパイラを store に取得してビルドするため、システムへ go を入れる必要はない。
    - home-manager(`tools.enable = true`、既定で PATH へ自動配置)
    - `nix profile install .#mdidx`
    - `nix build .#mdidx`
    - devShell には自動で入る
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
| `rules.enable` | `true` | `rules/always-on.md` を `CLAUDE.md` / `AGENTS.md` として配布 |
| `agentDefs.enable` | `true` | `plugins/*/agents/*.md` を `~/.claude/agents` へ配布(Claude 固有) |
| `tools.enable` | `true` | mdidx バイナリを `home.packages` に入れて PATH へ通す(`markdown-context` 用) |

- skill の **追加・削除** の反映には flake 更新 + `home-manager switch` が要る
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
| rules/always-on.md | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | — |
| agents/*.md | `~/.claude/agents/` | (非対応) | — |

**反映には Claude Code / Codex の再起動が必要。**

## エージェントへの伝わり方

- **skill**: 3者とも同じ `SKILL.md`(frontmatter の `name` / `description`)形式。
  `description` の「いつ使うか」が自動ロードの判定に使われるので、用途を具体的に書く。
- **常時ルール**: Claude は `CLAUDE.md`、Codex は `AGENTS.md` を読む。どちらも配布元は `rules/always-on.md`。
- **モデル委譲**: agent 定義(`model:`)は Claude 固有。Claude はメインのモデルを自動切替
  できないため、`model-routing` skill に従い Task/Agent ツールで安価サブエージェントへ委譲する。
  Codex は本 skill の方針 + Codex 自身のモデル設定で同等を達成する。

## 新しい skill を足すとき

1. `plugins/<plugin>/skills/<name>/SKILL.md` を作る(frontmatter に `name` と具体的な `description`)。
2. 常時効かせたい最小限の不変則があれば `rules/always-on.md` に1行追記する。
3. 公開するなら `marketplace.json` の該当 plugin に含まれることを確認(skills/ 配下は自動検出)。
4. `home-manager switch`(または `bash install.sh`)で配布し、各エージェントを再起動する。
5. 重要 skill は `meta/empirical-prompt-tuning` で実測 QA を実施する。
