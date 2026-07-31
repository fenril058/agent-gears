---
name: codex-consultation
description: >-
  Claude CodeからCodex plugin経由でpersistentなCodex相談を実行する。
  subagent-consultationが選ぶCodex固有の実行adapterとして、またはCodexのthreadを
  維持して相談するよう明示された場合に使用する。cwd、sandbox capability、jobの結果取得、
  継続、実行失敗を扱い、prompt設計と回答の統合は呼び出し元に任せる。
---

# Codex相談adapter

`codex:codex-rescue` 経由で相談を実行し、2往復目に備えてCodex threadを維持する。
Codexの回答と実行状況を呼び出し元skillへ返す。
回答の評価・要約・統合は行わない。

## 入力

呼び出し元に以下を要求する:

- 完結した相談prompt
- 対象worktreeの絶対path
- 静的相談か、検証可能な相談か
- remote情報が必要か
- 新規相談か、継続か

対象pathまたは相談promptがなければ、推測せず不足として返す。

## 実行capabilityの選択

作業が静的な読み取りだけに明確に限定される場合のみread-onlyで実行する。

test、build、lint、再現command、診断がcache、一時file、生成物などを作る可能性があれば、
書き込み可能にして実行する。
reviewや診断だからといってread-onlyとは限らない。

書き込み可能なreviewまたは診断では、相談promptに以下の制約を追加する:

```text
tracked source fileを変更せず、修正を実装しないこと。
test、build、lint、診断commandを実行し、通常の一時fileや生成物を作ることは許可する。
```

ユーザーが実装を依頼した場合は、この制約を追加しない。

`gh pr view`、`gh api`、remote refの取得、release noteの取得などには、filesystemの権限とは
別にnetwork accessが必要である。
書き込み可能だからnetworkも利用可能だと断定しない。

導入済みCodex pluginが実行単位のnetwork optionを提供する場合、remote情報を必要とする相談で使う。
提供しない場合は、信頼済み対象repositoryのproject-local `.codex/config.toml` に依存する:

```toml
[sandbox_workspace_write]
network_access = true
```

相談の一部としてこのconfigを作成・変更しない。
remote accessに失敗したら呼び出し元へ返し、呼び出し元が不足情報を取得して同じCodex threadを
継続するか判断できるようにする。

## 相談の開始

Claude Codeでは、Agent toolを `subagent_type: codex:codex-rescue` で呼ぶ。

対象worktreeの絶対pathを依頼文の `--cwd <path>` に入れる。
rescue agentはそれをpromptから取り除き、runtime optionとして
`codex-companion.mjs task --cwd <path>` へ渡す。
Claude Codeのcurrent directoryが対象worktreeと同じだと仮定しない。

検証可能な相談では `--write` を指定する。
静的相談ではread-onlyを明示する。
呼び出し元がforeground/backgroundを指定した場合は維持する。
指定がなければ、範囲の定まった相談はforeground、長時間の調査はbackgroundを選ぶ。

1往復目は新しいCodex taskとして開始する。
返されたjobとthreadの識別子を保持する。
あるcwdで作ったtaskはそのworkspaceのstateに保存され、別のcwdから取得できない。

rescue agentがbackground jobを開始した場合、同じcwdから `/codex:status` と
`/codex:result` で結果を取得する。
enqueueの成功を相談回答として扱わない。

## 同じCodex相談先の継続

2往復目は、同じ絶対cwdからrescue agentを `--resume` 付きで呼ぶ。
呼び出し元の反論、補足、追加質問、さらに調べてほしい観点だけを送る。
新しいCodex taskを作らない。

Claude側のwrapper agentは呼び直してよい。
相談の継続性はwrapper agentのcontextではなく、resumeされたCodex threadで定義する。

## 実行状況の返却

以下をすべて呼び出し元へ返す:

- Codexの回答。黙って補正しない
- 取得できた場合はjobまたはthreadの識別子
- read-onlyか書き込み可能か
- Codexが実行したと報告するtest、build、診断とその結果
- 取得できなかったremote情報またはcommand失敗

`could not fetch`、`permission denied`、`not found`、sandbox error、network error、command失敗などは、
Codexが回答も生成していても実行失敗として扱う。
未実行のtestや取得できなかったPR文脈を検証済みとして表現しない。

追加往復の判断、独自検証、回答の統合、ユーザー向けの最終報告は、呼び出し元の
`subagent-consultation` が担当する。
