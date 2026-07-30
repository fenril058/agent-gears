---
name: fast-search
description: コードベースに対する広域・意味的な探索(「どこで何が行われているか」「この機能はどう実装されているか」)が必要なときに使う。単純な文字列一致や既知ファイルの参照ではなく、複数ファイルにまたがる意味的な問いに、fastcontext で少ない手数で答える。
compatibility: fastcontext CLI が PATH に必要で、OpenAI 互換 API(環境変数 FC_API_KEY / FC_MODEL / FC_BASE_URL。旧名も利用可)も要る。どちらも skill には同梱されない。無い場合は設定不備として報告してから Grep/Read のフォールバックへ。入手は https://github.com/microsoft/fastcontext
---

# Fast Search (fastcontext)

広域の「どこで・何が」を、全文 Grep の総当たりではなく `fastcontext` で引く。
意味的な問いに対し、関連箇所を少ない手数で見つける。

## 前提(初回だけ設定)

`fastcontext` CLI は skill に同梱されない。
[microsoft/fastcontext](https://github.com/microsoft/fastcontext) から導入する。
PATH に無ければ後述の「フォールバック」を使う。

fastcontext は OpenAI 互換 API をバックエンドにする。
次の環境変数を読み、`FC_` 付きの名前を優先し、括弧内の旧名へフォールバックする。

- `FC_API_KEY` (`API_KEY`): OpenAI 互換エンドポイントの鍵
- `FC_MODEL` (`MODEL`): 使うモデル名
- `FC_BASE_URL` (`BASE_URL`): エンドポイント URL

鍵は各自の環境で設定する(コミットしない・nix store に置かない)。
Ollama の OpenAI 互換 API には、空でないダミーの鍵と
`http://localhost:11434/v1` のようなベース URL を指定する。
設定済みかは `fastcontext -q "test" --max-turns 1` で確認できる。
未設定・実行不能のときは下の「フォールバック」に従う。

## 使い分け

- 既知ファイル / 単純な文字列・記号の一致 → **Grep / Read**(fastcontext は使わない)。
- 「どこで認証している?」「この設定はどう読み込まれる?」のような
  複数ファイルにまたがる意味的な問い → **fastcontext**。
- 探索の結論だけ要る(本文ダンプ不要)で量が多く、**かつユーザーが委譲を求めた** →
  `search` サブエージェントへ渡す(依頼文の書き方は `model-routing` skill 参照)。
  求められていないのに自分から立てない。

## 使い方

```bash
fastcontext -q "認証トークンはどこで検証されるか"
```

出典(ファイル/箇所)だけ欲しいとき:

```bash
fastcontext -q "設定ファイルの読み込み経路" --citation
```

長い探索を区切るときは `--max-turns N`、挙動を追うときは `--verbose`。

## フォールバック(fastcontext が使えないとき)

黙って代替に落ちない。理由を1行で述べ、原因を切り分けて名指しする。

- **CLI か認証情報が無い**(command not found、`Missing credentials`):
  設定不備であり、想定される状態ではない。そう報告して環境を直せるようにする。
- **それ以外の理由で実行に失敗した**(接続拒否、タイムアウト、エンドポイント停止):
  設定不備と断定せず、原因未確認の実行失敗として報告する。設定自体は正しいかもしれない。

そのうえで広域・意味的な探索を次で代替して作業は続ける。
作業を止めず、fastcontext が使えないことを理由に全文 Read で抱え込まない。

- Grep/Glob/Read の組み合わせ。サブエージェントに読ませてよいなら Explore サブエージェント。

## やらないこと

- 1ファイルを読めば済む問いに fastcontext を回さない。
- fastcontext の結果を鵜呑みにせず、編集前に該当ファイルを実際に Read で確認する。
