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

- worktree は原則として `wt`(worktrunk)で作成する。新規作成には `wt switch --create <branch>` を使う。
- `wt` を経由せず作成された worktree では、post-start hook、gitignored ファイルの symlink 化、`direnv allow`、依存関係の準備が完了していない可能性がある。その状態で実装、ビルド、テスト、`direnv exec` を行わない。
- 実装ファイルを変更する場合は、対象 worktree をカレントディレクトリ、または書き込み可能な workspace root としてエージェントのセッションを開始する。
- 別の worktree で開始済みのセッションから、兄弟 worktree に対する実装変更、ビルド、テスト、`direnv exec`、Git 操作を行わない。
- 兄弟 worktree の読み取り専用レビューは、既存セッションから行ってよい。
- 次の条件をすべて満たす場合に限り、既存セッションから兄弟 worktree への限定的な書き込みを許可できる。

  - 対象 worktree が filesystem sandbox の書き込み可能範囲に明示的に追加されている。
  - 書き込み対象のディレクトリまたはファイルが明示されている。
  - 実装変更、ビルド、テスト、`direnv exec`、Git 操作を行わない。
  - ユーザーが今回限りの例外として明示的に許可している。

- 限定的な書き込みの例として、`.dev/contexts/` への context export や、作業引き継ぎ用メタデータの保存を認める。
- サブエージェントに実装作業を行わせる場合も、先に `wt` で worktree を作成し、その worktree を書き込み可能な workspace root として開始する。worktree の path を伝えるだけで書き込み可能になるとは仮定しない。

## Markdownの整形ルール

- 一文ごとに改行し、段落の区切りは空行で示す。
