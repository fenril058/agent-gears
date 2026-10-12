---
name: markdown-context
description: 長い Markdown 文書から、見出し単位の取得によって無関係な本文を大幅に読まずに済む場合に、必要な節を取得する。長い仕様書、設計書、原稿などの部分読みに使う。小さいファイル、長さが不明なだけの場合、文書全体が必要な作業は対象外。
compatibility: mdidx と jq が PATH に必要。mq は任意(構造クエリ用途のみ)。いずれも skill には同梱されない。導入は README の周辺ツール節を参照(mdidx は例えば `nix profile install github:fenril058/agent-gears#mdidx`)。
---

# Markdown Context Retrieval

索引の確認と節の選択にかかる手間よりも、読まずに済む本文の削減が大きい場合に `mdidx` を使う。
認識した見出しで分割する道具であり、タスクに必要な要件がどの節に揃っているかを判定するものではない。

## 読み方を選ぶ

- 小さいファイルは直接読む。
  長さが不明というだけで索引を作らず、既知のファイル情報、範囲を限った Read、必要ならサイズ確認を使う。
- 文書全体が必要な作業では直接読み、必要なら分割する。
  索引を作ってから `.sections[]` を出力しても、本文は絞られず手間が増える。
- 長い文書の一部だけが必要なら、役立つ場合に以下の見出し索引を使う。
  既知の行範囲や、対象を絞った `rg` 検索と Read または shell による取得で足りる場合もある。
- `mdidx` または `jq` がなければ、その作業では Read や shell を使う。
  導入方法は [リポジトリ README](https://github.com/fenril058/agent-gears#readme) を参照する。

## mdidx で節を取得する

`mdidx` は Markdown を `{index, sections}` の JSON に変換する。
索引の `## N. 見出し` の N が `sections[N]` に対応する。
各節は、次に認識された見出しの直前までとなる。
次の見出しが子見出しの場合も、そこで区切られる。
前文があれば `sections[0]` に入り、なければ最初の見出しが入る。

1. 現在のファイル内容に対応する索引がまだなければ確認する:

   ```bash
   mdidx path/to/doc.md | jq -r '.index'
   ```

2. 選んだ節を取得する:

   ```bash
   mdidx path/to/doc.md | jq -r '.sections[3,5,8]'
   ```

   子見出しも含める場合は `.sections[2:6][]` のようにスライスし、次の同じ深さか浅い見出しの直前まで取る。
   番号はこの例を流用せず、索引から選ぶ。

親節の導入、共通制約、参照された定義や例外など、判断に関わる前提も含める。
見出しだけでは要件の所在を判断できない場合は本文を検索するか読む範囲を広げ、選んだ節だけで要件が揃ったとみなさない。

変更されていない本文を繰り返し参照する場合は、一度変換した結果を再利用できる:

```bash
mdidx path/to/doc.md > /tmp/doc.idx.json
jq -r '.index'       /tmp/doc.idx.json
jq -r '.sections[5]' /tmp/doc.idx.json
```

## mq による構造クエリ(任意)

`mq` は要素型による抽出や変換に使い、見出し単位の節取得を複雑なクエリへ置き換えるためには使わない。

- 見出し: `mq -F text '.h2' doc.md`
- コードブロック: `mq -F text '.code' doc.md`
- 入出力形式: `-I` / `-F`(`mq --help` 参照)
