# agent-gears

Claude Code・Codex・GitHub Copilot 共用の **skill / agent / 常時ルール** 一式。
Claude には plugin マーケットプレイスとして、Codex / Copilot には skill として、自分の環境には home-manager で配布できる。

このリポジトリは2つの性格を併せ持つ。
**公開する skill/agent(`plugins/`)** と、**個人のエージェント設定(`rules/` と、その symlink 配布の仕組み)** である。
前者はマーケットプレイスとして共有でき、後者は自分の `~/.claude` / `~/.codex` / `~/.copilot` を構成する。
マーケットプレイス名は `fenril058-agent-skills`(`marketplace.json` の `name`)である。

リポジトリ直下の `CLAUDE.md` / `AGENTS.md` はこの両者とは別で、このリポジトリ自体を編集するエージェントへの repo-local 指示である。
こちらは配布はされない。

## 内容

このリポジトリは、領域の異なるエージェント向け skill を1か所に束ねて配布する。
現在は6つの plugin があり、依存の向きで層になっている。

```
critique / project-records / code-review   ← ワークフロー層
        ↓                                    (基盤を呼ぶ)
context-engineering                        ← 基盤層
agent-instructions                         ← 指示テキスト自体を書き、測る
writing                                    ← 文章の規範(用語規則は全層から参照)
```

### context-engineering (基盤: どう読み・探し・委譲されるか)

運用コストの多くは、無駄な文脈の読み込みと、安価に回せる作業まで高いモデルで処理することから来る。

- markdown-context: mdidx で大きな Markdown の必要な節だけ取る。
- fast-search: fastcontext で広域・意味的な探索を少ないトークンで行う。
- model-routing: 機械的・量的な作業を安価モデルのサブエージェントへ回す。
- subagent-consultation: 判断を要する相談をサブエージェントに投げ、往復検証で精度を上げる。

後ろ2つは「作業を別のモデル/エージェントに回す」の両輪である。
機械的な作業は安価に、判断は強いモデルに、と適用範囲を互いに書き分けている。

### agent-instructions (指示テキスト自体を書き、測る)

- agent-instructions-refine: CLAUDE.md / AGENTS.md を圧縮する。コードから導出できる情報を削り、残りを検証可能な命令文に書き直す。
- empirical-prompt-tuning: 書いた指示をバイアスを排した実行者に動かさせ、自己申告と指示側メトリクスの両面で評価して反復する。

対で回す。片方が削り、もう片方が削った結果まだ機能するかを測る。

### critique (決める前に案を叩く)

- grilling: 計画・決定について一問ずつ推奨案付きでインタビューし、共通理解に達するまで実装に着手しない。固まった語と決定はその場で domain-modeling へ記録する。
- spec-ambiguity-audit: 安価モデルに仕様書を素読みさせて疑問点を挙げさせ、機械的フィルタで裏取りする。
- unconventional-simplification: 実装の裏の暗黙の前提を1つずつ外し、より少ない実装・説明で済む別解を探す。

いずれも計画を作る skill ではなく、既にある案・仕様・実装を攻撃する skill である。

### project-records (決めたことを寿命ごとに記録する)

- conversation-context-export/import: ブランチ単位で設計判断・却下理由・制約を引き継ぐ。
- domain-modeling: このコードベースの用語集 (`CONTEXT.md`) と ADR を保守する。
- durable-knowledge-export: ブランチを越えて残す知見を、リポジトリの外へ保存する。

#### 記録先の3層

会話で得たものをどこに書くかは、置き場所ではなく**更新モデル**で決まる。
どの skill も自分の層だけを規定し、他層の判定を写さずに渡す。

| 層 | skill | sink | 更新モデル |
| --- | --- | --- | --- |
| 揮発 | conversation-context-export/import | `.dev/contexts/` + PR コメント | ブランチごとに再生成。commit しない |
| 記録 | domain-modeling | `CONTEXT.md`、ADR ディレクトリ | 追記と supersede。書き換えない |
| 永続 | durable-knowledge-export | GitHub wiki / knowledge リポジトリ | living page。常に現在状態 |

記録層だけが「決めて後で覆した」を保存する。
living page に置いた決定はその履歴を失うため、ADR は永続層ではなく記録層に属する。
永続層はリポジトリの外に書く。使える sink が無ければ置き場所を作らずに中止する。

### code-review (出来上がったものを検める)

