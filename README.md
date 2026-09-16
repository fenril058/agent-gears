# agent-gears

Claude Code・Codex・GitHub Copilot で共用する agent skill と常時ルールのリポジトリ。

公開する skill は `plugins/agent-gears/` の単一 plugin にまとめ、個人環境へ配布する常時ルールは `rules/` に置く。
Markdown の必要な節だけを取得する CLI `mdidx` も同梱する。

リポジトリ直下の `AGENTS.md` は、このリポジトリ自体を編集する agent 向けの repo-local instruction であり、配布対象ではない。

## 構成

| Path | 役割 |
| --- | --- |
| [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) | Claude Code plugin marketplace の定義 |
| [`plugins/agent-gears/`](plugins/agent-gears/) | 配布する単一 plugin |
| [`plugins/agent-gears/skills/`](plugins/agent-gears/skills/) | 公開する skill |
| [`plugins/agent-gears/README.md`](plugins/agent-gears/README.md) | plugin 固有の利用ガイド |
| [`rules/always-on.md`](rules/always-on.md) | Claude Code・Codex・GitHub Copilot 共通の常時ルール |
| [`rules/claude.md`](rules/claude.md) | Claude Code 固有の常時ルール |
| [`install.sh`](install.sh) | symlink による命令的な配布 |
| [`nix/hm-module.nix`](nix/hm-module.nix) | home-manager による宣言的な配布 |
| [`cmd/mdidx/`](cmd/mdidx/) | `mdidx` の Go 実装 |
| [`docs/adr/`](docs/adr/) | このリポジトリの設計判断 |
| [`PROVENANCE.json`](PROVENANCE.json) | 外部由来 skill の機械可読な出典情報 |
| [`NOTICE`](NOTICE) | 外部由来 skill の人間向け出典表示 |

現在の plugin は skill のみを含み、custom agent 定義は同梱していない。

### 常時ルール vs skill

常時ルールは対応する agent の instruction file として毎ターン読み込まれる不変則である。
skill は `SKILL.md` の `description` が作業に合致したときに読み込まれ、個別の手順を提供する。
各 skill の runtime contract は、その skill の `SKILL.md` を正本とする。

### SKILL.md の言語

言語に依存しない skill は英語の `SKILL.md` を正本とし、日本語ミラーの `SKILL-ja.md` を併置する。
`japanese-tech-writing` と `argument-gap-edit` は日本語の `SKILL.md` が正本である。
成果物用の template と codepatrol の付属文書は日本語のまま保持する。

