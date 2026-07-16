# Claude Code 専用の常時ルール

## Codex への委譲

- 委譲を始める前に対象 worktree の絶対パスを確定し、ジョブの完了まで保持する。
- `codex:codex-rescue` に書き込み作業を委譲するときは、その絶対パスを依頼文の `--cwd` に指定する。
- `codex:codex-rescue` は依頼文から `--cwd` を取り除き、`codex-companion.mjs task --cwd <絶対パス>` の runtime option として渡す。
- Claude セッションの cwd と対象 worktree が同じだと仮定しない。

### 結果の取得

- `task`、`/codex:status`、`/codex:result` は、同じ委譲ジョブについて同じ worktree の cwd で実行する。
- main checkout から別の worktree に委譲した場合は、対象 worktree を cwd にして `/codex:status` と `/codex:result` を呼び出す。
- `task --cwd <worktree>` で作成したジョブは、その worktree に対応する workspace の state に保存される。別の cwd からは検索できない。
