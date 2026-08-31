---
name: skill-feedback
description: agent-gears の skill が誤った挙動をした観測を、証拠が会話に残っているうちに fenril058/agent-gears の `skill-feedback` ラベル付き GitHub issue として1件記録する。この収録の skill が誤った指示を出した、description が名指す状況で発火しなかった、発火すべきでない場面で発火した、他の指示と矛盾した場合、または利用者が skill へのフィードバックの記録を求めた場合に使う。skill の文言をどう変えても変わらなかった結果、既に決まっている変更、この収録が所有しない skill には使わない。
compatibility: gh CLI(GitHub CLI、認証済み)が PATH にあり、fenril058/agent-gears への書き込み権限が必要。`ctx` は任意で、session 識別子の解決にのみ使う。gh は https://cli.github.com から入手する。
---

# Skill Feedback

skill へのフィードバックはセッションが終わると消える。
この skill は、証拠がまだ辿れるうちに観測を1件書き留める。

記録は `skill-improver` の入力になり、improver は skill の文言への編集を提案する。
したがって、その文言の変更で防げたはずのものだけを記録する。

## 対象範囲

この loop が扱うのは、このリポジトリが所有する skill である。
skill の原本があるのはそこなので、どこで失敗を観測したかにかかわらず、issue は必ず `fenril058/agent-gears` に立てる。

別のプロジェクトで作業しているのは通常の状況であり、記録を見送る理由にはならない。
そのプロジェクトの issue tracker に紛れ込ませないため、すべての `gh` 呼び出しに `--repo` を渡す理由になるだけである。

このリポジトリが所有しない skill へのフィードバックは、ここに記録しない。

## 何を記録するか

印象ではなく、個別の出来事を記録する。

- skill が発火し、その指示が誤った結果を生んだ。
- skill の `description` が名指す状況で、skill が発火しなかった。
- 発火すべきでない場面で発火した。
- skill の指示が、常時ルール、ホスト自身の指示、または他の skill と矛盾した。

次は記録しない。

- skill の文言をどう変えても変わらなかった結果。
  これは skill ではなくモデルの挙動であり、improver には手の打ちようがない。
- 「この skill は冗長に感じる」のような総体的な印象。
  個別の出来事が無ければ検証する対象が無い。
- 既に決まっている変更。
  その場合は skill を直接編集して PR を出す。
  この loop は、まだ判断に変換していない観測のためにある。

## 記録の書き方

一般化を担うのは理由の部分である。
期待した結果を「なぜ」期待したかの詳しい説明は、詳細のない報告を何件集めたものより価値が高い。
improver は理由を文言に変換できるが、結論だけからは何も導けない。

各記録は次を述べる。

- **Skill**: frontmatter の `name`。
- **期待**: 何が起きるべきだったか、**およびその理由**。
  理由こそが編集で符号化できる部分である。
  これが無い記録は特定の文言を支持しない。
- **観測**: skill が実際に何を引き起こしたか。
- **出典**: 下記のとおり。
- **会話中の対処**: その場で何が是正したか(あれば)。

### 出典は固定された状態へ解決できること

improver が読むのはこの要約ではなく出典であり、失敗が起きた時点の状態を必要とする。

次のいずれかを使う。

- `provider: <名前>` と `session: <provider の session id>`。
  ホスト自身の session 識別子と、どのエージェント由来か(`claude`、`codex` など)を併記する。
  improver は `ctx locate session` で対応付ける。
- `PR #<n>` または commit の完全な URL。
- `<owner>/<repo>@<commit>:<path>`。
  path だけでは足りない。
  commit が無いと improver は今日のファイルを読み、失敗を生んだファイルと取り違える。

## 起票前に確認する

起票は公開である。
`fenril058/agent-gears` は public リポジトリなので、issue 本文は作成した瞬間から誰でも読める。

`gh` を呼ぶ前に次を行う。

1. その issue について利用者の明示的な了承を得る。
   失敗に気づいたことは、それを公開してよいという依頼ではない。
   起票しようとしている本文を見せる。
2. **秘匿情報を除去する**。
   API キー、トークン、パスワード、個人を識別できる情報を含めない。
   失敗を観測したときに作業していた非公開プロジェクトの内容も同様に扱う。
   観測に必要な部分だけを引用する。
3. 引用は最小限にする。
   一般化するのは理由であって、顧客のソースコードではない。

## 起票する

```
gh issue create --repo fenril058/agent-gears --label skill-feedback \
  --title "<skill-name>: <症状を1行で>" \
  --body "$(cat <<'BODY'
## Skill
<frontmatter の name>

## 期待
…とその理由。

## 観測
…

## 出典
provider: claude / session: <provider の session id>
(または: PR #<n> / <owner>/<repo>@<commit>:<path>)

## 会話中の対処
…
BODY
)"
```

ラベルが無ければ最初に1度だけ作る。
`gh label create skill-feedback --repo fenril058/agent-gears`

1 issue につき 1 つの出来事とする。
原因を共有する2つの出来事も 2 issue に分ける。
improver は独立した発生回数を数えるので、分離できる形である必要がある。

## 正しく動いた確認

skill が正しく振る舞った確認を記録する価値があるのは、それが未解決の feedback issue と矛盾する場合だけである。
その場合は improver の判断を変えるので、新規 issue ではなくその issue へのコメントとして書く。
これほど小さい corpus では、日常的な確認は信号を薄めるだけである。
