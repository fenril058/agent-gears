# 常時ルール (context-engineering)

全エージェント共通の不変則。詳細手順は各項目が指す skill 側にある。

## 用語

- 定義していない用語や勝手な造語を導入しない。
  その分野で確立した術語を使う。
  新語が必要なら初出で定義する。
  詳細点検は `no-neologism` skill。

## 文脈効率(トークン削減)

- 大きな Markdown を理由なく全文読みしない。
  索引から必要な節だけ取る(`markdown-context` skill / `mdidx`)。
- コードベースの広域・意味的な探索は全文 Grep の総当たりでなく `fastcontext`(`fast-search` skill)。
- 重くないが量の多い作業(機械的編集・反復・広域探索)は、安価モデルのサブエージェントへ委譲する(`model-routing` skill)。
  設計・判断・レビューはメインモデルに残し、委譲オーバーヘッドが見合わない小規模作業はそのまま処理する。

## 検証

- 修正に付けるテストは、**修正前のコードに対して落ちること**を確認してから採用する。
  修正後に通ることだけを見ても、そのテストがバグを捉えている保証はない。
  「危険な副作用が起きなかった」形の表明は、その副作用が別の理由で最初から起きない場合に無意味に通る。
  argv、ファイル内容、同時実行数など、バグが実際に変える値を assert する。
- 「些細」「軽い」という見積もりは、**それを反証する最小の実験を 1 つ走らせてから**受け入れる。
  外れるときは重い側に外れる。
  調査で前提が変わったなら、着手前に報告して方針を確認する。
- 自分の一次調査の結論も、断定する前に裏を取る。
  grep の断片だけを見て「記載なし」と結論する類の誤りに注意する。
- 「不可能だから対処しない」と書く前に、本当に不可能かを確認する。
  多くは「移植性がない」「割に合わない」であって不可能ではない。
  とくにセキュリティ文書で不可能性を誇張すると、塞げたはずの人を追い返す。

## Git 操作

- 「rebase 済み」「最新に追従済み」と述べる前に `git merge-base --is-ancestor origin/main HEAD` で確認する。
  PR を web/API 経由で merge するとローカルの `main` は即座に古くなるため、ローカル `main` との比較では判定できない。

## リポジトリ配置 (ghq)

- GitHub 等の clone は ghq 管理下に置く(`~/ghq/<host>/<owner>/<repo>`)。
- ただし `<owner>/<repo>` は **`ghq get` した URL** で決まり、現在の `origin` とは一致しないことがある。
  upstream を ghq get した後に origin を fork へ張り替えた fork では、ディレクトリは upstream owner のまま(例: `~/ghq/github.com/emacs-twist/twist.nix` の origin は `fenril058/twist.nix`)。
- よって path を `origin` から推測しない。実 path は `ghq list --full-path <repo>` で確認する。

## worktree(エージェント隔離)

- worktree は並列作業(複数セッション/エージェントの同時進行)を意図するときだけ使う。
  worktree はセッション分割によるcontext断絶と人間の切り替えの手間を伴うため、並列を意図しない単発作業ではメインの checkout で `git switch`/`git checkout` して branch を切り替える。
- worktree は原則として `wt`(worktrunk)で作成する。新規作成には `wt switch --create <branch>` を使う。
- `wt` を経由せず作成された worktree では、post-start hook、gitignored ファイルの symlink 化、`direnv allow`、依存関係の準備が完了していない可能性がある。
  その状態で実装、ビルド、テスト、`direnv exec` を行わない。
- 実装ファイルを変更する場合は、対象 worktree をカレントディレクトリ、または書き込み可能な workspace root としてエージェントのセッションを開始する。
- 別の worktree で開始済みのセッションから、兄弟 worktree に対する実装変更、ビルド、テスト、`direnv exec`、Git 操作を行わない。
- 兄弟 worktree の読み取り専用レビューは、既存セッションから行ってよい。
- 既存セッションから兄弟 worktree への書き込みは、実装変更・ビルド・テスト・`direnv exec`・Git 操作を伴わない限定的な書き込みに限り、前提条件を明示した個別 skill(`conversation-context-export` 等)経由でのみ許可する。
- サブエージェントに実装作業を行わせる場合も、先に `wt` で worktree を作成し、その worktree を書き込み可能な workspace root として開始する。
  worktree の path を伝えるだけで書き込み可能になるとは仮定しない。

## Markdownの整形ルール

- 一文ごとに改行し、段落の区切りは空行で示す。
