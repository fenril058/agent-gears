# Claude Code 専用の常時ルール

## worktree

- `WorktreeCreate` hook がセッションに読み込まれていれば、Claude Code の native worktree 作成は `wt switch --create` を呼び、Worktrunk lifecycle を通る。
  これで確認できるのは、Worktrunk の作成経路を通ったことと、blocking な pre-start が完了したことまで。
  background の post-start の完了と成功はこれに含まれないので、依存する操作の前に別途確認する(`rules/always-on.md`)。
- どちらの経路になったかは、作成された path と branch 名で判別する。
  hook 経由なら要求した branch 名がそのまま使われ、worktrunk の layout(リポジトリの兄弟ディレクトリ)に作られる。
  hook 無しなら Claude Code 組み込みの経路になり、リポジトリ内の `.claude/worktrees/` に、branch 名を加工して(`/` が `+` になり `worktree-` が前置される)作られる。
  path と branch 名は経路の判別にだけ使う。
  環境準備が完了した証拠にはならない。
  `wt list` は `git worktree list` を列挙するだけで、どちらの経路の worktree も表示するので判別に使えない。
- plugin がインストール済みでも、セッションに読み込まれていなければ hook は動かない。
  `worktrunk:` namespace の skill が使えることが、読み込まれている観測可能な手がかりになる。
  使えなければ `/reload-plugins` を試す。
  ただしこれは復旧手段のひとつにすぎない。
- reload 後も hook を確認できない、または plugin が未導入・無効・故障している場合は、native 作成を使わない。
  `rules/always-on.md` の既定経路(`wt switch --create`)に戻る。
  現在の Claude セッションを対象 worktree に移せないなら、停止して報告する。
- `Agent` の `isolation: "worktree"` も同じ `WorktreeCreate` hook を通る(worktrunk plugin の一次資料による)。
  ただし Claude Code は内部 agent ID を `name` として渡すため、`worktrunk.agent-<id>` という throwaway branch の worktree になる。
- hook を通ることと、実装用 worktree の運用要件を満たすことは別。
  canonical な feature branch、path、workspace root、後続の統合方法は満たされず、これらは実行して確認してもいない。
  よって Agent isolation は通常の実装委譲には使わず、`rules/always-on.md` の workspace root 規則に従う。

## Codex への委譲

- 委譲を始める前に対象 worktree の絶対パスを確定し、ジョブの完了まで保持する。
- `codex:codex-rescue` に書き込み作業を委譲するときは、その絶対パスを依頼文の `--cwd` に指定する。
- reviewや診断でもtest、build、lint、再現commandを実行する可能性があれば、`codex:codex-rescue` に `--write` を指定する。
- 検証のためのwrite capabilityとtracked source fileの変更許可を区別し、修正を依頼していない場合はsourceを変更しないよう依頼文で制約する。
- `codex:codex-rescue` は依頼文から `--cwd` を取り除き、`codex-companion.mjs task --cwd <絶対パス>` の runtime option として渡す。
- Claude セッションの cwd と対象 worktree が同じだと仮定しない。

### 結果の取得

- `task`、`/codex:status`、`/codex:result` は、同じ委譲ジョブについて同じ worktree の cwd で実行する。
- main checkout から別の worktree に委譲した場合は、対象 worktree を cwd にして `/codex:status` と `/codex:result` を呼び出す。
- `task --cwd <worktree>` で作成したジョブは、その worktree に対応する workspace の state に保存される。別の cwd からは検索できない。

## Bash

- CI や background job の完了待ちは `Monitor` の until ループか `run_in_background` を使う。
  `sleep N; gh pr checks <n>` は harness が拒否する。
- Bash の cwd は呼び出し間で持続するが、直前の `cd` の結果を前提にしない。
  path は絶対で書くか、`cd` と後続をひとつの command 内で完結させる。

## ファイル編集

- 既存ファイルを上書き、または機械的に変更する前に、同じセッションで変更対象の現在の内容を確認する。
  確認にどの手段を使うかは問わない。
  変更前に現在の内容を確認したかを問う。
- auto-memory の `MEMORY.md` も既存ファイルなので例外ではない。