- sanity-review: 対話コンテキスト・PR 概要欄・実装コードの整合性つまり「実装者の正気」を点検する PR レビュー報告書を作成する。結果ではなくプロセスをレビューする。
- library-update-review: 依存更新 PR のレビューを行う。
- codepatrol: リポジトリのセキュリティ調査を領域ごとに進める。複数セッションにまたがる長期作業を `.dev/codepatrol/` の状態で継続する。

### writing (文章の規範)

- japanese-tech-writing: 日本語の技術文書・書籍原稿の整形・パラグラフライティング・論証の厳密さ・冗長の排除。
- argument-gap-edit: 論証の筋を点検し、段落を再配置する。
- no-neologism: 未定義語・勝手な造語を確立した術語へ直す。

前2つは日本語原稿向け、no-neologism は散文・コード・回答に共通で当てる。
`no-neologism` が扱うのは分野の術語であり、プロジェクト内部の語彙は `project-records` の `domain-modeling` が扱う。

## 構成

```
.claude-plugin/marketplace.json   Claude 用マーケットプレイス定義(plugin 一覧)
plugins/
  context-engineering/            plugin: 基盤(どう読み・探し・委譲されるか)
    .claude-plugin/plugin.json
    LICENSE                       shokai/agent-skills 由来 skill 用(MIT)
    skills/
      markdown-context/  大きな Markdown を mdidx で部分取得(主役)/ mq(補助)
      fast-search/       fastcontext での広域・意味的探索
      model-routing/     安価モデルのサブエージェントへの委譲ポリシー
      subagent-consultation/  サブエージェントへのセカンドオピニオン(往復検証)
    agents/
      search.md          コードベース探索・調査(Sonnet)
      bulk-edit.md       機械的・反復的な編集(Haiku)
  agent-instructions/             plugin: 指示テキスト自体を書き、測る
    .claude-plugin/plugin.json
    skills/
      agent-instructions-refine/  CLAUDE.md/AGENTS.md 等の指示ファイルを推敲
      empirical-prompt-tuning/    指示の実測 QA ループ(mizchi/skills 由来・MIT)
  critique/                       plugin: 決める前に案を叩く
    .claude-plugin/plugin.json
    LICENSE                       shokai/agent-skills 由来 skill 用(MIT)
    skills/
      grilling/          一問ずつ推奨案付きの意思決定インタビュー(mattpocock/skills 由来・MIT)
      spec-ambiguity-audit/  安価モデルに仕様書を素読みさせ、疑問点を機械的フィルタで検証する監査
      unconventional-simplification/ 暗黙の前提を1つずつ外してシンプルな別解を探す
  project-records/                plugin: 決めたことを寿命ごとに記録する
    .claude-plugin/plugin.json
    LICENSE                       shokai/agent-skills 由来 skill 用(MIT)
    skills/
      conversation-context-export/ 揮発層: 文脈の書き出し(.dev/contexts/ + PR コメント、+ TEMPLATE.md)
      conversation-context-import/ 揮発層: 文脈の読み込み
      domain-modeling/            記録層: 用語集と ADR(mattpocock/skills 由来・MIT、+ CONTEXT-FORMAT.md / ADR-FORMAT.md)
      durable-knowledge-export/   永続層: ブランチを越える知見をリポジトリ外へ(自作、+ TEMPLATE.md)
  code-review/                    plugin: 出来上がったものを検める(shokai/agent-skills 由来・MIT)
    .claude-plugin/plugin.json
    LICENSE
    skills/
      sanity-review/              対話コンテキスト込みの PR レビュー報告書(+ TEMPLATE.md)
      library-update-review/      依存更新 PR のレビュー
      codepatrol/                 領域ごとのセキュリティ調査(+ CHECKLIST.md / REPORT-TEMPLATE.md / checklist-vs-report.md)
  writing/                        plugin: 文章の規範(一部 k16shikano の gist 由来・public domain)
    .claude-plugin/plugin.json
    NOTICE
    skills/
      japanese-tech-writing/  日本語技術文書の文章規範
      argument-gap-edit/      論証の筋を点検・再配置する編集
      no-neologism/           未定義語・造語の点検手順(核ルールは rules/always-on.md)
rules/always-on.md   全エージェント共通の常時ルール(個人設定)
rules/claude.md      Claude Code 専用の常時ルール。`~/.claude/rules/agent-gears.md` へ配布
CLAUDE.md / AGENTS.md このリポジトリで作業するエージェント向けの repo-local 指示(配布しない。AGENTS.md は CLAUDE.md への symlink)
install.sh           symlink 配布スクリプト(home-manager を使わない場合)
flake.nix / nix/     home-manager モジュール・mdidx/skills-ref のビルド定義(宣言的配布)
cmd/mdidx/           同梱の mdidx(Markdown 索引化)の Go 実装ソース
PROVENANCE.json      外部由来 skill の出所と帰属表示ファイルの置き場所(唯一の宣言元)
scripts/             CI 用の整合チェック(配布2系統の配布先一致 / plugin メタの一致 / 帰属表示の配置 / skills-ref による SKILL.md 仕様検証)
```

