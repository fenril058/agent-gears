# mdctx 実装計画書

## 0. この計画書の目的

この計画書に従って、Coding Agent専用のMarkdownコンテキスト取得CLI `mdctx` を実装する。

`mdctx` の目的は、Markdown全文をAgentのコンテキストへ投入せず、質問やタスクに関連するsectionだけを、少ないトークン量で取得することである。

既存の `mdidx` は維持する。

`mdidx` はMarkdownをsection単位へ分割し、JSONとして出力する低レベルプリミティブである。

```bash
mdidx docs/spec.md | jq -r '.index'
mdidx docs/spec.md | jq -r '.sections[5]'
```

`mdctx` は `mdidx` と同じsection定義を利用し、次を一つのコマンドで実行する。

```text
Markdownファイル探索
→ 関連section検索
→ section本文取得
→ 重複排除
→ トークン予算内で選択
→ Agent向けJSON出力
```

---

# 1. 最終的なプロダクト境界

## 1.1 公開コマンド

初期リリースでは次の二つを公開する。

```text
mdidx
mdctx query
```

### `mdidx`

既存仕様を維持する。

```bash
mdidx FILE
```

標準出力:

```json
{
  "index": "...",
  "sections": [
    "...",
    "..."
  ]
}
```

### `mdctx`

新規実装する。

```bash
mdctx query --q "authentication retry policy" docs/
```

標準出力はJSONとする。

---

## 1.2 初期リリースで実装しないもの

以下はv0.1の対象外とする。

* `mdsearch` 独立コマンド
* `mdctx fetch`
* `mdctx index`
* watch daemon
* embedding検索
* LLMによるクエリ書き換え
* LLMによる要約
* `mq` の必須統合
* Python依存
* SQLite永続インデックス
* frontmatter検索
  -複数リポジトリ横断検索
* Markdown以外の文書形式
* 人間向けinteractive UI
* human-readable textを既定出力にすること

必要な機能を先回りして実装しない。

---

# 2. 成功条件

v0.1は、以下を満たしたとき完成とする。

1. `mdctx query` が複数のMarkdownファイルから関連sectionを検索できる
2. 検索結果のsection番号が `mdidx FILE | jq '.sections[N]'` と完全に一致する
3. Markdown全文を結果へ含めない
4. 指定されたトークン予算を超えない
5. 同一sectionを重複して返さない
6. 親sectionと子sectionの内容を重複して返さない
7. 結果なしと低confidenceを区別できる
8. stdoutにはJSON以外を出さない
9. diagnostic logはstderrへ出す
10. `mdidx` の既存JSON仕様を壊さない
11. 日本語文書および日本語クエリを最低限検索できる
12. 外部LLM、外部API、ネットワーク接続を必要としない
13. Goの単一バイナリとしてビルドできる

---

# 3. Codexへの実装方針

## 3.1 最優先事項

実装時は、機能数より以下を優先する。

```text
正しいsection境界
安定したJSON
決定論的な挙動
少ない出力トークン
テスト容易性
```

検索アルゴリズムの高度化は後回しにする。

---

## 3.2 基本原則

### 同一のsection modelを使う

`mdidx` と `mdctx` が別々にMarkdownを分割してはならない。

Markdown parsingとsection生成を共有パッケージへ移す。

```text
Markdown parser
      ↓
shared section model
   ↙             ↘
mdidx JSON      mdctx search
```

### `mdidx` の後方互換を壊さない

既存出力:

```json
{
  "index": "...",
  "sections": []
}
```

のフィールド名、型、順序に依存する既存処理を壊さない。

JSONオブジェクトのキー順序は契約にしなくてよいが、golden testでは意味的な一致を確認する。

### stdoutを汚さない

次をstdoutへ出してはならない。

* progress
* debug log
* warning text
* index作成メッセージ
* human-readable summary

stdoutはJSON専用とする。

### エラーを握り潰さない

空結果と実行失敗を区別する。

---

# 4. 推奨リポジトリ構成

既存構成に合わせて調整してよいが、責務は以下のように分離する。

