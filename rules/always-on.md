# 常時ルール (context-engineering)

全エージェント共通の不変則。詳細手順は各項目が指す skill 側にある。

## 用語

- 定義していない用語や勝手な造語を導入しない。その分野で確立した術語を使う。
  新語が必要なら初出で定義する。詳細点検は `no-neologism` skill。

## 文脈効率(トークン削減)

- 大きな Markdown を理由なく全文読みしない。索引から必要な節だけ取る(`markdown-context` skill / `mdidx`)。
- コードベースの広域・意味的な探索は全文 Grep の総当たりでなく `fastcontext`(`fast-search` skill)。
- 重くないが量の多い作業（機械的編集・反復・広域探索）は、安価モデルのサブエージェントへ委譲する（`model-routing` skill）。
  設計・判断・レビューはメインモデルに残し、委譲オーバーヘッドが見合わない小規模作業はそのまま処理する

## リポジトリ配置 (ghq)

- GitHub 等の clone は ghq 管理下に置く(`~/ghq/<host>/<owner>/<repo>`)。
- ただし `<owner>/<repo>` は **`ghq get` した URL** で決まり、現在の `origin` とは一致しないことがある。
  upstream を ghq get した後に origin を fork へ張り替えた fork では、ディレクトリは upstream owner のまま(例: `~/ghq/github.com/emacs-twist/twist.nix` の origin は `fenril058/twist.nix`)。
- よって path を `origin` から推測しない。実 path は `ghq list --full-path <repo>` で確認する。

## worktree(エージェント隔離)

- worktree は必ず `wt`(worktrunk)で作る。`wt switch --create <branch>` を使う。
- `wt` を経由しない worktree は使わない。post-start hook が走らず、gitignored の symlink 化・`direnv allow` が済まないため、direnv/依存の無い壊れた作業ツリーになり、ビルド・テストが通らない。
- サブエージェントを隔離環境で動かすときも、先に `wt` で作った worktree の中で動かす。
