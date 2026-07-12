# Pass-1 prompt template

See the parent SKILL.md's *Platform implementations* section for how to dispatch this
on your platform (Claude Code: `Agent` tool with `model: haiku`; Codex: a separate
`/model`-switched session). Fill in only the file path — do not add project background,
do not summarize what the document is for beyond what's needed to name the file.

## English

```
You are the engineer who will implement this software. Read the following document:

<path>

List, as concretely as possible, every point where you cannot tell — from this
document alone — which of several implementations is intended: ambiguous wording,
contradictions, undefined terms, or gaps.

- Cite the line number(s) in the document for every item. Skip anything you can't
  cite a line number for.
- Prioritize points where the implementation would actually branch, not wording
  nitpicks.
- Do not guess at an answer or fill the gap yourself. List the question only.
- No cap on the number of items — list everything you notice.

I have no additional background on this document or project to give you. Base your
judgment on the document text alone.
```

## Japanese (knot プロジェクトなど日本語仕様書向け)

```
あなたはこれからこのソフトウェアの実装を任されるエンジニアです。以下の文書を読んでください。

<path>

実装を始めるにあたって「この文書だけでは判断できない」「曖昧で複数の解釈ができる」
「矛盾している」「未定義・抜けている」と感じた点を、できるだけ具体的に箇条書きで
挙げてください。

- 各項目には、文書中の該当箇所の行番号を必ず明記してください。行番号がわからない
  場合はその項目を書かないでください。
- 些細な言葉遣いの指摘ではなく、実装方針が分岐しうる点を優先してください。
- 件数の上限は設けません。気づいた点をすべて挙げてください。
- 自分で仮定して答えを埋めたり、推測で解決したりしないでください。疑問点の列挙
  だけを行ってください。

この文書やプロジェクトについて、私からの追加の背景説明はありません。文書本文だけ
を根拠に判断してください。
```

## Why line-number citation is mandatory, not a nice-to-have

Pass 2 filters by extracting only the cited line's surrounding context. An item
without a citable line number can't be checked mechanically and either gets dropped
silently or forces a full-document read to place it — both defeat the point of the
two-pass design. Instruct the model to omit uncitable items rather than guess a line
number, since a wrong citation is worse than no item (it makes pass 2 check the wrong
place and wrongly clear the item as "already answered").