```text
cmd/
  mdidx/
    main.go

  mdctx/
    main.go

internal/
  markdown/
    parse.go
    section.go
    heading.go
    normalize.go

  mdidx/
    output.go

  corpus/
    discover.go
    ignore.go

  search/
    query.go
    literal.go
    tokenize.go
    bm25.go
    rank.go

  retrieve/
    candidate.go
    dedupe.go
    select.go

  contextbudget/
    estimate.go
    budget.go

  protocol/
    mdctx.go
    errors.go

testdata/
  markdown/
  corpus/
  golden/
  queries/
```

既存のpackage構成と大きく衝突する場合は、既存設計を優先する。

ただし、以下の責務は分離する。

```text
Markdown parsing
section model
search
budgeting
JSON protocol
CLI
```

---

# 5. 共有section model

## 5.1 内部データ構造

最低限、以下を保持する。

```go
type Section struct {
    Number      int
    Path        string
    Heading     string
    HeadingPath []string
    Level       int

    Parent      int
    SubtreeEnd  int

    Content     string
    ByteStart   int
    ByteEnd     int
}
```

必要に応じてフィールドを追加してよい。

### 必須条件

* `Number` は `mdidx.sections` の配列indexと一致する
* `Content` は `mdidx.sections[Number]` と一致する
* `HeadingPath` はrootから現在のheadingまでを保持する
* `Parent` がない場合は `-1`
* `SubtreeEnd` はsubtree直後のsection番号、または配列長とする

`SubtreeEnd` は半開区間として扱う。

```text
section subtree = [Number, SubtreeEnd)
```

---

## 5.2 section境界

既存の `mdidx` の挙動を正とする。

新しいMarkdown parserへ全面的に置き換えない。

まず既存ロジックを共有packageへ抽出し、既存挙動をgolden testで固定する。

最低限、以下をテストする。

* ATX heading
* 見出しなし文書
* 文書先頭の本文
* heading levelの飛び越し
* 同名heading
* 空section
* code fence内の `#`
* heading末尾の `#`
* 日本語heading
* CRLF
* 空ファイル

Setext headingを既存 `mdidx` が扱っていない場合、v0.1では追加しない。

---

# 6. `mdctx query` CLI仕様

## 6.1 基本形式

```bash
mdctx query --q QUERY [PATH...]
```

例:

```bash
mdctx query \
  --q "認証トークンの更新に失敗した場合の挙動" \
  docs/
```

---

## 6.2 v0.1の引数

```text
--q STRING
--max-context-tokens INTEGER
--max-results INTEGER
--include GLOB
--exclude GLOB
--format json|plan
--explain
```

### 既定値

```text
--max-context-tokens 2400
--max-results 5
--format json
```

PATHが省略された場合は現在ディレクトリを使用する。

---

## 6.3 引数検証

以下はエラーにする。

* `--q` が空
* `--max-context-tokens <= 0`
* `--max-results <= 0`
* 存在しない明示パス
* 未知のformat
* Markdownファイルが一件も見つからない

---

# 7. Markdownファイル探索

## 7.1 対象

以下をMarkdownとして扱う。

```text
*.md
*.markdown
```

v0.1では `*.mdx` を含めない。

---

## 7.2 既定除外

最低限、以下を除外する。

```text
.git
node_modules
vendor
dist
build
target
.next
.cache
```

`.gitignore` 対応が容易であれば実装する。

大きな追加依存や複雑化が必要なら、v0.2へ送る。

---

## 7.3 deterministic ordering

ファイル探索結果はpathで昇順にsortする。

同一入力に対して結果順が変わらないようにする。

---

# 8. 検索実装

## 8.1 v0.1の検索方式

次の三つを実装する。

1. exact literal match
2. heading-aware token match
3. BM25相当のlexical ranking

Embeddingは実装しない。

---

## 8.2 text normalization

検索用の正規化を実装する。

最低限:

* Unicode normalization
* lowercase
* 連続空白の圧縮
* punctuationの分離
* ASCII英数字token
* 日本語trigram

元の本文は変更しない。

正規化は検索indexだけに使う。

---

## 8.3 日本語tokenization

v0.1では形態素解析器を追加しない。

日本語文字列はtrigramへ分割する。

例:

```text
認証トークン
```

概念的には次のように分割する。

```text
認証ト
証トー
トーク
ークン
```

