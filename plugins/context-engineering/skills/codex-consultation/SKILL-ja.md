---
name: codex-consultation
description: >-
  Claude CodeからCodex CLIを直接foregroundで呼び、1回の同期的なCodex相談を実行する。
  subagent-consultationが選ぶCodex固有の実行adapterとして、またはCodexへの相談を
  明示された場合に使用する。導入確認、作業directory、sandbox capability、network access、
  timeout、実行失敗を扱い、prompt設計・往復判断・回答の統合は呼び出し元に任せる。
---

# Codex相談adapter

Codex CLIで相談を1回実行し、回答と実行状況を呼び出し元skillへ返す。
回答の評価・要約・統合は行わない。

**1回の呼び出しで1つの結果を返す。**
相談要求は、それを行った呼び出しの中で usable answer か consultation failure のどちらかまで完結する。
jobの識別子、status / result command、その他呼び出し元が手動で回収しなければならないものを返さない。
`codex:codex-rescue`、background job、その他Codex pluginのlifecycleを経由しない。
これらは呼び出し元が回収できないjobを返し、相談を依頼したreviewが人手待ちで止まる。

## 入力

呼び出し元に以下を要求する:

- 完結した相談prompt。
  単体で成立していること。Codexは呼び出し元の会話も、前のroundの内容も見ていない(「2往復目」を参照)。
- 対象worktreeの絶対path
- 静的相談か、検証可能な相談か
- remote情報が必要か

対象pathまたは相談promptがなければ、推測せず不足として返す。

## CLIの導入確認

```text
command -v codex
```

`codex` がPATHに無ければ、「Codex CLIが導入されていない」を相談失敗として返して終了する。
別の相談先で代替しない。fallbackは `subagent-consultation` が担当する。

## 実行capabilityの選択

作業が静的な読み取りだけに明確に限定される場合のみ `-s read-only` で実行する。

test、build、lint、再現command、診断がcache、一時file、生成物などを作る可能性があれば `-s workspace-write` で実行する。
reviewや診断だからといってread-onlyとは限らない。

書き込み可能なreviewまたは診断では、相談promptに以下の制約を追加する:

```text
tracked source fileを変更せず、修正を実装しないこと。
test、build、lint、診断commandを実行し、通常の一時fileや生成物を作ることは許可する。
```

ユーザーが実装を依頼した場合は、この制約を追加しない。

### network access

`gh pr view`、`gh api`、remote refの取得、release noteの取得などにはnetwork accessが必要で、sandboxは既定でこれを遮断する。
`-c sandbox_workspace_write.network_access=true` で有効にする。

この設定はworkspace-write sandboxに紐づいており、read-onlyの実行では効かない。
codex-cli 0.152.0 では、`-s read-only` にこのflagを付けても名前解決に失敗する(`curl: (6) Could not resolve host`)。
したがって、remote情報を必要とする相談は、書き込みの要否にかかわらず `-s workspace-write` で実行する。

## 実行

回答fileが途中終了でも片づくよう、相談全体をひとつのcommandで実行する:

```bash
ans=$(mktemp) && trap 'rm -f "$ans"' EXIT
timeout -k 10 <実効上限の秒数> \
  codex exec --ephemeral -C <対象worktreeの絶対path> \
  -s <read-only|workspace-write> \
  [-c sandbox_workspace_write.network_access=true] \
  -o "$ans" \
  "<呼び出し元のprompt>" < /dev/null
rc=$?
printf '\n===ANSWER(rc=%s)===\n' "$rc"; cat "$ans"
```

- `-C <path>` で対象worktreeを作業rootにする。
  hostのcurrent directoryが対象worktreeと同じだと仮定しない。
- `--ephemeral` はsession fileを書かないため、kill されたりtimeoutした実行が回収対象のjobを残さない。
- `< /dev/null` は必須。
  promptを引数で渡していても、Codexはstdinを追加の `<stdin>` blockとして読みEOFまで待つため、閉じないとhangする。
- promptはCLI引数として渡す。標準入力ではない。
- `-o "$ans"` でCodexの最終messageがそこに書かれる。
  stdoutにはbanner、実行commandのtranscript、token数も混ざるので、回答は `===ANSWER===` marker以降から読み、transcriptは実行状況の報告に使う。

### 回答file

Codexの最終messageには、source、PR文脈、その相談が触れたものが引用されうる。
置き場所は放置してよいscratchではない。

