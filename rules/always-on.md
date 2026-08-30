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
- 自然言語でしか表せない未知の挙動・症状から、複数領域にまたがる候補箇所を絞る場合だけ
  `fastcontext`(`locate-implementation` skill)を使う。
  既知ファイル・既知シンボル・小規模探索・設計判断・issue の優先順位づけには使わない。

## 検証

- バグ修正の回帰テストは、修正前に失敗し、修正後に成功することを確認する。
  argv、ファイル内容、同時実行数など、バグが変える観測可能な値を直接 assert する。
- 実装方針を左右する見積もり、調査結果、実現可能性は、反証できる最小の確認を行ってから断定する。
  「未確認」「移植性がない」「費用に見合わない」「実現不可能」を区別する。
  調査で前提が変わったなら、着手前に報告して方針を確認する。
- 「安全」「起きない」「影響は限定的」と断定する前に、その主張を反証する最小の実験を行う。
  推論で書いた安全性の説明は、そのまま欠陥になる。
  実験できないなら断定せず「未確認」と書く。

## Git 操作

- 読み取り専用の依頼、network unavailable、または `.git` に書き込めない状況では `git fetch` を実行しない。
  その場合は「現在の `origin/main` が最新かは未確認」と明記し、最新性を主張しない。
  実行可能な場合だけ、「`origin/main` の最新を含む」と述べる前に `git fetch origin main` を実行し、`git merge-base --is-ancestor origin/main HEAD` で確認する。

## リポジトリ配置 (ghq)

- GitHub 等の clone は ghq 管理下に置く(`~/ghq/<host>/<owner>/<repo>`)。
- ただし `<owner>/<repo>` は **`ghq get` した URL** で決まり、現在の `origin` とは一致しないことがある。
  upstream を ghq get した後に origin を fork へ張り替えた fork では、ディレクトリは upstream owner のまま(例: `~/ghq/github.com/emacs-twist/twist.nix` の origin は `fenril058/twist.nix`)。
- よって path を `origin` から推測しない。実 path は `ghq list --exact --full-path <repo>` で確認する。

## worktree(エージェント隔離)

- worktree は並列作業(複数セッション/エージェントの同時進行)を意図するときだけ使う。
  worktree はセッション分割によるcontext断絶と人間の切り替えの手間を伴うため、並列を意図しない単発作業ではメインの checkout で `git switch`/`git checkout` して branch を切り替える。
- 新規 worktree は既定では `wt switch --create <branch>`(worktrunk)で作る。
  現在のセッションで、host 固有の作成経路が `wt switch --create` を実際に呼び Worktrunk lifecycle を通ると確認できる場合だけ、その経路で代替してよい。
- `wt` が無い、hook の承認で停止した、Worktrunk integration が未導入・無効・故障している、経路を確認できない、のいずれかなら、別の作成方法へ黙って fallback せず停止して報告する。
- Worktrunk lifecycle を通ったことと、環境準備が完了したことを同一視しない。
  pre-start は blocking で、`wt switch --create` が返る前に完了する。
  post-start は background で、worktree が使える時点では完了していない。
- 作業開始前に完了している必要がある処理は pre-start に置かれていなければならない。
  post-start にある処理に依存する操作の前には、プロジェクト固有の readiness、終了状態、または log(`wt config state logs`)を確認する。
  worktree の存在や `wt switch` の成功を post-start 完了の証拠にしない。
- 実装ファイルの変更は、対象 worktree を cwd または書き込み可能な workspace root として開始したセッションだけで行う。
- 別のセッションから兄弟 worktree に対する実装変更、ビルド、テスト、`direnv exec`、Git 操作を行わない。
  読み取り専用のレビューは既存セッションから行ってよい。
- これらを伴わない限定的な書き込みは、前提条件を明示した個別 skill(`conversation-context-export` 等)経由でのみ許可する。
- 対象 worktree を書き込み可能な workspace root にできないホストでは、そのホストのサブエージェントに実装作業を委譲しない。
  worktree の path を伝えるだけで書き込み可能になるとは仮定しない。

## Markdownの整形ルール

- リポジトリ内の Markdown 文書は、一文ごとに改行し、段落の区切りを空行で示す。