実際の実装ではUnicode rune単位で処理する。

英数字列は通常tokenとして保持する。

---

## 8.4 ranking fields

以下を別フィールドとして評価する。

* filename
* heading
* heading path
* section content

初期重みの例:

```text
exact match          8.0
filename             3.0
heading              4.0
heading path         2.5
body BM25            1.0
```

この値をAPI契約にしない。

定数として一か所へまとめる。

---

## 8.5 exact identifier boost

次のようなqueryはliteral matchを強く優先する。

```text
ERR_AUTH_42
MaxRetryCount
--max-context-tokens
/api/v2/login
```

英数字、underscore、hyphen、slashを含むtokenはexact identifier候補として扱う。

---

## 8.6 検索対象単位

検索対象はfileではなくsectionとする。

一つのdocument全体を一候補にしない。

見出しなし文書は一つのsectionとして扱う。

---

## 8.7 score normalization

外部出力の `score` は0から1へ正規化する。

絶対的な確率とは扱わない。

```text
1.0 = 当該query内で最も高い相対score
```

confidenceは別ロジックで算出する。

---

# 9. confidence判定

## 9.1 出力値

```text
high
medium
low
```

---

## 9.2 初期判定

例:

### high

* exact literal matchがheadingまたは本文にある
* 複数query tokenがheadingと本文の双方で一致
* 1位と2位のscore差が十分大きい

### medium

* BM25で明確な候補がある
* heading pathに部分一致する
* 複数tokenの一部だけ一致する

### low

* 一般語だけが一致
* scoreが非常に低い
* 1位以下がほぼ同点
* query tokenの大半が未一致

閾値は定数化し、テスト可能にする。

---

# 10. 重複排除

最低限、以下を行う。

## 10.1 同一section

同じpathとsection番号を持つ候補を一つへ統合する。

## 10.2 親子section

親sectionの `Content` が子section本文まで含む設計の場合、親と子を同時に返して重複させない。

現在の `mdidx` のsection定義が各heading本文のみで子sectionを含まない場合、単純に両方を保持してよい。

実装前に既存仕様を確認し、その仕様をテストで固定する。

## 10.3 同一内容

完全一致するsection本文は、原則として上位一件だけ返す。

ただしpathは `duplicates` metadataとして保持してよい。

v0.1で複雑になる場合、この処理は省略可能。

---

# 11. トークン予算

## 11.1 定義

`--max-context-tokens` は、最終JSON内の `results[].content` の推定トークン合計に適用する。

JSON metadata自体のトークン量はhard limitへ含めなくてよい。

ただし計測値として出力する。

---

## 11.2 token estimation

外部tokenizer依存を追加しない。

初期推定は以下のいずれかとする。

```text
UTF-8文字数 / 4
```

または、英語と日本語を分けた軽量推定。

推奨:

```text
ASCII word token:
  word数 × 1.3

CJK文字:
  文字数 × 1.0

その他:
  rune数 / 3
```

推定ロジックはinterface化する。

```go
type TokenEstimator interface {
    Estimate(text string) int
}
```

将来、正確なtokenizerへ差し替え可能にする。

---

## 11.3 section選択

score順にsectionを選ぶだけではなく、最低限次を守る。

1. 最高score候補を最初に選ぶ
2. 同一ファイル、同一heading pathの冗長候補を抑制する
3. 予算を超える候補は原則スキップする
4. 単一の最上位sectionが予算を超える場合は切断を許可する
5. 切断はparagraph境界またはline境界で行う
6. 切断時は `truncated: true`
7. 元section全体の推定token数を保持する

---

## 11.4 大きすぎるsection

最上位sectionだけで予算を超える場合:

```text
heading
+
query hit周辺のparagraph
+
可能ならsection冒頭
```

を返す。

単純に先頭から切るだけにしない。

query hit位置を取得し、その周辺を優先する。

v0.1で実装困難な場合は、以下の簡易実装を許可する。

```text
heading + query hitを含む前後N行
```

---

# 12. 出力JSON

## 12.1 context mode

既定出力。

