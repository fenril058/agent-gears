# Claude Code 専用の常時ルール

## Codex への委譲

- `codex:codex-rescue` に書き込み作業を委譲するときは、対象 worktree の絶対パスを依頼文の `--cwd` に指定する。
- `codex:codex-rescue` は依頼文から `--cwd` を取り除き、`codex-companion.mjs task --cwd <絶対パス>` の runtime option として渡す。
- Claude セッションの cwd と対象 worktree が同じだと仮定しない。
- 対象 worktree を確定できない場合は、Codex を起動する前に確定する。
