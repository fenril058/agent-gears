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
相談要求は、それを行った呼び出しの中で usable answer か explicit failure のどちらかまで完結する。
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

```bash
timeout 900 codex exec --ephemeral -C <対象worktreeの絶対path> \
  -s <read-only|workspace-write> \
  [-c sandbox_workspace_write.network_access=true] \
  -o <回答file> \
  "<呼び出し元のprompt>" < /dev/null
```

- `-C <path>` で対象worktreeを作業rootにする。
  hostのcurrent directoryが対象worktreeと同じだと仮定しない。
- `--ephemeral` はsession fileを書かないため、kill されたりtimeoutした実行が回収対象のjobを残さない。
- `< /dev/null` は必須。
  promptを引数で渡していても、Codexはstdinを追加の `<stdin>` blockとして読みEOFまで待つため、閉じないとhangする。
- promptはCLI引数として渡す。標準入力ではない。
- `-o <file>` でCodexの最終messageがそのfileに書かれる。
  stdoutにはbanner、実行commandのtranscript、token数も混ざる。回答はfileから読み、transcriptは実行状況の報告に使う。
  このfileは対象worktreeの外のscratch pathに置く。相談がreview対象のrepositoryにuntracked fileを残さないようにする。

相談の上限は 900 秒(15分)とする。
これはexecution policyの既定値であってcontract自体ではない。呼び出し元が別の上限を指定してもよい。

hostの挙動に左右されないよう `timeout 900` でprocess自体を縛り、あわせてBash呼び出しにも 900000 ms のtool call timeoutを設定する。
hostがそれより短くtool call timeoutを制限する場合(Claude CodeのBash toolは上限 600000 ms と明記している)、実際に効く上限はhost側の制限である。
どちらが先に効いたかを報告する。
`timeout` が使えない環境では、tool call timeoutだけに頼る。

## 完了しなかった場合

timeoutに達した実行は相談失敗とする。
`timeout` が発動したときの終了コードは 124 なので、これはCodex CLIのerrorではなくtimeoutとして読む。
1回目を回収するために2回目のCodex実行を始めない。background実行へ切り替えない。後から回収するものを呼び出し元へ渡さない。
timeoutしたこと、その上限、得られている範囲のtranscriptを報告する。

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

## 実行状況の返却

以下をすべて呼び出し元へ返す:

- `-o` のfileから読んだCodexの回答。黙って補正しない
- read-onlyか書き込み可能か、およびnetwork accessを有効にしたか
- Codexが実行したと報告するtest、build、診断とその結果
- 取得できなかったremote情報またはcommand失敗
- 失敗した場合はその種類。CLI未導入、timeout、非0終了、usable answerが得られない、のいずれか

`could not fetch`、`permission denied`、`not found`、sandbox error、network error、command失敗などは、Codexが回答も生成していても実行失敗として扱う。
未実行のtestや取得できなかったPR文脈を検証済みとして表現しない。

非0終了、空の回答file、進められない旨だけを述べる回答は、回答ではなく相談失敗である。

追加往復の判断、相談先のfallback、独自検証、回答の統合、ユーザー向けの最終報告は、呼び出し元の `subagent-consultation` が担当する。