```json
{
  "schema_version": "1",
  "status": "ok",
  "query": "authentication retry policy",
  "strategy": {
    "search": [
      "literal",
      "heading",
      "bm25"
    ],
    "selection": "token_budget"
  },
  "budget": {
    "max_context_tokens": 2400,
    "estimated_content_tokens": 1380
  },
  "stats": {
    "files_scanned": 24,
    "sections_scanned": 181,
    "candidates_considered": 12,
    "results_returned": 3
  },
  "results": [
    {
      "path": "docs/auth.md",
      "section": 7,
      "jq": ".sections[7]",
      "heading": "Retry policy",
      "heading_path": [
        "Authentication",
        "Token refresh",
        "Retry policy"
      ],
      "score": 1.0,
      "confidence": "high",
      "estimated_tokens": 420,
      "complete_section": true,
      "truncated": false,
      "content": "### Retry policy\n..."
    }
  ],
  "warnings": []
}
```

---

## 12.2 plan mode

```bash
mdctx query \
  --q "authentication retry policy" \
  --format plan \
  docs/
```

本文を返さない。

```json
{
  "schema_version": "1",
  "status": "ok",
  "query": "authentication retry policy",
  "candidates": [
    {
      "path": "docs/auth.md",
      "section": 7,
      "jq": ".sections[7]",
      "heading": "Retry policy",
      "heading_path": [
        "Authentication",
        "Retry policy"
      ],
      "score": 1.0,
      "confidence": "high",
      "estimated_tokens": 420
    }
  ]
}
```

このモードは既存の `mdidx + jq` workflowとの接続点として実装する。

---

## 12.3 status

以下を使用する。

```text
ok
no_results
insufficient_evidence
budget_exceeded
error
```

### `no_results`

literal、heading、BM25のいずれでも候補がない。

### `insufficient_evidence`

候補はあるが、すべてconfidenceが低い。

### `budget_exceeded`

必須候補が予算へ収まらず、安全な切断もできない。

---

## 12.4 warnings

文字列配列とする。

例:

```json
{
  "warnings": [
    "Top result was truncated to fit the context budget",
    "All matches had low confidence"
  ]
}
```

---

# 13. exit code

```text
0: status=ok
2: status=no_results
3: status=insufficient_evidence
4: status=budget_exceeded
5: internal or I/O error
6: invalid arguments
7: Markdown parse error
```

exit codeが0以外でも、可能な限りstdoutへschema-valid JSONを返す。

---

# 14. `--explain`

`--explain` 指定時もstdout schemaを壊さない。

以下を追加する。

```json
{
  "explain": {
    "normalized_query_tokens": [
      "authentication",
      "retry",
      "policy"
    ],
    "ranking_weights": {
      "heading": 4.0,
      "heading_path": 2.5,
      "body": 1.0
    },
    "candidate_scores": []
  }
}
```

大量出力にならないよう、candidateは上位20件までとする。

---

# 15. テスト計画

## 15.1 Unit tests

### Markdown section model

* section numbering
* heading path
* parent
* subtree end
* byte range
* code fence内のheading記号
* 日本語heading
* duplicate heading
* empty section

### Tokenization

* English
* Japanese
* mixed Japanese/English
* identifier
* punctuation
* Unicode normalization

### Ranking

* heading matchがbody matchより上位
* exact identifierが最上位
* filename matchが加点される
* irrelevant sectionが低scoreになる

### Budget

* 予算内で候補選択
* 超過候補のskip
* 最上位sectionの切断
* token合計が上限以下
* duplicate除去後の再計算

### Protocol

* JSON schema
* statusとexit code
* stdoutにlogが混ざらない
* plan modeにcontentがない

---

## 15.2 Golden tests

既存 `mdidx` 出力をgolden fileとして固定する。

```text
testdata/golden/mdidx/
```

最低限:

* simple.md
* nested-headings.md
* code-fence.md
* japanese.md
* no-heading.md
* duplicate-heading.md
* empty.md

リファクタリング前後で意味的に同一であることを確認する。

---

## 15.3 Integration tests

実際のCLIをビルドし、以下を確認する。

```bash
mdctx query --q "retry policy" testdata/corpus
```

検証項目:

* exit code
* valid JSON
* expected path
* expected section
* token budget
* deterministic ordering
* stderrとstdoutの分離

