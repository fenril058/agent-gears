# agent-gears plugin

文脈効率、指示設計、批評、記録、レビュー、学習、文章規範を扱う skill 群をまとめて配布する。

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

`sanity-review` は、PR や明示された commit range の説明、利用可能な対話コンテキスト、実装を照合する。
差分に現れない却下案、失敗した試行、意図的な非対応の根拠も、変更に関係する範囲で疑い直す。
依存更新でも明示的に起動できるが、通常の依存更新レビューへ自動追加するものではなく、特定の組込レビューコマンドも前提にしない。

PR は URL・番号で指定でき、対象の明示がなければ現在ブランチの PR も利用できる。
PR のない range では、変更の説明、Reviewed head(レビュー対象 commit)、Comparison basis(実際の差分の起点)を渡す。
不完全な range 指定を、無関係な PR へ置き換えない。

対話コンテキストは任意であり、明示された資料を優先する。
補助資料や部分的な記録だけでは依頼された判断を検証できない場合、必要な分だけ追加探索する。
資料を限定する明示指示には従う。
探索では、対象に対応する PR コメントと規約上のローカル文脈を、由来・対象・保存時点・内容で比較する。
明示資料も時点を確認し、対象 head との関係が未確認の記録や、後の revision の記録は、補助資料として扱う。
ローカル保存だけでは共有済みコメントが更新されないため、最新コメントだけで選ばない。
文脈がなければ原則続行し、検討過程の確認が限られることを報告する。
文脈の共有や再生成を要求しない。

レビュー対象には read-only で接し、指摘をその場で修正しない。
exact commit を記録し、別 revision のコードや実行結果を混ぜない。
静的調査には元の Git の object を保護付きで読み、read-only の `.git` だけを理由に clone しない。
書込を伴いうる実行検証は、exact Reviewed head から作る別の使い捨て clone または export 済み tree で行う。
操作上の保護と入力の詳細は [SKILL.md](skills/sanity-review/SKILL.md) を参照。

報告は、対象 revision、文脈の出所、根拠のある指摘、検証と未確認範囲、判断を依頼に合う形式で示す。
固定テンプレート、全項目の採点、PR 概要の再掲は求めない。
通常は会話に出力し、保存・投稿は依頼や既存の許可に従う。

self-review と別のレビュアーによるレビューのどちらにも使える。
実装時の仮説から距離を置きたい場合は、必要な文脈を export して別 session で対象を指定する方法もある。
共有は必須ではなく、ローカルファイルも明示して渡せる。
独立レビューを依頼する場合は、`subagent-consultation` で host の会話継承と利用者の指定に従う。
対象資料を渡し、主担当の仮説を渡さず、返された候補は主担当が検証する。

[revision-isolation canary](https://github.com/fenril058/agent-gears/blob/main/docs/sanity-review-revision-isolation-canary.md) は、実際の別 revision 混入事故と、read-only な `.git` による不要な clone・広い fetch の記録を保つ。
partial clone、attributes、移動する PR head、shallow history、API 取得漏れは synthetic variant として区別する。
host の first-party skill testing での点検用であり、この文書の存在自体は行動改善の証明ではない。

## codepatrol

`codepatrol` は、リポジトリのセキュリティ調査を領域ごとに進め、`.dev/codepatrol/` の状態で複数セッションにまたがる調査を継続する。

### 独立探索の境界

調査本体は main investigator 単独で完了する。
選択した領域のコードを読み、working checklist の該当観点を確認し、tri-state(問題なし/非該当/未確認)で発見事項を記録する調査は main investigator 自身の作業であり、外部へ委譲しない。

独立探索は、同じ領域をもう一度別の探索経路で調べる価値があると判断した場合の任意の追加であり、必須ではない。
ただし user が明示的に要求した場合は、この追加価値の判断を挟まず実施する。
実施する場合、独立探索側に渡すのは調査対象の領域、対象 path/files、repository instructions、中立な security mechanism facts、該当する checklist perspective だけである。
main investigator 側の findings、報告書のドラフト、疑っている箇所、深刻度の判断、修正方針、結論は渡さない。

返ってきた指摘は candidate として扱い、main investigator が実コードで検証したものだけを報告書の発見事項にする。
working checklist へは逆流させない。

独立探索が無いこと自体は、どの場合も調査の失敗ではない。報告書に何を残すかだけが分かれる。

- 追加価値がないと判断して実施しなかった: 通常の main-only investigation。記録しない。
- 価値があると判断して試みたが、usable result を得られなかった: 調査自体は完全。ただし必要と判断した独立探索経路を得られなかった coverage limitation として報告書に記録する。
- user が独立探索を明示的に要求していたが実行できなかった: main investigation の結果は提示してよいが、要求された調査形態を満たせなかったことを明示する。
