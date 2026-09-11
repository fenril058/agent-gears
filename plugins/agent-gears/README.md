# agent-gears plugin

文脈効率、指示設計、批評、記録、レビュー、学習、文章規範を扱う skill 群と、Claude Code 用 agent 定義をまとめて配布する。

## codex-consultation

`codex-consultation` は、Claude Code で Codex を相談先に選んだときの実行 adapter である。
policy の default timeout は 900 秒(15分)で、Bash tool call には 900000 ms を要求する。

### Claude Code の Bash timeout 既定値との差

Claude Code の Bash timeout ceiling は、既定では `BASH_MAX_TIMEOUT_MS` と `BASH_DEFAULT_TIMEOUT_MS` の大きい方で決まる。
既定値はそれぞれ 600000 ms(10分)と 120000 ms(2分)なので、既定の ceiling は 600000 ms である。
`codex-consultation` が要求する 900000 ms より短いため、既定設定では15分の policy timeout を使い切れず、実際の持ち時間は10分に切り詰められる。
`codex-consultation` はこの状態を host-limited として報告する。
適用された host ceiling 内に usable result が得られれば consultation は成功のままで、実際にその bound に到達した場合だけ consultation failure とする。
host 設定自体は変更しない。

### 15分の policy timeout をフルに使うための設定

`BASH_MAX_TIMEOUT_MS` を 900000 ms 以上にすると、host ceiling が15分以上になる。

user-level の `~/.claude/settings.json` に書く例(host ceiling を20分にする):

```json
{
  "env": {
    "BASH_MAX_TIMEOUT_MS": "1200000"
  }
}
```

shell 環境変数として設定する例(Claude Code を起動する前の親 shell で実行する):

```bash
export BASH_MAX_TIMEOUT_MS=1200000
claude
```

`1200000`(20分)は host が許す ceiling を広げるだけである。
`codex-consultation` の Bash call は引き続き 900000 ms(15分)を要求するため、通常の consultation は15分で bound される。
`BASH_MAX_TIMEOUT_MS` は `codex-consultation` 専用の設定ではなく、Claude Code 全体の Bash timeout ceiling を広げる。
timeout を明示しない Bash call の実際の待ち時間は `BASH_DEFAULT_TIMEOUT_MS` のままで、この変更では変わらない。

この目的では `BASH_DEFAULT_TIMEOUT_MS` を変更する必要はない。
default を上げると、timeout を明示しない他の Bash call にも影響する。

### 変更しないもの

`codex-consultation` は `.claude/settings.json` / `.claude/settings.local.json` や環境変数を自動で書き換えない。
ceiling を上げるかどうかは利用者の判断であり、skill 自身は policy default の 900 秒と host-limited handling を維持する。

## sanity-review

`sanity-review` は、PR 概要欄、export された対話コンテキスト、実装コードを照合し、実装者の説明や検討過程を含むレビュー報告書を作成する。

次のどちらも通常の use case である。

- 実装者が自分の PR を見直す self-review
- 実装者とは別のレビュアーが行うレビュー

self-review では、実装中の session から `sanity-review` を実行できる。

実装時の前提や既存仮説から距離を置いて読み直したい場合は、次の利用方法を推奨する。

1. 実装 session で、必要な対話コンテキストを export する。
2. 同じリポジトリを扱える別 session を開く。
3. PR の URL または番号を指定して `sanity-review` を実行する。

別 session を使うと、実装時の対話に含まれる暗黙の前提や既存仮説をそのまま引き継がず、PR 概要欄、対話コンテキスト、コードを読み直しやすい。
これはレビューの独立性を高めたい場合の任意の運用であり、`sanity-review` の定義や必須条件ではない。
