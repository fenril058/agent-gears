# Claude Code 専用の常時ルール

## worktree

- 指定した branch 名をそのまま使い、後続の統合手順もその branch を前提とする並列委譲では、`Agent` の `isolation: "worktree"` を直接選ばず、`worktrunk` skill の parallel sub-Agents 手順に従う。

## Codex への委譲

- 委譲を始める前に対象 worktree の絶対パスを確定し、ジョブの完了まで保持する。
- `codex:codex-rescue` に書き込み作業を委譲するときは、その絶対パスを依頼文の `--cwd` に指定する。
- reviewや診断でもtest、build、lint、再現commandを実行する可能性があれば、`codex:codex-rescue` に `--write` を指定する。
- 検証のためのwrite capabilityとtracked source fileの変更許可を区別し、修正を依頼していない場合はsourceを変更しないよう依頼文で制約する。
- `codex:codex-rescue` は依頼文から `--cwd` を取り除き、`codex-companion.mjs task --cwd <絶対パス>` の runtime option として渡す。
- Claude セッションの cwd と対象 worktree が同じだと仮定しない。

### 結果の取得

- `task`、`/codex:status`、`/codex:result` は、同じ委譲ジョブについて同じ worktree の cwd で実行する。
- main checkout から別の worktree に委譲した場合は、対象 worktree を cwd にして `/codex:status` と `/codex:result` を呼び出す。
- `task --cwd <worktree>` で作成したジョブは、その worktree に対応する workspace の state に保存される。別の cwd からは検索できない。

## Bash

- CI や background job の完了待ちは `Monitor` の until ループか `run_in_background` を使う。
  `sleep N; gh pr checks <n>` は harness が拒否する。
- Bash の cwd は呼び出し間で持続するが、直前の `cd` の結果を前提にしない。
  path は絶対で書くか、`cd` と後続をひとつの command 内で完結させる。

## ファイル編集

- 既存ファイルを変更する前に、同じセッションで変更対象の現在の内容を確認する。
  確認にどの手段を使うかは問わない。
  変更前に現在の内容を確認したかを問う。
- auto-memory の `MEMORY.md` も既存ファイルなので例外ではない。
