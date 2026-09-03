# code-review plugin

出来上がったものを検めるレビュー skill 群。

- **sanity-review**: 実装者の主張・対話コンテキスト・実装コードを突き合わせ、レビュー対象 revision に bind したレビュー報告書を作る。
- **library-update-review**: 依存更新 PR(dependabot/renovatebot 等)のレビュー。リリースノート分析と過去障害の調査を行う。
- **codepatrol**: 領域ごとに継続するセキュリティ調査。複数 session にまたがる長期作業を `.dev/codepatrol/` の状態で続ける。

`SKILL.md` は agent が従う protocol と入出力の contract を書いたものである。
この README は人間向けに、**いつ・どの session から・何を渡して使うか** を書く。

## sanity-review をどう使うか

### まず: skill を起動することと full review は別物

`sanity-review` を起動すれば full review が行われる、というものではない。

full review は、実装した session とは別の session がレビューを行い、その報告書が修正側へ戻るまでの一連の流れ(workflow)である。
skill が担うのはそのうち reviewer の工程だけで、前後の工程は利用者が置く。
前後が欠けたまま起動しても skill は動くが、それは独立性を欠いた degraded なレビューであり、報告書にもそう記録される。

### 推奨: full independent review

```text
implementation session
  → change declaration
  → (任意)軽い self-review
  → conversation-context-export
  → fresh review session
  → sanity-review
  → revision に bind されたレビュー報告書
  → implementation / fix session または human へ handoff
  → revision が変わったら staleness を確認し、必要なら再レビュー
```

手順:

1. **implementation session で実装する。**

2. **change declaration(変更の宣言)を書く。**
   なぜ変更したのか、何を変えたのか、何を変えていないのか、成立していると主張する invariant、意図的にやらないこと(non-goal)。
   GitHub を使うなら PR 概要欄がその置き場になる。
   PR を作らない場合でも、この内容自体は reviewer に渡す必要がある。

3. **必要なら implementation session のまま軽く self-review する。**
   安く早く、明らかな欠陥はここで落ちる。
   ただしこれは full review の代わりにはならない(後述)。

4. **`conversation-context-export` で対話コンテキストを export する。**
   コードを読んでもわからないもの、つまり設計意図と根拠、却下した代替案とその理由、発見した制約、検証済みの事実、難所を明示的に渡す。
   export しなければ、この情報は implementation session と一緒に消える。

5. **fresh review session を開く。**
   実装を行っていない、実装時の対話を持っていない session を使う。
   レビュー対象のコードは読める必要があるので、同じリポジトリの checkout / worktree で開く。

6. **`sanity-review` を実行する。**
   例:「PR #123 のレビュー報告書を書いて」。
   PR が無い場合は、変更の説明(change declaration)と、レビューする revision range を渡す。
   reviewer は 2〜4 で渡された材料と、コード自身を照合する。
   reviewer の内部では独立した相談先(別モデルファミリが望ましい)とのセカンドオピニオンも行われる。

7. **レビュー報告書を受け取る。**
   報告書には、レビュー対象 revision と比較基準、使った change declaration と context handoff、指摘とその扱い、未解決の問い、レビューの mode、相談の有無が入る。

8. **報告書を implementation / fix session、または人間へ渡す。**
   report は成果物であり、reviewer が実装側へ暗黙に伝えることは前提にしない。
   GitHub を使うなら PR に貼るのが共有面になる。

9. **revision が動いたら staleness を確認する。**
   報告書は 1 つの revision についてのものである。
   commit の追加・rebase・force-push・指摘への修正が入れば、報告書は古い revision についての記述になる。
   指摘の扱いは新しい revision に対して確認し直し、変更が大きければ再レビューする。

### なぜ fresh session なのか

新しい session を開くことが目的ではない。

implementation の対話には、暗黙の前提・自己正当化・「もう検討して却下した」という既存仮説が乗っている。
それを継承した reviewer は、その前提が隠している誤りを見つけられない。
同じ材料でも、「思い出した結論」として読むか「読み直す証拠」として読むかで、見えるものが変わる。

だから reviewer には、記憶ではなく明示的な入力として材料を渡す。
2〜4 の手順(change declaration、context export)は、この受け渡しを成立させるためにある。

### 便宜的に使う: self-review(degraded)

```text
implementation session
  → sanity-review
```

実装した session からそのまま起動する使い方も禁止していない。
チェックリストと手順の網羅性には価値があり、明らかな齟齬はこれでも見つかる。

ただし implementation session からの独立性が無いので、full independent review とは同等ではない。
報告書の Review mode には `self-review` と記録され、独立したレビューを別途行うべきかどうかも結論に書かれる。

use case としては、PR を出す前の自己点検、あるいは full review を回す前の下ごしらえと考えるとよい。

### 対話コンテキストは「正しい前提」ではない

`conversation-context-export` が渡すのは、実装者がそう考えたという **証拠** であって、reviewer が従うべき **権威** ではない。

そこに書かれた設計判断・制約・却下理由・意図的な非対応も、reviewer の検証対象である。
「却下した代替案」の却下理由が妥当か、「試したがダメだった」の試し方が妥当だったか、「やらない」が今の実装を踏まえても妥当か。
`sanity-review` の手順6はこれを明示的に行う。

つまり context を渡すことは、reviewer を実装者の結論に縛るためではなく、**検証できる対象を増やすため** である。

### GitHub を使わない場合

reviewer が必要とするのは、次の 3 種類の証拠であって GitHub ではない。

| 論理的な入力 | GitHub adapter での実体 |
| --- | --- |
| change declaration | PR 概要欄、実装者自身の PR コメント |
| context handoff | 対話コンテキストの PR コメント、`.dev/contexts/` のファイル |
| code revision / diff reference | PR の head SHA と base、`gh pr diff` |

GitHub がない場合は、これらを呼び出し時に渡す(変更の説明を会話で渡す、revision range を引数で渡す、handoff のファイルを指す)。
渡せないものがあれば、reviewer はそれを degradation として報告書に記録する。

なお、GitHub を使わない環境で **これらの artifact をどこに保存し、session 間をどう運ぶか**(transport / storage)はまだ決めていない。
現状は「呼び出し側が渡す」までが contract である。

## library-update-review

依存更新 PR は `sanity-review` の対象外である。
リリースノートの読み方、更新の影響範囲、過去の障害履歴の調べ方が別物なので、`library-update-review` を使う。

## codepatrol

セキュリティ調査を領域ごとに分けて、複数 session にわたって進める。
`sanity-review` が 1 つの変更を見るのに対し、こちらはリポジトリ全体を対象に、前回の続きから調査する。
