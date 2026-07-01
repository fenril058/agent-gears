---
name: durable-knowledge-export
description: >-
  ブランチを越えて永続させる知見を、最適な永続置き場——あれば GitHub wiki、無ければリポジトリ内 docs——に書き出す。現在のブランチ/PR を越えて残す価値のある発見(実測値、ツール評価、アーキテクチャ判断、規約、システム自体に関わる横断的な落とし穴)のときに使う。
  まず永続/揮発を判定する。揮発する(ブランチ単位の)文脈は conversation-context-export 側へ回す。
  トリガ: 「永続知見として保存して」「wiki/docs に書いて」「これはブランチを越えて残すべき」。
compatibility: git と gh CLI(GitHub CLI・認証済み)が PATH に必要。gh はリポジトリ状態の取得と GitHub wiki への書き込みに使う。gh の入手は https://cli.github.com
---

# 永続知見の書き出し手順書

発生元ブランチが消えても有用な知見=**永続知見**を、最適な永続置き場に書き出し、その置き場の索引を同期する。

これは**永続層**である。対になるのは `conversation-context-export`(**揮発層**: ブランチ/PR 単位の文脈を `.dev/contexts/` + PR コメントへ)。セクション1の判定で発見を正しい層へ振り分ける。

永続置き場は**sink 解決**(セクション2)で選ぶ: 到達可能な GitHub wiki があればそれを優先、無ければリポジトリ内 docs。セクション1の判定は不変で、**sink だけ**が環境に応じて変わる。

## 1. 判定: 永続か揮発か

以下の**3条件すべて**を満たすときだけ、その発見を**永続**とみなす:

1. 特定の変更ではなく、**プロジェクト/システム/ツール自体**についての知見である
2. 発生元ブランチが merge または破棄された**後も**有用である
3. **無関係な別ブランチの将来セッション**が恩恵を受ける、または放置すると再発見してしまう種類である

鋭い判別テスト:

- **ブランチ削除テスト**: 「このブランチが半年後に消えても、これは要るか?」要る→永続。
- **タイトルテスト**: 自然なタイトルが**話題/概念**(永続)か、**ブランチ/PR/変更**(揮発)か。
- **種別テスト**: 実測値、ツール評価、アーキテクチャ判断(ADR)、規約・方針、システム横断の落とし穴→永続。特定変更の根拠、*この* PR の却下代替案、*この*ブランチの残作業、一度きりのデバッグメモ→揮発。

振り分け:

- **揮発** → この skill は使わない。`conversation-context-export` を使う。
- **混在** → 分割する: 永続的な事実は永続置き場へ、変更の根拠は `conversation-context-export` へ。
- **不明** → 発見と判定をユーザーに提示し、どちらの層か尋ねる。

## 2. sink を解決する

以下の順で永続置き場を選ぶ。推測せず明示的に解決する。

```
gh repo view --json url,hasWikiEnabled -q '.url, .hasWikiEnabled'
```

(`gh` が失敗する、または GitHub remote が無い repo なら「wiki 無し」とみなしてリポジトリ内 docs へ。)

1. **GitHub wiki(優先)** — 出力の URL を `{repo-url}` とする。到達性を確認:
   ```
   git ls-remote {repo-url}.wiki.git
   ```
   ref が列挙されれば sink は **wiki** → セクション3A。
2. **到達可能な wiki が無い** → sink は **リポジトリ内 docs** → セクション3B。
   - フォールバック時、ユーザーへ一言: wiki を使いたいなら、Wikis を有効化し最初のページを web UI で1度作成してから再実行する。(未初期化の wiki は push では作れない。`has_wiki` の有効化だけでは初回ページは作られない。)

書き込む前に、どの sink を選んだか・理由を述べる。

## 3A. sink: GitHub wiki

wiki は別 git リポジトリで内容用 REST API が無いため、clone → 編集 → push。