`SKILL.md` の配置と frontmatter は [agentskills.io specification](https://agentskills.io/specification) に準拠し、CI では公式 `skills-ref` を使って検証する。

## Skills

利用条件と手順は、各リンク先の `description` と本文を参照する。

|  |  |  |
| --- | --- | --- |
| [agent-instructions-refine](plugins/agent-gears/skills/agent-instructions-refine/SKILL.md) | [argument-gap-edit](plugins/agent-gears/skills/argument-gap-edit/SKILL.md) | [codepatrol](plugins/agent-gears/skills/codepatrol/SKILL.md) |
| [codex-consultation](plugins/agent-gears/skills/codex-consultation/SKILL.md) | [conversation-context-export](plugins/agent-gears/skills/conversation-context-export/SKILL.md) | [conversation-context-import](plugins/agent-gears/skills/conversation-context-import/SKILL.md) |
| [domain-modeling](plugins/agent-gears/skills/domain-modeling/SKILL.md) | [durable-knowledge-export](plugins/agent-gears/skills/durable-knowledge-export/SKILL.md) | [empirical-prompt-tuning](plugins/agent-gears/skills/empirical-prompt-tuning/SKILL.md) |
| [grilling](plugins/agent-gears/skills/grilling/SKILL.md) | [japanese-tech-writing](plugins/agent-gears/skills/japanese-tech-writing/SKILL.md) | [library-update-review](plugins/agent-gears/skills/library-update-review/SKILL.md) |
| [markdown-context](plugins/agent-gears/skills/markdown-context/SKILL.md) | [navigating](plugins/agent-gears/skills/navigating/SKILL.md) | [quizzing](plugins/agent-gears/skills/quizzing/SKILL.md) |
| [sanity-review](plugins/agent-gears/skills/sanity-review/SKILL.md) | [spec-ambiguity-audit](plugins/agent-gears/skills/spec-ambiguity-audit/SKILL.md) | [subagent-consultation](plugins/agent-gears/skills/subagent-consultation/SKILL.md) |
| [unconventional-simplification](plugins/agent-gears/skills/unconventional-simplification/SKILL.md) |  |  |

`codex-consultation`、`sanity-review`、`codepatrol` の利用上の補足は [plugin README](plugins/agent-gears/README.md) に置く。

## 配布方法

### Claude Code plugin marketplace

```text
/plugin marketplace add fenril058/agent-gears
/plugin install agent-gears@fenril058-agent-skills
```

Claude Code は plugin 内の `skills/` を読み込む。

### Codex skill-installer

Codex では `skill-installer` に [`plugins/agent-gears/skills/`](plugins/agent-gears/skills/) 内の必要な skill ディレクトリを指定する。

### home-manager

全 skill、常時ルール、`mdidx` をまとめて配布する場合は home-manager module を使う。

```nix
{
  inputs.agent-gears.url = "github:fenril058/agent-gears";

  imports = [ inputs.agent-gears.homeManagerModules.default ];

  programs.agent-gears = {
    enable = true;
    repoPath = "/absolute/path/to/agent-gears";
  };
}
```

既定の `mutable = true` では `repoPath` の作業ツリーへ symlink する。
store 内の flake source を直接配布する場合は `mutable = false` を指定する。
利用可能な option と配布先の正本は [`nix/hm-module.nix`](nix/hm-module.nix) を参照する。

### install.sh

home-manager を使わない場合は、skill と常時ルールを symlink する。

```bash
bash install.sh --dry-run
bash install.sh
bash install.sh --uninstall
```

skill は `~/.claude/skills/`、`~/.agents/skills/`、`~/.copilot/skills/` へ配布する。
常時ルールは Claude Code・Codex・GitHub Copilot の各 instruction file へ配布する。
通常実行と `--uninstall` は、このリポジトリが管理する obsolete または dangling な symlink も整理する。

## 同梱ツール

`mdidx` は Markdown を見出し索引と節へ変換し、`markdown-context` skill が必要な節だけを取得するために使う。

```bash
nix profile install github:fenril058/agent-gears#mdidx
```

リポジトリ内では `nix build .#mdidx` または `nix develop` でも利用できる。
CLI の使い方は [`markdown-context/SKILL.md`](plugins/agent-gears/skills/markdown-context/SKILL.md) を参照する。

## Documentation

| 知りたいこと | 正本 |
| --- | --- |
| skill の起動条件と実行手順 | 各 [`skills/*/SKILL.md`](plugins/agent-gears/skills/) |
| plugin 固有の利用上の補足 | [`plugins/agent-gears/README.md`](plugins/agent-gears/README.md) |
| このリポジトリを編集する際の規則 | [`AGENTS.md`](AGENTS.md) |
| 設計判断 | [`docs/adr/`](docs/adr/) |
| sanity-review の revision-isolation canary | [`docs/sanity-review-revision-isolation-canary.md`](docs/sanity-review-revision-isolation-canary.md) |
| Claude Code の instruction loading canary と暫定回避 | [`docs/claude-code-instruction-loading.md`](docs/claude-code-instruction-loading.md) |
| 外部由来 skill の出典と許諾 | [`PROVENANCE.json`](PROVENANCE.json)、[`NOTICE`](NOTICE)、[`plugins/agent-gears/LICENSE`](plugins/agent-gears/LICENSE)、[`plugins/agent-gears/NOTICE`](plugins/agent-gears/NOTICE) |
| 脆弱性の報告方法 | [`SECURITY.md`](SECURITY.md) |

## 既知の上流不具合と暫定回避（Claude Code）

Claude Code が file 操作を Bash-first にすると、nested `CLAUDE.md` と path-scoped rules が読み込まれない場合がある。
このリポジトリは、変更対象を dedicated `Read` で一度開く暫定 compatibility rule を [`rules/claude.md`](rules/claude.md) から配布する。

`CLAUDE_CODE_THRIFTY_SONIC=0` による回避も限定条件で確認しているが、これは documented user-facing setting ではなく、agent-gears が自動設定する値でもない。
再現条件、canary、設定例、撤去条件は [`docs/claude-code-instruction-loading.md`](docs/claude-code-instruction-loading.md) を参照する。
上流の追跡先は [anthropics/claude-code#90450](https://github.com/anthropics/claude-code/issues/90450) である。

## 新しい skill を足すとき

1. `plugins/agent-gears/skills/<name>/SKILL.md` を追加する。
2. 英語正本の skill には `SKILL-ja.md` を追加し、以後も手動で同期する。
3. 外部由来なら `PROVENANCE.json` と必要な `LICENSE` / `NOTICE` を更新する。
4. skill はディレクトリ構成から自動列挙されるため、配布スクリプトへ名前を追加しない。
5. `nix fmt` と `nix flake check` を実行する。

frontmatter、帰属表示、配布、plugin metadata の詳細な更新規則は [`AGENTS.md`](AGENTS.md) を参照する。

## License

リポジトリ全体と自作物は [MIT License](LICENSE) で提供する。
第三者由来の skill は、それぞれの許諾と [`PROVENANCE.json`](PROVENANCE.json) の宣言に従う。
