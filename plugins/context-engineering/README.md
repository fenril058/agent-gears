# context-engineering plugin

エージェントがどう読み・探し・委譲・相談されるかを扱う skill 群。

## codex-consultation

`codex-consultation` は、Claude Code で Codex を相談先に選んだときの実行 adapter である。
policy の default timeout は 900 秒(15分)で、Bash tool call には 900000 ms を要求する。

### Claude Code の Bash timeout 既定値との差

Claude Code の Bash timeout ceiling は、既定では `BASH_MAX_TIMEOUT_MS` と `BASH_DEFAULT_TIMEOUT_MS` の大きい方で決まる。
既定値はそれぞれ 600000 ms(10分)と 120000 ms(2分)なので、既定の ceiling は 600000 ms である。
`codex-consultation` が要求する 900000 ms より短いため、既定設定では 15分の policy timeout を使い切れず、実際の持ち時間は 10分に切り詰められる。
`codex-consultation` はこの状態を host-limited として報告する。
適用された host ceiling 内に usable result が得られれば consultation は成功のままで、実際にその bound に到達した場合だけ consultation failure とする。
host 設定自体は変更しない。

### 15分の policy timeout をフルに使うための設定

`BASH_MAX_TIMEOUT_MS` を 900000 ms 以上にすると、host ceiling が 15分以上になる。

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
