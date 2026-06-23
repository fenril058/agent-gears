---
name: markdown-context
description: 大きな・未知の Markdown ファイルから必要な節だけを取り出して読むときに使う。README、設計書、仕様書、長いドキュメント、本の原稿などを全文ロードせず、見出し索引から該当箇所だけを取得してトークンを節約する。md2idx を主役に、構造クエリが要るときだけ mq を併用する。
---

# Markdown Context Retrieval

大きな Markdown を全文 Read しない。**索引を見て、必要な節だけ取る。**
組み込みの Read(offset/limit)+Grep では節の終端を確実に取れないが、
md2idx は見出しで節境界を切るので、取りこぼしも取りすぎも起きない。

## 判断

- ファイルが小さい(数十行)→ そのまま Read でよい。
- ファイルが大きい / 長さが不明 / 一部だけ要る → 以下の md2idx 手順。
- 「コードブロックだけ」「特定要素型の横断抽出」「変換」が要る → mq(後述)。

## md2idx(主役・固定2手)

`md2idx` は Markdown を `{index, sections}` の JSON に変換する。
`index` は番号付き目次、`sections` は見出し単位の生 Markdown 配列。
索引の `## N. 見出し` の N が `sections[N]` に対応する。

1. 目次を見る(数十行で済む):

   ```bash
   md2idx path/to/doc.md | jq -r '.index'
   ```

2. 必要な節だけ取る(N は索引の番号):

   ```bash
   md2idx path/to/doc.md | jq -r '.sections[5]'
   ```

   複数節なら `jq -r '.sections[3,5,8]'`。

同じファイルを何度も引くなら、一度だけ変換してキャッシュする:

```bash
md2idx path/to/doc.md > /tmp/doc.idx.json
jq -r '.index'       /tmp/doc.idx.json
jq -r '.sections[5]' /tmp/doc.idx.json
```

`--pretty` は人間向け整形。パイプ処理では不要。

## mq(補助・構造クエリが要るときだけ)

`mq` は Markdown 版の jq。要素型での抽出・横断・変換ができる。
**節の取得が目的なら md2idx を使う。** mq は次のような別の用途のときだけ:

- 見出しだけ一覧: `mq -F text '.h2' doc.md`
- コードブロックだけ集める: `mq -F text '.code' doc.md`
- 入力形式の指定や変換が要る場合は `-I` / `-F`(`mq --help` 参照)

`mq -F text` の出力は要素間に空行が混ざる。読みにくければ末尾に
`| sed '/^[[:space:]]*$/d'` を足して空行を除く(例: `mq -F text '.h2' doc.md | sed '/^[[:space:]]*$/d'`)。

## やらないこと

- 大きな Markdown を理由なく全文 Read しない。
- md2idx で済む「節取得」を mq のクエリで書かない(誤クエリで取りこぼす)。
