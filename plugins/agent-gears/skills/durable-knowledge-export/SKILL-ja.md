---
name: durable-knowledge-export
description: >-
  永続させる知見を、リポジトリの外の永続置き場——GitHub wiki、または専用の knowledge リポジトリ——に書き出す。現在のブランチ/PR を越えて残す価値のある発見(実測値、ツール評価、規約、システム自体に関わる横断的な落とし穴)のときに使う。
  まず永続/揮発を判定する。揮発する(ブランチ単位の)文脈は conversation-context-export 側へ、このコードベースのアーキテクチャ判断は domain-modeling 側へ回す。
  トリガ: 「永続知見として保存して」「wiki に書いて」「これはブランチを越えて残すべき」。
compatibility: git と gh CLI(GitHub CLI・認証済み)が PATH に必要。gh はリポジトリ状態の取得と GitHub wiki への書き込みに使う。knowledge リポジトリ sink はさらに環境変数 AGENT_KNOWLEDGE_REPO(ローカルの git リポジトリを指す)を要求する。未設定ならその sink は使えず、置き場所を勝手に作らずに中止する。
---

# 永続知見の書き出し手順書

発生元ブランチが消えても有用な知見=**永続知見**を、**リポジトリの外**の永続置き場に書き出し、その置き場の索引を同期する。

リポジトリの外であることが肝心である。
作業ツリーの中に落ちた永続知見は、由来したブランチと絡まり、リポジトリ自身の記録と競合する。この skill は意図的に外へ書く。

これは**永続層**である。対になる層が2つある。

- `conversation-context-export` — **揮発層**(ブランチ/PR 単位の文脈を `.dev/contexts/` + PR コメントへ)。
- `domain-modeling` — **記録層**(このコードベースの用語集とアーキテクチャ決定記録。コードと一緒に commit される)。

セクション1の判定で発見を振り分ける。

永続置き場は**sink 解決**(セクション2)で選ぶ: リポジトリに紐づく知見は到達可能な GitHub wiki、リポジトリをまたぐ知見は専用の knowledge リポジトリ。セクション1の判定は不変で、**sink だけ**が環境に応じて変わる。

## 1. 判定: 永続か揮発か

以下の**3条件すべて**を満たすときだけ、その発見を**永続**とみなす:

1. 特定の変更ではなく、**プロジェクト/システム/ツール自体**についての知見である
2. 発生元ブランチが merge または破棄された**後も**有用である
3. **無関係な別ブランチの将来セッション**が恩恵を受ける、または放置すると再発見してしまう種類である

鋭い判別テスト:

- **ブランチ削除テスト**: 「このブランチが半年後に消えても、これは要るか?」要る→永続。
- **タイトルテスト**: 自然なタイトルが**話題/概念**(永続)か、**ブランチ/PR/変更**(揮発)か。
- **種別テスト**: 実測値、ツール評価、規約・方針、システム横断の落とし穴→永続。特定変更の根拠、*この* PR の却下代替案、*この*ブランチの残作業、一度きりのデバッグメモ→揮発。

振り分け:

- **揮発** → この skill は使わない。`conversation-context-export` を使う。
- **このコードベースのアーキテクチャ判断** → この skill は使わない。`domain-modeling` を使う。
  ADR は不変で、説明対象のコードと同じ履歴に載る。一方ここのページは常に現在状態を示す living document なので、決定をここに置くと「決めて後で覆した」という記録が失われる。
  このプロジェクトの用語も同じで、`CONTEXT.md` すなわち `domain-modeling` の担当である。
- **混在** → 分割する: 永続的な事実は永続置き場へ、変更の根拠は `conversation-context-export` へ、決定は `domain-modeling` へ。
- **不明** → 発見と判定をユーザーに提示し、どちらの層か尋ねる。

## 2. sink を解決する

sink は推測せず明示的に解決する。決めるのは2つの問いである。**その知見が何に紐づくか**、次に**何が到達可能か**。

### 2-1. スコープ

- **リポジトリ単位** — *この* リポジトリについての知見(ビルド、癖、ここで採った実測値)。2-2 へ。
- **リポジトリ横断** — 複数のリポジトリにまたがる知見(どこでも使うツールの評価、このマシンの環境の癖、プロジェクト横断で適用する規約)。wiki は1つのリポジトリに属するのでこれを保持できない。sink は **knowledge リポジトリ** → セクション3B。knowledge リポジトリが未設定なら 2-3 へ。

### 2-2. 到達性(リポジトリ単位の知見)

```
gh repo view --json url,hasWikiEnabled -q '.url, .hasWikiEnabled'
```

(`gh` が失敗する、または GitHub remote が無い repo なら「wiki 無し」とみなす。)

1. **GitHub wiki(優先)** — 出力の URL を `{repo-url}` とする。到達性を確認:
   ```
   git ls-remote {repo-url}.wiki.git
   ```
   ref が列挙されれば sink は **wiki** → セクション3A。
2. **到達可能な wiki が無く、knowledge リポジトリが設定済み** → sink は **knowledge リポジトリ** → セクション3B。
   - ユーザーへ一言: wiki を使いたいなら、Wikis を有効化し最初のページを web UI で1度作成してから再実行する。(未初期化の wiki は push では作れない。`has_wiki` の有効化だけでは初回ページは作られない。)
