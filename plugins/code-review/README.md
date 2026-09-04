# code-review plugin

出来上がった変更を検めるレビュー skill 群。

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
