# Claude Code 専用の常時ルール

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

## path に紐づく指示のロード(上流不具合の暫定回避)

- 上の内容確認とは別の要件として、変更対象の path に適用される nested `CLAUDE.md` と path-scoped rules を context にロードする。
- 現行の Claude Code は、このロードを dedicated `Read` を通した読み取りでしか行わない。
  Bash の `cat` / `sed` / `grep` で読んでも内容は得られるが、その path の指示はロードされない。
  よってファイルを変更する前に、そのファイルを一度 `Read` で開く。
  auto mode の Bash 優先案内より、この `Read` を優先する。
- 読み取り全般を `Read` に固定する規則ではない。
  探索、検索、実行結果の確認、変更しないファイルの参照は Bash のままでよい。
- この節は https://github.com/anthropics/claude-code/issues/90450 が未解決である間だけの暫定規則で、修正を再現確認したら撤去する。