### 常時ルール vs skill

- **共通の常時ルール(`rules/always-on.md`)**: 各エージェントの instruction file として毎ターン読まれる短い不変則だけ。
- **エージェント固有の常時ルール(`rules/<agent>.md`)**: 対応するエージェントだけが毎ターン読む短い不変則だけ。
- **skill(`<plugin>/skills/<name>/SKILL.md`)**: `description` が今の作業に合致したときだけ読み込まれる。詳細手順はこちら。

### SKILL.md の言語(英語正本 + 日本語ミラー)

トークナイザは CJK を不利に扱うため、同内容なら英語の方が約 3 割トークンが少ない(実測は wiki [SKILL-token-ja-en](../../wiki/SKILL-token-ja-en) 参照)。
そこで **指示が中心で言語中立な skill は英語版 `SKILL.md` を正本** とし、日本語は保守ミラー `SKILL-ja.md` として併置する(agentがロードするのは `SKILL.md` のみ)。

- **英語正本 + `SKILL-ja.md`**:
  - `writing` の `no-neologism` を含む、下記以外のすべて。
- **日本語 `SKILL.md` のまま**:
  - `writing` の `japanese-tech-writing` / `argument-gap-edit`。規範の中身・例文が日本語前提のため。
- **`TEMPLATE.md` は日本語のまま**:
  - `code-review` の `sanity-review`、`project-records` の `conversation-context-export` / `durable-knowledge-export`。
  - `codepatrol` の付属ファイル(`CHECKLIST.md` / `REPORT-TEMPLATE.md` / `checklist-vs-report.md`)も同様に日本語のまま。
  これは GitHub に貼る/wiki・docs に残す成果物の雛形(出力)であり、指示本体(`SKILL.md`)のみ英語化する。
  出力は利用者の作業言語に従う。
- 編集は英語 `SKILL.md` を正、`SKILL-ja.md` は手動で追従させる(内容の乖離に注意)。

### agentskills.io 標準への準拠