3. **どちらも無い** → 2-3 へ。

### 2-3. 使える sink が無い場合

**勝手に作らない。**
永続知見を作業ツリーに書くことこそこの skill が避けるためにあるものであり、スクラッチディレクトリでは失われる。

中止し、どの確認が失敗したかをユーザーに伝え、進み方を2つ示す。

- **wiki を有効化する** — Wikis をオンにし、最初のページを web UI で1度作成する。知見をチームに届けたいならこちら。
- **knowledge リポジトリを用意する** — git リポジトリを作り `AGENT_KNOWLEDGE_REPO` で指す(レイアウトはセクション3B)。個人用・リポジトリ横断の知見ならこちら。

判断を待つ間に失われないよう、発見の全文を返答の中に書く。

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

## 3B. sink: knowledge リポジトリ

永続知見のための専用 git リポジトリ。記述対象のどのプロジェクトの外にも独立して存在する。
`AGENT_KNOWLEDGE_REPO` がそのローカルパスを保持する。
複数リポジトリにまたがる知見を置ける唯一の sink であり、wiki を持たないリポジトリのフォールバックでもある。

### レイアウト

ページは記述対象リポジトリのパスの下に置く。ghq のレイアウトを写すので、場所は記憶ではなく計算で出る。

```
{AGENT_KNOWLEDGE_REPO}/
  README.md                       ← 全体索引
  github.com/{owner}/{repo}/
    README.md                     ← リポジトリ単位の索引
    {Topic}.md
  _cross/
    README.md
    {Topic}.md                    ← リポジトリをまたぐ知見
```

`{owner}/{repo}` は対象リポジトリの remote から求める。ディレクトリ名から求めてはいけない。
origin を張り替えた fork ではディレクトリが upstream owner のままなので、両者は食い違う。

### 手順

1. **場所の解決**: `AGENT_KNOWLEDGE_REPO` を読む。未設定、またはそのパスが git リポジトリでなければセクション2-3 の状況である。黙って作らずに中止する。
2. **ページ**: `{scope-path}/{Topic}.md`、話題名。`{scope-path}` はリポジトリ単位なら `github.com/{owner}/{repo}`、横断なら `_cross`。新規→作成。既存→まず読み、セクション4の更新ルールを適用。
3. **索引**: 同じディレクトリの `README.md` を維持し、ディレクトリが新規なら全体の `README.md` にも追加する。ページ一覧見出しの下に、無ければ `- [{Topic}]({Topic}.md) — {一言}` を追加。索引が無ければその見出しごと作成する。
4. **確認してから commit** する。対象はプロジェクトのリポジトリではなく knowledge リポジトリである:
   ```
   git -C {AGENT_KNOWLEDGE_REPO} add {scope-path} README.md && git -C {AGENT_KNOWLEDGE_REPO} commit -m "{メッセージ}"
   ```
   identity が未設定の場合の注意は 3A のステップ4と同じ。
5. **upstream があるときだけ push する。** `git -C {AGENT_KNOWLEDGE_REPO} remote` で確認し、remote があれば push は外部公開になるので先に確認する(セクション5)。remote が無ければローカル commit で完了であり、URL を報告せずその旨を述べる。

## 4. ページ本文と更新ルール

この skill のディレクトリの [TEMPLATE.md](TEMPLATE.md) を読み、両 sink で従う。要点:

- ページを**自己完結**させる: 発生元ブランチは消えるので、単独で成立する文脈を含める。
- 実測・評価は**日付と出典コマンド/コミット**を記録し、後から陳腐化が分かるようにする。
- `conversation-context-export` と同じ「重点/薄くてよい」の規律: 永続的な事実とその根拠であって、苦労話やコードを読めば自明なことは書かない。

既存ページの更新(どちらの sink もセッション横断、wiki は場合により著者横断):

- 既存の項目は原則残し、新情報を追記する。
- **実際に追試して反証したものだけ**を修正・削除する。推論だけでは削除しない。
- ページは常に現時点で正しい状態を表す。履歴は git に任せる(ページ内に取り消し線・変更履歴を残さない)。

## 5. 確認と報告

- **wiki sink**: push の前に、下書きしたページと `Home.md` の変更をユーザーに提示して確認——ユーザーが既に「確認なしで push」と言っていない限り AskUserQuestion を使う。push 後にページ web URL を報告。
- **knowledge リポジトリ sink**: commit の前に、下書きしたページと索引の変更を提示する。remote があれば push は公開になるので、wiki と同様に別途確認する。ファイルパスと commit を報告。
- 発見を分割した場合は、`conversation-context-export` と `domain-modeling` へ回した内容も報告する。

## 関連スキル

- **conversation-context-export**: 揮発層——ブランチ/PR 単位の文脈を `.dev/contexts/` + PR コメントへ。揮発する発見はこちらへ回す。
- **conversation-context-import**: 保存した揮発文脈を読み込む。
- **domain-modeling**: 記録層——このコードベースの用語集(`CONTEXT.md`)とアーキテクチャ決定記録。コードと一緒に commit される。決定と用語はこちらへ回す。living page ではなく不変の記録だからである。
