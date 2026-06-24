---
name: fast-search
description: コードベースに対する広域・意味的な探索(「どこで何が行われているか」「この機能はどう実装されているか」)が必要なときに使う。単純な文字列一致や既知ファイルの参照ではなく、複数ファイルにまたがる意味的な問いに、fastcontext で少ない手数で答える。
---

# Fast Search (fastcontext)

広域の「どこで・何が」を、全文 Grep の総当たりではなく `fastcontext` で引く。
意味的な問いに対し、関連箇所を少ない手数で見つける。

## 前提(初回だけ設定)

fastcontext は OpenAI 互換 API をバックエンドにする。次の環境変数が要る。
未設定だと `Missing credentials` で落ちる。

- `API_KEY`: OpenAI 互換エンドポイントの鍵(`OPENAI_API_KEY` でも可)
- `MODEL`: 使うモデル名
- `BASE_URL`: エンドポイント URL(OpenAI 本家なら省略可)

鍵は各自の環境で設定する(コミットしない・nix store に置かない)。
設定済みかは `fastcontext -q "test" --max-turns 1` で確認できる。
未設定・実行不能のときは下の「フォールバック」に従う。

## 使い分け

- 既知ファイル / 単純な文字列・記号の一致 → **Grep / Read**(fastcontext は使わない)。
- 「どこで認証している?」「この設定はどう読み込まれる?」のような
  複数ファイルにまたがる意味的な問い → **fastcontext**。
- 探索の結論だけ要る(本文ダンプ不要)で量が多い → `search` サブエージェントに委譲
  (`model-routing` skill 参照)。委譲すればメインの文脈を汚さず安価に回せる。

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

fastcontext が未設定 / 実行不能(`Missing credentials` 等)のときは、広域・意味的な
探索を次で代替する。fastcontext の不在を理由に全文 Read で抱え込まない。

- Explore サブエージェント(読み取り中心の広域探索)、または Grep/Glob/Read の組み合わせ。
- 結論だけ要る・量が多いなら `search` サブエージェントへ委譲(`model-routing` skill)。

## やらないこと

- 1ファイルを読めば済む問いに fastcontext を回さない。
- fastcontext の結果を鵜呑みにせず、編集前に該当ファイルを実際に Read で確認する。
