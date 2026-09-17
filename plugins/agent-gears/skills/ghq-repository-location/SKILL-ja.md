---
name: ghq-repository-location
description: >-
  このマシンで Git リポジトリを置く場所の local convention。clone は ghq を通し、既に
  clone 済みのリポジトリの path は remote URL から推測せず ghq から取得する。リポジトリを
  clone するとき、または現在の作業ディレクトリ以外のリポジトリの local path が必要なとき
  に使用する。
---

# ghq によるリポジトリの配置

このマシンは clone をすべて ghq の root 配下に置く。
この skill が定めるのは、そこから導かれる2つの判断だけである。

## clone するとき

`ghq get <リポジトリの URL>` で clone する。
置き場所を自分で選ばない。
現在の作業ディレクトリや一時 path へ clone するのは、ghq root の外に使い捨ての clone を作るよう利用者から指示された場合だけである。

## 既存の clone を探すとき

場所は ghq に問う。

```
ghq list --exact --full-path <repo>
```

同名のリポジトリが複数の owner にある場合は `<owner>/<repo>` で絞る。

path を remote URL、`origin`、issue や PR のリンクに含まれる owner 名から組み立てない。
ディレクトリ名は clone した URL に由来し、それは現在の `origin` と一致しないことがある。
upstream から clone した後に origin を fork へ張り替えた fork は、path に upstream の owner を残したままになる。
そのため `origin` から導いた path は、もっともらしく、存在せず、しかも誤っていることが同時に起こりうる。

`ghq` が使えない場合、または listing が空の場合は、local path が不明であることを報告して確認する。
推測した path で代用しない。
推測した path に偶然ディレクトリが存在しても、それを当該リポジトリとして扱わない。

## ghq のそれ以外

`ghq --help` を読む。
この skill は ghq の subcommand や option を書き写さない。
