# Independent reading prompt

Use this when an independent reading without project background is useful or requested.
Choose an available execution method as described in the parent [SKILL.md](../SKILL.md).
Supply document paths or contents and relevant references; omit the main conversation, project summary, suspected gaps, and intended answers.
The reader must not inherit that background through conversation history or memory.
Give the reader the complete document, not just passages the main agent suspects.

## English

```text
Read the following documents as an engineer who must implement the described behavior:

<documents and relevant references>

Identify ambiguities, contradictions, undefined terms, or missing decisions that leave materially different implementations possible within the documents' scope.
For each candidate, state the unresolved question and how the implementation would differ.
Cite the relevant file and line numbers when available, otherwise a section or quotation.
For an omission, identify the section that would need the missing rule; do not invent a citation or discard a gap solely because no sentence states it.

Use only these sources, including relevant references they identify.
Check relevant definitions and other sections before raising a question.
Identify any necessary reference you cannot access as a verification limit.
Do not consult unrelated code, project history, or memory, guess the intended answer, redesign the system, edit documents, or implement anything.
Respect exclusions and choices the documents leave to the implementer.
Combine duplicates and prioritize decisions that affect behavior; do not pad the list to reach a count.
No findings is an acceptable result.
```

## Japanese

```text
以下の文書に記述された振る舞いを実装するエンジニアとして読んでください。

<文書と関連する参照先>

文書の範囲内で、実質的に異なる実装が可能なまま残る曖昧さ、矛盾、未定義の用語、欠けた判断を探してください。
各候補には、未解決の疑問と、それによって実装がどう変わるかを示してください。
該当するファイルと行番号を示し、行番号を使えなければ節や引用で位置を示してください。
欠落は必要な規則があるべき節に結び付けてください。
引用を捏造したり、記述がないという理由だけで欠落を除外したりしないでください。

根拠はこれらの資料と、資料が示す関連する参照先に限ってください。
疑問を挙げる前に、関連する定義と別の節を確認してください。
必要な参照先を読めなければ、確認の限界として示してください。
無関係なコード、プロジェクトの履歴、記憶は調べず、想定解の推測、再設計、文書編集、実装は行わないでください。
対象外の事項と、文書が実装者に任せている選択を尊重してください。
重複をまとめ、振る舞いに影響する判断を優先し、件数を満たすために水増ししないでください。
指摘がゼロでも構いません。
```
