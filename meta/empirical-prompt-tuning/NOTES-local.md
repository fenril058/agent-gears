# NOTES-local — empirical QA をこのリポジトリの skill に当てるときの追補

このファイルは **ローカル併置ノート**。隣の `SKILL.md`(英語正本)/ `SKILL-ja.md`(日本語ミラー)は上流
([mizchi/skills](https://github.com/mizchi/skills/tree/main/meta/empirical-prompt-tuning))
から取り直す前提なので直接編集しない。上流取り直しでも消えないよう、運用の追補はここに置く。

出典: 下記 3 点は [`waxa-eval`](https://github.com/mizchi/skills/tree/main/meta/waxa-eval)
(mizchi/skills, MIT)由来の知見を、`empirical-prompt-tuning` の session 内 subagent
ループ(`SKILL.md` ワークフロー 2〜6)へ持ち込めるよう書き直したもの。waxa CLI 本体は
未導入。CI 再現性 / ledger 永続化 / 外部公開の回帰防止が要るようになったら、そのとき
`meta/waxa-eval/` を上流から取り直して導入する(`SKILL.md` 末尾「関連」の補完関係を参照)。

## 1. 要件チェックリストを「surface + semantic」のペアで持つ

`SKILL.md` の要件チェックリスト(ワークフロー 1, 4)の各軸を、可能なら 2 本立てにする:

- **surface 判定**: 成果物に特定トークンが出たか。**日英両方の表記を必ず入れる**。
  この repo は日本語 skill が中心なので取りこぼしが頻発する。例:
  `スクレイプ` / `scrape`、`非互換` / `incompatible`、`信頼` / `trust`、
  `止める` / `stop` / `defer`。1 軸につき広い alternation でまとめる。
- **semantic 判定**: 同じ軸を意味等価で見る(subagent の自己申告 ○/×/部分的)。

surface だけだと「言い換え・略語・日本語表記」で false negative が出る。semantic が ○ で
surface が × のときは **判定文言(surface 側)を広げる**。シナリオ側を「この語を使え」と
縛らない(skill の自然な出力を歪める)。

## 2. 4 段階トラジェクトリを収束の目安に使う

構造的に健全な skill は **3〜4 iteration** で収束する。各 iter がどの段階かを見る:

| 段階 | 直すもの | 兆候 |
|---|---|---|
| 1. 構造欠落 | 振る舞いが丸ごと欠けている(skill が X を指示していない) | surface も semantic も**両方**落ちる。1 修正で pass 率が跳ねる |
| 2. 判定の幅 | skill は正しいが surface 判定が狭すぎる | semantic ○ / surface × が同じ軸で出る → regex を広げる |
| 3. surface 表記 | LLM が日本語・同義語・略語を使い、判定が拾えない | 片方の trial だけ落ちる。中身ではなく表記の取りこぼし |
| 4. 残余 | eval 設定の構造的限界(下記 3)で、skill 本体の問題ではない | 自己申告が「外部実行 stuck」を出す。台帳に記録し追わない |

4 iter を超えても減らないなら、`SKILL.md` の「発散」基準どおり設計を疑う(パッチを続けない)。

## 3. Execution の stuck は 2 種類 — 実行できるなら実行させる

`fast-search` / `markdown-context` は実ツール(`mdidx` / `fastcontext` / `mq`、Web 取得、
外部 CLI)の実行を前提にする。評価で Execution が stuck になったら、原因を必ず切り分ける:

- **環境起因**(ツールが無い・API キー未設定・ネットワーク禁止)→ **false signal**。
  skill の欠陥ではない。台帳に「eval 環境制約」と記録して追わない。
- **指示起因**(ツールはあるのに、skill の説明では何をどう打てばいいか分からない)→
  **本物の欠陥**。これが直す対象。

### 方針

- **実行できる環境を整えて実行させる**。これが唯一の正規ルート。実行すれば end-to-end の
  本物の Execution シグナル(フラグ違い・出力形式の想定ズレなど、動かして初めて出る失敗)が取れる。
- **実行不能なら、その軸は評価せず止めて報告する**。narrate で代替しない。口で説明させると
  「もっともらしいが間違った手順」が pass し、実ツールを通っていない偽の合格が出る。
  これは `SKILL.md`「環境制約」節の哲学(dispatch 不能を自己再読で代替せず
  `empirical evaluation skipped` と正直に報告する)と同じ。

実行不能を検出したら、当該軸を「環境未整備で未評価」と明示し、ユーザーに環境整備を促す。例:

```
fast-search の Execution 軸は fastcontext の実行が必要だが、
この環境では API_KEY 未設定で動かせない。
→ この軸は未評価。fastcontext を設定して再実行してほしい。
```

環境整備はユーザーの責務。評価側が narrate で穴埋めして「測れたことにする」のが最悪手。