---

## 15.4 Benchmark fixture

最初は小規模でよい。

```text
testdata/benchmark/
  docs/
  queries.json
  expected.json
```

query entry例:

```json
{
  "id": "auth-retry-001",
  "query": "認証トークン更新に失敗した場合の再試行",
  "expected": [
    {
      "path": "docs/auth.md",
      "sections": [7, 8]
    }
  ]
}
```

最低20件を作る。

以下を含める。

* exact heading
* 同義語
* identifier
* 日本語
* 英語
* 日英混在
* no answer
* 複数sectionが必要
* 巨大section

---

# 16. ベンチマークCLI

v0.1の本体完成後、内部またはtest commandとして追加する。

例:

```bash
go test ./internal/benchmark/... -run TestBenchmarkCorpus
```

または:

```bash
go run ./cmd/mdctx-bench
```

公開バイナリにする必要はない。

計測する。

```text
File Recall@1
Section Recall@1
Section Recall@3
MRR
平均返却推定token数
全文比token削減率
no-answer precision
平均実行時間
peak memory
```

---

# 17. `markdown-query` / `mdq` との比較

v0.1実装へ直接vendorしない。

最初は比較adapterだけを作る。

## 17.1 adapterの目的

同一query corpusに対して以下を比較する。

```text
mdctx native
mdq
rg
mdidx index-only
full file read
```

## 17.2 この段階でしないこと

* `mdq` ソースをコピーしない
* PythonコードをGoから埋め込まない
* `mdctx` の必須依存にしない
* 検索品質を測る前にBM25実装を置き換えない

## 17.3 導入判断

`mdq` の一部を取り込むのは、次を満たす場合のみ。

1. Section Recall@3が明確に改善する
2. no-answer precisionを悪化させない
3. 出力token数が増えすぎない
4. Agent task成功率が改善する
5. 配布と保守コストが妥当
6. Goへの限定的移植が困難

MITコードを取り込む場合はlicense noticeと出所を保持する。

---

# 18. 実装フェーズ

## Phase 1: 現状調査と互換性固定

### 作業

1. 現在の `mdidx` のpackage構成を確認
2. CLI entrypointを特定
3. Markdown section生成ロジックを特定
4. 現在のJSON出力をgolden test化
5. edge case testを追加
6. READMEまたはSKILL内の既存使用例を確認

### 完了条件

* 既存挙動がテストで固定されている
* 既存テストがすべて通る
* 変更前後の `mdidx` 出力差分を検出できる

### このフェーズで機能追加しない

---

## Phase 2: section model共有化

### 作業

1. Markdown parsingロジックを共有packageへ抽出
2. `Section` modelを導入
3. `mdidx` を共有modelからJSON生成するよう変更
4. heading pathを内部的に計算
5. parentとsubtree endを内部的に計算

### 完了条件

* `mdidx` の出力が既存goldenと一致
* section番号とcontentが変わらない
* 共有packageを `mdctx` から利用可能
* 循環依存がない

---

## Phase 3: `mdctx query` skeleton

### 作業

1. `cmd/mdctx` を追加
2. CLI argument parserを追加
3. path探索を追加
4. Markdownをsectionへ変換
5. 固定JSON schemaを返す
6. exit codeを実装
7. stdout/stderrを分離

この段階では検索は仮実装でもよい。

### 完了条件

以下がschema-valid JSONを返す。

```bash
mdctx query --q "test" testdata/corpus
```

---

## Phase 4: literal and heading search

### 作業

1. query normalization
2. English tokenization
3. Japanese trigram
4. exact literal match
5. heading match
6. heading path match
7. filename match
8. deterministic ranking

### 完了条件

* exact heading queryで正解sectionが1位
* exact identifier queryで正解sectionが1位
* 日本語headingを日本語queryで検索可能
* 同score時の順序が安定

---

## Phase 5: BM25

### 作業

1. section corpusからterm frequencyを構築
2. document frequencyを構築
3. BM25 scoreを計算
4. heading/bodyのfield weighting
5. literal scoreと統合
6. scoreを0から1へ正規化

### 完了条件

* 同義的な複数token queryでliteral検索よりRecallが改善
* exact matchの順位を不必要に下げない
* benchmark queryでSection Recall@3を計測できる