1. セッションのスクラッチディレクトリ(メイン repo の作業ツリー外)へ clone:
   ```
   git clone {repo-url}.wiki.git {scratch}/repo.wiki
   ```
   ユーザーの git が使うプロトコルに合わせる(`gh auth status` で ssh/https 確認)。ssh なら `git@github.com:owner/repo.wiki.git`。
2. **ページ**: house style に合わせた話題名のファイル(例: `SKILL-token-ja-en.md`)。新規→作成。既存→まず読み、セクション4の更新ルールを適用。
3. **索引**: `Home.md` のページ一覧見出しの下に、無ければ `- [[{PageName}]] — {一言}` を追加。
4. **確認してから push**(wiki への書き込みは外部公開——セクション5):
   ```
   git add {PageName}.md Home.md && git commit -m "{メッセージ}" && git push
   ```
   commit には git identity が要る。グローバルの `user.name`/`user.email` が未設定だと
   (新規 clone では起こりがち)commit が失敗するので、repo の identity をインラインで渡す:
   `git -c user.name='...' -c user.email='...' commit -m "{メッセージ}"`(値はメイン repo の
   `git config user.name`/`user.email` を流用する)。
5. 報告するページ web URL: `{repo-url}/wiki/{PageName}`。

## 3B. sink: リポジトリ内 docs

メイン repo 内の版管理された docs ディレクトリ。`.dev/contexts/`(揮発・非マージ)と違い、これは **docs-as-code**: 通常の PR フローでデフォルトブランチに commit・merge され、そこに恒久的に残る。

1. **ディレクトリ**: 既定 `docs/knowledge/`。無ければ作成。(repo に慣習的な docs 置き場が既にあればそちらを優先し、ユーザーに伝える。)
2. **ページ**: `docs/knowledge/{Topic}.md`、話題名。新規→作成。既存→まず読み、セクション4の更新ルールを適用。
3. **索引**: `docs/knowledge/README.md` を維持。そのページ一覧見出しの下に、無ければ `- [{Topic}]({Topic}.md) — {一言}` を追加。索引が無ければその見出しごと作成する。
4. **この skill からは commit/push しない。** ファイルを作業ツリーに書き、現在のブランチに対するユーザーの通常の commit/PR に乗せる(merge されて初めて永続化する)。ファイルを書いて commit 可能にした旨をユーザーに伝える。

## 4. ページ本文と更新ルール

この skill のディレクトリの [TEMPLATE.md](TEMPLATE.md) を読み、両 sink で従う。要点:

- ページを**自己完結**させる: 発生元ブランチは消えるので、単独で成立する文脈を含める。
- 実測・評価は**日付と出典コマンド/コミット**を記録し、後から陳腐化が分かるようにする。
- `conversation-context-export` と同じ「重点/薄くてよい」の規律: 永続的な事実・判断とその根拠であって、苦労話やコードを読めば自明なことは書かない。

既存ページの更新(どちらの sink もセッション横断、wiki は場合により著者横断):

- 既存の項目は原則残し、新情報を追記する。
- **実際に追試して反証したものだけ**を修正・削除する。推論だけでは削除しない。
- ページは常に現時点で正しい状態を表す。履歴は git に任せる(ページ内に取り消し線・変更履歴を残さない)。

## 5. 確認と報告

- **wiki sink**: push の前に、下書きしたページと `Home.md` の変更をユーザーに提示して確認——ユーザーが既に「確認なしで push」と言っていない限り AskUserQuestion を使う。push 後にページ web URL を報告。
- **リポジトリ内 docs sink**: 作業ツリーへの書き込みは確認不要(通常の PR に乗る)。書き込んだファイルパスを報告。
- 発見を分割した場合は、`conversation-context-export` へ回した内容も報告する。

## 関連スキル

- **conversation-context-export**: 揮発層——ブランチ/PR 単位の文脈を `.dev/contexts/` + PR コメントへ。揮発する発見はこちらへ回す。
- **conversation-context-import**: 保存した揮発文脈を読み込む。