skill の配置と `SKILL.md` frontmatter は [agentskills.io のオープン標準](https://agentskills.io/specification)に準拠する。
公式リファレンスバリデータ `skills-ref` で CI(`scripts/check-skill-spec.sh`)が検証する。

**標準に従う部分**:

- 各 skill を1ディレクトリ = 1 `SKILL.md` で置く。
- frontmatter の必須フィールド `name` / `description`(名前・説明の制約、`name` とディレクトリ名の一致)。
- `compatibility`(外部ツール要件の宣言)も標準フィールド。

**標準から外れる部分**:

- Claude Code のトップレベル拡張フィールド(本リポジトリでは `argument-hint`)は agentskills 標準外。
  Claude Code が解釈する拡張であり、`skills-ref` は本来これを "Unexpected fields" として弾く。
  この配布物の主対象は Claude Code なので、`check-skill-spec.sh` は既知の Claude 拡張(`CLAUDE_EXT`)だけを許容に読み替える(未知フィールドや `name`/`description` 違反は失格のまま)。
- 付随ファイル `SKILL-ja.md` / `TEMPLATE.md` / `NOTES-local.md` は標準の対象外。
  正本は `SKILL.md` のみで、バリデータもこれらを検証しない。

### 出典とライセンス

リポジトリ全体および自作物は **MIT**(`LICENSE`)。
第三者由来の skill は各自の条項(いずれも MIT / public domain で互換)に従う。
人間向けの一覧は `NOTICE`、機械可読な宣言元は `PROVENANCE.json` で、後者から組み立てた
「あるべき `LICENSE` / `NOTICE` の集合」と実ファイルの一致を CI(`scripts/check-licenses.sh`)が検証する。
plugin 単位の `LICENSE` は複数 plugin に分散するため、複製漏れも移動後の残骸も同じ差分で捕まる。

- **writing**(`japanese-tech-writing` / `argument-gap-edit`):
  - [k16shikano の gist](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d)由来。
  - ライセンスは[実質 public domain](https://gist.github.com/k16shikano/67625f2a7d96e3bbdfae8d571a936063)。
- **shokai/agent-skills 由来**(`context-engineering` の `subagent-consultation`、`code-review` の `sanity-review` / `library-update-review` / `codepatrol`、`critique` の `unconventional-simplification`、`project-records` の `conversation-context-export` / `conversation-context-import`):
  - [shokai/agent-skills](https://github.com/shokai/agent-skills) 由来。
    - ライセンスは **MIT**。該当 skill を持つ plugin それぞれの `LICENSE` に複製してある。
    - 英語化のうえ取り込んだ。
    - upstream の `codex-consultation`(Codex CLI 相談)は取り込んでいない。
      Codex は独立した skill ではなく `subagent-consultation` が選ぶ相談先の一つとして扱う(Claude Code では `subagent_type: codex:codex-rescue`)。
      相談プロトコルを二重に持たずに済み、呼び出し側は相談先を知らなくてよい。
    - `sanity-review` の外部 Agent 相談は `subagent-consultation` →(失敗時)main 単独の 2 段フォールバックに書き換えてある。
      相談先の種類(別モデルファミリか同ファミリか)は手順ごとに `Args:` で指定する。
    - `unconventional-simplification` / `codepatrol` の外部 Agent 相談も `codex-consultation` を外し `subagent-consultation` に書き換えてある。
    - `codepatrol` は Cosense 連携を外し、レポート書き出し先をローカル(`.dev/codepatrol/`)専用にしてある。
- **mattpocock/skills 由来**:
  - `critique` の `grilling`。
    - ライセンスは **MIT**、`plugins/critique/skills/grilling/LICENSE` 参照。
    - 上流は英語のみのため英語正本のまま取り込み、日本語ミラー `SKILL-ja.md` を追加した。
    - 上流の `grill-with-docs`(本文は「`/grilling` を `/domain-modeling` を使って走らせる」の一行)は取り込まず、
      同じ合成を `grilling` 本体の「固まった端から記録する」規律として持たせてある。
  - `project-records` の `domain-modeling`。
    - ライセンスは **MIT**、`plugins/project-records/skills/domain-modeling/LICENSE` 参照。
    - ADR ディレクトリを上流の `docs/adr/` 決め打ちから解決式に変更した(既存リポジトリの慣習・`.adr-dir` 等を探す)。
    - supersede 規則、3層の振り分け、`no-neologism` との分担を追記した。
- `project-records` の `durable-knowledge-export` は **自作**。
    - 揮発層(`conversation-context-export`)・記録層(`domain-modeling`)の対として、
      ブランチを越える永続知見を**リポジトリの外**(GitHub wiki、または `AGENT_KNOWLEDGE_REPO` が指す knowledge リポジトリ)へ書き出す。
- **mizchi/skills 由来**(`agent-instructions` の `empirical-prompt-tuning`):
  - [mizchi/skills](https://github.com/mizchi/skills/tree/main/meta/empirical-prompt-tuning)由来。
  - 同 repo の方針(README)で「`LICENSE.txt` の無い skill は MIT」とされるため **MIT**(同 skill の `LICENSE` に明記)。
  - **有効な `SKILL.md` は英語版**、日本語ミラーを `SKILL-ja.md` として併置(upstream と同様)。
  - MIT なので取り込んで改変する方針に変えた(上流を取り直さない)。
    これに伴い、上流の運用追補を置いていた `NOTES-local.md` は `SKILL.md` / `SKILL-ja.md` へ畳んで削除し、
    上流生成の `README.md`(中身は上流からのインストール手順)も削除した。
    畳んだ内容には [waxa-eval](https://github.com/mizchi/skills/tree/main/meta/waxa-eval)(MIT)由来の知見を
    session 内ループ向けに書き直したものを含む。waxa CLI 本体は未導入。

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
GitHub Copilot 向けには専用のマーケットプレイス経路はなく、home-manager(経路3)または install.sh が `~/.copilot/skills/` へ配布する。

### 1. Claude — plugin マーケットプレイス

```
/plugin marketplace add fenril058/agent-gears
/plugin install context-engineering@fenril058-agent-skills
/plugin install agent-instructions@fenril058-agent-skills
/plugin install critique@fenril058-agent-skills
/plugin install project-records@fenril058-agent-skills
/plugin install code-review@fenril058-agent-skills
/plugin install writing@fenril058-agent-skills
```

plugin 内の `skills/` と `agents/` が自動で読み込まれる。

### 2. Codex — skill-installer

Codex の `skill-installer` で GitHub の skill ディレクトリを `~/.agents/skills` へ導入する。

```
install-skill-from-github.py --repo fenril058/agent-gears --path plugins/context-engineering/skills/markdown-context
```

(`agents/` は Claude 固有のため Codex では扱わない。)

### 3. 自分の環境 — home-manager(クロスエージェント宣言配布)

skills/agents/常時ルールを `~/.claude`・`~/.agents`・`~/.codex`・`~/.copilot` へ一括 symlink する。
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
| `codex.enable` | `true` | `~/.agents/skills` と `~/.codex/AGENTS.md` へ Codex 向けファイルを配布 |
| `copilot.enable` | `true` | `~/.copilot` へ配布(GitHub Copilot) |
| `rules.enable` | `true` | 共通ルールとエージェント固有ルールを対応する instruction file として配布 |
| `agentDefs.enable` | `true` | `plugins/*/agents/*.md` を `~/.claude/agents` へ配布(Claude 固有) |
| `tools.enable` | `true` | mdidx バイナリを `home.packages` に入れて PATH へ通す(`markdown-context` 用) |

- skill の **追加・削除** の反映には flake 更新 + `home-manager switch` が要る
  (配布対象は flake ソースから列挙)。既存 skill の編集は `mutable = true` なら即反映。
- 配布対象は `plugins/*/skills/*`・`plugins/*/agents/*`。

### 4. home-manager を使わない場合 — install.sh

```bash
bash install.sh --dry-run   # 張る予定を確認
bash install.sh             # 実行(冪等。実ファイルは .bak.<時刻> に退避)
bash install.sh --uninstall # このリポジトリを指す symlink だけ外す
```

配布先:

| 対象 | Claude Code | Codex | GitHub Copilot |
|------|-------------|-------|----------------|
| 各 skill | `~/.claude/skills/` | `~/.agents/skills/` | `~/.copilot/skills/` |
| rules/always-on.md | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.copilot/copilot-instructions.md` |
| rules/claude.md | `~/.claude/rules/agent-gears.md` | — | — |
| agents/*.md | `~/.claude/agents/` | (非対応) | (非対応) |

**反映には Claude Code / Codex / Copilot の再起動が必要。**

## エージェントへの伝わり方

- **skill**: 3者とも同じ `SKILL.md`(frontmatter の `name` / `description`)形式。
  `description` の「いつ使うか」が自動ロードの判定に使われるので、用途を具体的に書く。
- **共通の常時ルール**: Claude は `CLAUDE.md`、Codex は `AGENTS.md`、Copilot は `copilot-instructions.md` を読む。いずれも配布元は `rules/always-on.md`。
- **Claude 専用の常時ルール**: Claude はユーザールール `~/.claude/rules/agent-gears.md` も読む。配布元は `rules/claude.md`。
- **モデル委譲**: agent 定義(`model:`)は Claude 固有。Claude はメインのモデルを自動切替
  できないため、`model-routing` skill に従い Task/Agent ツールで安価サブエージェントへ委譲する。
  Codex は本 skill の方針 + Codex 自身のモデル設定で同等を達成する。

## 新しい skill を足すとき

1. どの plugin に置くか決める。判定基準は分類の綺麗さではなく**インストール単位**である。
   「これだけ欲しくて他は要らない人がいるか」で決める。
2. `plugins/<plugin>/skills/<name>/SKILL.md` を作る(frontmatter に `name` と具体的な `description`)。
   英語を正本とし、日本語ミラー `SKILL-ja.md` を併置する(例外は「SKILL.md の言語」節)。
3. **外部から取り込んだ skill なら** `PROVENANCE.json` に追記し、帰属表示ファイルを置く。
   `scope` が `plugin` なら `plugins/<plugin>/LICENSE`、`skill` なら skill ディレクトリ直下。
   直下の `NOTICE` にも出所を書く。`scripts/check-licenses.sh` が両方を検証する。
4. 常時効かせたい最小限の不変則があれば、共通なら `rules/always-on.md`、Claude Code 固有なら `rules/claude.md` に1行追記する。
5. 公開するなら `marketplace.json` の該当 plugin に含まれることを確認(skills/ 配下は自動検出)。
   plugin を新設したなら `marketplace.json` と `plugins/<plugin>/.claude-plugin/plugin.json` の両方に書く
   (`name` / `version` / `keywords` の一致を `scripts/check-plugin-meta.sh` が検証する)。
6. `home-manager switch`(または `bash install.sh`)で配布し、各エージェントを再起動する。
7. 重要 skill は `empirical-prompt-tuning` で実測 QA を実施する。