---

## Phase 6: token budget and result assembly

### 作業

1. token estimator
2. max-results
3. max-context-tokens
4. duplicate除去
5. oversized section truncation
6. complete/truncated metadata
7. estimated token metadata

### 完了条件

* `results[].content` の推定token合計が上限以下
* 最上位候補を可能な限り含む
* 重複sectionがない
* truncationがmetadataに反映される

---

## Phase 7: confidence and no-answer

### 作業

1. high/medium/low判定
2. minimum score threshold
3. no-results
4. insufficient-evidence
5. warnings
6. exit code

### 完了条件

* 関係ないqueryを `ok` にしない
* no-answer corpusで誤検出率を測定できる
* statusとexit codeが対応する

---

## Phase 8: plan mode

### 作業

1. `--format plan`
2. contentを除外
3. path、section、jq selectorを返す
4. estimated tokenを返す
   5.候補上位のみ返す

### 完了条件

以下の結果からAgentが既存 `mdidx + jq` へ接続できる。

```json
{
  "path": "docs/auth.md",
  "section": 7,
  "jq": ".sections[7]"
}
```

---

## Phase 9: benchmarkと比較

### 作業

1. 20件以上のgold query
2. `rg` adapter
3. `mdq` adapter
4. full-read baseline
5. metrics出力
6. cold execution time計測
7. token削減率計測

### 完了条件

以下をレポートできる。

```text
mdctx Section Recall@1/3
mdq Section Recall@1/3
rg Section Recall@1/3
平均context token
全文比削減率
no-answer precision
```

---

# 19. 実装時の禁止事項

Codexは以下を行わないこと。

* `mdidx` の既存JSONを無断で変更する
* 既存テストを削除して通す
* test failureをskipへ変更する
* stdoutへlogを出す
* query処理に外部APIを使う
* embedding modelを追加する
* Python runtimeを必須化する
* `mdq` を先にvendorする
* parserを全面的に置き換える
* 依存追加を必要以上に行う
* 未使用の抽象化を大量に作る
* 将来用のdaemonやwatchを実装する
* benchmarkなしでranking weightを最適化したと主張する
* token数を正確なLLM token数として扱う
* confidenceを確率として表現する

---

# 20. コーディング要件

* `go fmt` を適用する
* `go vet ./...` を通す
* `go test ./...` を通す
* public typeとpublic functionへdoc commentを付ける
* error wrappingに `%w` を使う
* context cancellationが自然に入る箇所では `context.Context` を利用する
* filesystemアクセスをinterface化しすぎない
* deterministic testを優先する
* global mutable stateを避ける
* ranking weightは一か所へまとめる
* JSON schema typeは専用packageへ置く
* CLI packageへ検索ロジックを書かない

---

# 21. 各フェーズ終了時にCodexが報告する内容

各フェーズの作業後、以下を簡潔に報告する。

```text
変更したファイル
実装した内容
追加したテスト
実行したコマンド
テスト結果
既知の制約
次フェーズで行うこと
```

例:

```text
Changed:
- internal/markdown/section.go
- internal/markdown/section_test.go
- cmd/mdidx/main.go

Implemented:
- Shared Section model
- Parent and heading path calculation

Validation:
- go test ./...
- go vet ./...

Result:
- All tests passed
- mdidx golden output unchanged

Known limitation:
- Setext headings remain unsupported, matching existing behavior
```

---

# 22. 最初にCodexへ依頼する実装単位

一度に全ロードマップを実装させない。

最初の依頼では、Phase 1とPhase 2だけを実行する。

## Codexへの最初の指示

```markdown
このリポジトリに、Agent専用Markdown retrieval tool `mdctx` を追加する予定です。

今回は新機能をまだ実装せず、既存 `mdidx` の互換性固定と内部section modelの共有化だけを行ってください。

要件:

1. 現在の `mdidx` の実装とテストを調査する
2. 現在のJSON出力をgolden testで固定する
3. Markdownのsection生成ロジックをCLIから分離し、共有可能なinternal packageへ移す
4. 内部にSection modelを導入する
5. Sectionには最低限、Number、Heading、HeadingPath、Level、Parent、SubtreeEnd、Contentを持たせる
6. `mdidx` の既存JSON出力を一切変更しない
7. 既存CLIの利用方法を変更しない
8. 新しい外部依存を原則追加しない
9. `go fmt`、`go vet ./...`、`go test ./...` を実行する
10. 変更内容と既知の制約を最後に報告する

既存挙動を変更する必要がある場合は、変更せず理由を報告してください。
新しい `mdctx` コマンドはまだ追加しないでください。
```