`mktemp` は対象worktreeの外に mode 0600 でfileを作り、`trap ... EXIT` はshellが取りうるどの経路でもそれを削除する。
成功も、非0終了も、timeoutも同じである。
trapが走る前にhostがshellをkillした場合、fileは 0600 のままそこに残るので、次のturnで明示的に削除する。

これは `--ephemeral` とは別の責務である。
`--ephemeral` はCodexのsessionやjobを残さず、trapは回答fileを残さない。

## 実行時間の上限

policyの既定は 900 秒(15分)。
これはexecution policyの既定値であってcontract自体ではない。呼び出し元が別の上限を指定してもよい。

実効上限は、policyの上限とhostのtool call timeout上限の小さいほうである。
tool call timeoutには実効上限を設定し、hostが明記する上限より大きい値を要求しない。`timeout` にも同じ秒数を渡す。
Claude CodeのBash toolは上限 600000 ms と明記しているので、そこでの実効上限は 600 秒になる。

実効上限がpolicyの上限を下回る場合、その相談は **host-limited** で実行されたことになる。
timeout時だけでなくどの結果でも実行状況に書き、policyが許す時間より短い持ち時間で実行されたことを呼び出し元に伝える。

`-k 10` はTERMの 10 秒後にKILLを送るので、CodexがTERMで終了しない場合でも実行時間は有界に保たれる。
`timeout` が使えない環境では上限はtool call timeoutだけになり、process側のkill保証は無い。これも degradation として報告する。

## 完了しなかった場合

実効上限に達した実行は相談失敗とする。
`timeout` の終了コードは、TERMで終わったときが 124、KILLが必要だったときが 137 である。どちらも同じtimeout系の失敗であって、Codex CLIのerrorではない。

1回目を回収するために2回目のCodex実行を始めない。background実行へ切り替えない。後から回収するものを呼び出し元へ渡さない。
timeoutしたこと、実効上限、host-limitedだったか、得られている範囲のtranscriptを報告する。

これを安全にしているのが `--ephemeral` である。
resumeすべきsessionも残るjobも無いため、processをkillすれば相談はそこで終わる。

範囲を定めた相談が繰り返し上限を超えるなら、必要なのは長寿命のjobではなくpromptの絞り込みである。
同じ内容で再実行せず、その旨を呼び出し元へ伝える。

## 2往復目

`codex exec` は単発実行であり、2回目の実行は1回目の記憶を持たない。
このadapterはCodex threadを保持せず、`--resume` も使わない。

したがって2往復目は、必要な文脈をすべて再掲したpromptによる新規実行になる。
元の背景・目的・制約・評価観点、1往復目の回答サマリー、呼び出し元の反論・補足・追加質問である。
そのpromptを組み立てるのは呼び出し元で、このadapterは実行するだけである。

## 結果の分類

どの実行も、次の2つのうちちょうど1つの結果に落ちる。
どちらかによって呼び出し元の次の行動が変わるので、混ぜない。

### consultation failure — usable answerが無い

- Codex CLIが導入されていない
- 実効上限に達した(`timeout` の終了コード 124 または 137)
- `codex exec` のprocessがそれ以外の理由で非0終了した
- 回答fileが空、または進められない旨しか述べていない

失敗を報告してそこで止まる。
別の相談先へ移るかどうかを決めるのは `subagent-consultation` であって、このadapterではない。

### usable result with execution degradation — 一部が失敗した実行から得た回答

Codexは回答したが、試みた一部が動かなかった場合である。
fetch、test、build、診断のcommandが失敗した、remote情報が取得できなかった、transcriptにsandbox errorやnetwork errorが出た、などが該当する。

これは相談失敗ではなく、別の相談先へ移る理由にもならない。
回答と実行状況を一緒に返し、不足情報の取得、それに依存した指摘の再評価、報告への明記は呼び出し元に委ねる。

transcriptでは `could not fetch`、`permission denied`、`not found`、sandbox error、network error、Codexが実行したcommandの非0終了に注意する。
どちらの結果でも、未実行のtestや取得できなかったPR文脈を検証済みとして表現しない。

## 実行状況の返却

以下をすべて呼び出し元へ返す:

- 2つの結果のどちらだったか
- Codexの回答そのもの。黙って補正しない
- read-onlyか書き込み可能か、およびnetwork accessを有効にしたか
- 実効上限と、host-limitedだったか
- Codexが実行したと報告するtest、build、診断とその結果
- 取得できなかったremote情報またはcommand失敗

追加往復の判断、相談先のfallback、独自検証、回答の統合、ユーザー向けの最終報告は、呼び出し元の `subagent-consultation` が担当する。
