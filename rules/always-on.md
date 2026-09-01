# 常時ルール (context-engineering)

全エージェント共通の不変則。詳細手順は各項目が指す skill 側にある。

## 用語

- 定義していない用語や勝手な造語を導入しない。
  その分野で確立した術語を使う。
  新語が必要なら初出で定義する。

## 文脈効率(トークン削減)

- 大きな Markdown を理由なく全文読みしない。
  索引から必要な節だけ取る(`markdown-context` skill / `mdidx`)。
- 自然言語でしか表せない未知の挙動・症状から、複数領域にまたがる候補箇所を絞る場合だけ
  `fastcontext`(`locate-implementation` skill)を使う。
  既知ファイル・既知シンボル・小規模探索・設計判断・issue の優先順位づけには使わない。
  `fastcontext` を使う前に、同 skill のエンドポイント分類と許可境界を適用する。
  `search` を含む、利用者と直接会話できない委譲先エージェントは、loopback endpoint の場合だけ `fastcontext` を実行し、非 loopback または判定不能なら親エージェントの許可申告にかかわらず Grep、Glob、Read へフォールバックする。
  非 loopback または判定不能な endpoint へ `fastcontext` が必要なら、メインセッションが API 呼び出し前に利用者から会話内で明示的な許可を得て実行する。
  ツール呼び出し時のコマンド承認プロンプトは、この許可とは扱わない。

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

- 読み取り専用の依頼、または `.git` に書き込めない状況では `git fetch` を実行せず、`git ls-remote origin main` でリモートの `main` を確認する。
  リモート先端が現在の `origin/main` と一致し、`git merge-base --is-ancestor origin/main HEAD` が成功した場合だけ、リモートの最新 `main` を含むと述べる。
  リモート先端が現在の `origin/main` と一致しない場合、または network unavailable などで確認できない場合は「リモートの最新 `main` を含むかは未確認」と明記し、最新性を主張しない。
  それ以外では、「リモートの最新 `main` を含む」と述べる前に `git fetch origin main` を実行し、`git merge-base --is-ancestor origin/main HEAD` で確認する。

## PR 本文

- PR 本文に、差分・テストコード・CI 結果から直接確認でき、変更で陳腐化する件数・バージョン・ファイル一覧を転記しない。
  これらは受入条件・比較結果・意思決定の根拠になる場合だけ記載する。

## リポジトリ配置 (ghq)

- GitHub 等の clone は ghq 管理下に置く(`~/ghq/<host>/<owner>/<repo>`)。
- ただし `<owner>/<repo>` は **`ghq get` した URL** で決まり、現在の `origin` とは一致しないことがある。
  upstream を ghq get した後に origin を fork へ張り替えた fork では、ディレクトリは upstream owner のまま(例: `~/ghq/github.com/emacs-twist/twist.nix` の origin は `fenril058/twist.nix`)。
- よって path を `origin` から推測しない。実 path は `ghq list --exact --full-path <repo>` で確認し、同名リポジトリが複数 owner にある場合は `ghq list --exact --full-path <owner>/<repo>` で特定する。

## worktree

- `wt` が使えるなら、worktree の作成・切替・削除に `git worktree` を直接使わず `wt` を通す。
  ホスト固有の作成経路が `wt` を通ると確認できないなら、その経路に頼らず `wt` を直接呼ぶ。
  手順は、そのホストに Worktrunk の skill(`worktrunk` / `wt-switch-create`)があればそれに従う。
- 自分から worktree を作るのは、並列作業(複数セッション/エージェントの同時進行)を意図するときだけ。
  利用者が worktree を明示的に要求した場合は、この判断を挟まない。
- worktree の path を渡されたことだけを、その worktree へ書き込める根拠にしない。
  ホストの書き込み可能範囲と、操作対象がその worktree であることを確認する。

## Markdownの整形ルール

- Git 管理対象かどうかにかかわらず、リポジトリを保存先とする Markdown 文書は、一文ごとに改行し、段落の区切りを空行で示す。
  チャット、issue と PR の本文・コメントには適用しない。
