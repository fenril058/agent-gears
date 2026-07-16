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
- worktree 内を変更するときは、その worktree をカレントディレクトリまたは書き込み可能な workspace root にしてエージェントのセッションを開始する。
  別の worktree で開始済みのセッションから兄弟 worktree を変更しない。
  `wt` で作成しても、開始済みセッションの filesystem sandbox に兄弟 worktree は自動追加されない。
- 兄弟 worktree の読み取り専用レビューは既存セッションから行ってよい。
  編集、テスト、`direnv exec`、Git 操作が必要になったら、対象 worktree を書き込み可能な workspace root にしたセッションへ切り替える。
- サブエージェントを隔離環境で動かすときも、先に `wt` で worktree を作り、その worktree を書き込み可能な workspace root にして動かす。
  worktree の path をサブエージェントへ伝えるだけで書き込み可能になるとは仮定しない。

## Markdownの整形ルール

- 一文ごとに改行し、段落の区切りは空行で示す。
