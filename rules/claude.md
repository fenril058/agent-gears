## Bash

- CI や background job の完了待ちは `Monitor` の until ループか `run_in_background` を使う。
- Bash では直前の `cd` を前提にせず、必要な `cd` と後続処理を同じ command 内で完結させる。

## ファイル編集

- 既存ファイルは、同じセッションで現在の内容を確認してから変更する。
- anthropics/claude-code#90450 の workaround として、変更対象のファイルは内容確認とは別に dedicated `Read` で一度開き、nested CLAUDE.md と path-scoped rules をロードする。
  auto mode の Bash 優先案内より、この `Read` を優先する。
  この要件は変更対象にだけ適用し、探索、検索、変更しないファイルの参照は Bash でよい。
