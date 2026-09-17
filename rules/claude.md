## Bash

- CI や background job の完了待ちは `Monitor` の until ループか `run_in_background` を使う。
- Bash では直前の `cd` を前提にせず、必要な `cd` と後続処理を同じ command 内で完結させる。

## ファイル編集

- 既存ファイルは、同じセッションで現在の内容を確認してから変更する。

## path に紐づく指示のロード(上流不具合の暫定回避)

- 上の内容確認とは別の要件として、変更対象の path に適用される nested `CLAUDE.md` と path-scoped rules を context にロードする。
- 現行の Claude Code は、このロードを dedicated `Read` を通した読み取りでしか行わない。
  Bash の `cat` / `sed` / `grep` で読んでも内容は得られるが、その path の指示はロードされない。
  よってファイルを変更する前に、そのファイルを一度 `Read` で開く。
  auto mode の Bash 優先案内より、この `Read` を優先する。
- 読み取り全般を `Read` に固定する規則ではない。
  探索、検索、実行結果の確認、変更しないファイルの参照は Bash のままでよい。
- この節は https://github.com/anthropics/claude-code/issues/90450 が未解決である間だけの暫定規則で、修正を再現確認したら撤去する。