---

# 23. 二回目以降のCodexへの指示

## Phase 3用

```markdown
前フェーズで共有化したMarkdown section modelを使って、`mdctx query` のCLI skeletonを追加してください。

今回は検索品質を実装せず、以下だけを実装してください。

- `mdctx query --q QUERY [PATH...]`
- Markdownファイル探索
- 共有section modelによるparse
- schema-valid JSON出力
- status、stats、resultsの基本構造
- stdoutとstderrの分離
- argument validation
- exit code
- unit testとintegration test

検索結果は一時的にheadingと本文の単純case-insensitive substring matchで構いません。

`mdidx` の出力と挙動は変更しないでください。
```

## Phase 4・5用

```markdown
`mdctx query` の検索品質を改善してください。

実装対象:

- Unicode normalization
- English tokenization
- Japanese trigram
- exact literal match
- filename、heading、heading path、bodyのfield weighting
- BM25
- exact identifier boost
- deterministic ranking
- normalized score
- unit test
- benchmark fixture

Embedding、外部API、Python依存、永続indexは追加しないでください。
```

## Phase 6・7用

```markdown
`mdctx query` にAgent向けcontext assemblyを追加してください。

実装対象:

- token estimator
- `--max-context-tokens`
- `--max-results`
- duplicate section除去
- oversized sectionの安全なtruncation
- complete_sectionとtruncated metadata
- confidence判定
- no_results
- insufficient_evidence
- warnings
- exit code
- budgetとconfidenceのテスト

stdoutは常にJSON専用としてください。
```

## Phase 8・9用

```markdown
`mdctx query` にplan modeとbenchmark基盤を追加してください。

実装対象:

- `--format plan`
- contentなしのcandidate出力
- `path`
- `section`
- `jq`
- `heading_path`
- `estimated_tokens`
- gold query corpus
- Section Recall@1/3
- MRR
- average delivered tokens
- no-answer precision
- full-read token reduction

可能であれば `rg` と既存 `mdq` を外部adapterとして比較してください。
`mdq` をvendorまたは必須依存にはしないでください。
```

---

# 24. v0.1完了時の期待例

入力:

```bash
mdctx query \
  --q "トークン更新失敗時の再試行回数" \
  --max-context-tokens 1200 \
  docs/
```

出力:

```json
{
  "schema_version": "1",
  "status": "ok",
  "query": "トークン更新失敗時の再試行回数",
  "strategy": {
    "search": [
      "literal",
      "heading",
      "bm25"
    ],
    "selection": "token_budget"
  },
  "budget": {
    "max_context_tokens": 1200,
    "estimated_content_tokens": 734
  },
  "stats": {
    "files_scanned": 18,
    "sections_scanned": 127,
    "candidates_considered": 6,
    "results_returned": 2
  },
  "results": [
    {
      "path": "docs/authentication.md",
      "section": 12,
      "jq": ".sections[12]",
      "heading": "Refresh retry policy",
      "heading_path": [
        "Authentication",
        "Token refresh",
        "Refresh retry policy"
      ],
      "score": 1.0,
      "confidence": "high",
      "estimated_tokens": 412,
      "complete_section": true,
      "truncated": false,
      "content": "### Refresh retry policy\n..."
    },
    {
      "path": "docs/errors.md",
      "section": 4,
      "jq": ".sections[4]",
      "heading": "Refresh failure",
      "heading_path": [
        "Authentication errors",
        "Refresh failure"
      ],
      "score": 0.72,
      "confidence": "medium",
      "estimated_tokens": 322,
      "complete_section": true,
      "truncated": false,
      "content": "## Refresh failure\n..."
    }
  ],
  "warnings": []
}
```

この出力をv0.1の到達点とする。
