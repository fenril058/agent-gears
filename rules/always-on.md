# 常時ルール (context-engineering)

全エージェント共通の不変則。詳細手順は各項目が指す skill 側にある。

## 用語

- 定義していない用語や勝手な造語を導入しない。その分野で確立した術語を使う。
  新語が必要なら初出で定義する。詳細点検は `no-neologism` skill。

## 文脈効率(トークン削減)

- 大きな Markdown を理由なく全文読みしない。索引から必要な節だけ取る(`markdown-context` skill / `mdidx`)。
- コードベースの広域・意味的な探索は全文 Grep の総当たりでなく `fastcontext`(`fast-search` skill)。
- 重くないが量の多い作業(機械的編集・反復・広域探索)は、安価モデルのサブエージェントへ委譲する(`model-routing` skill)。重い判断はメインに残す。
