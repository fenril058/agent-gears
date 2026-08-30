---
status: accepted
date: 2026-08-30
---

# 到達可能性レベルの隔離を立証できない評価基盤を維持しない

agent-gears は、skill と常時ルールを評価するための汎用 eval infrastructure を、現役機能として維持しない。
今後の empirical evaluation は static audit と各 host の first-party tooling を先行させる。

対象を限定した custom measurement を作るのは、具体的な未解決点、その測定が変更する判断、時間箱、停止条件に加えて、次を満たす検証可能な隔離境界が揃った場合だけとする。

- 候補なし arm では、候補を全経路から到達不能にする。
- すべての arm で、評価条件を秘匿する。
- 対象名は、候補自体から判明する場合を除き、runner、実行環境、scenario world から漏洩させない。
- それ以外の観測可能な環境は、arm 間で等価にする。

## なぜ

2026-08-25 から 08-29 にかけて、corpus schema、validator、renderer、comparator、CI gate からなる基盤を構築した(issue #42、#50 / PR #43–#48, #51)。
そこで判明した一次的な問題は、汎用化の順序ではなく、比較の因果的妥当性そのものにある。

候補を withhold するとは、executor から到達不能にすることを意味する。
到達経路は作業ツリーだけではない。
host の設定下にインストールされた複製、他の arm が使用中または残した複製、シナリオが executor を置く checkout 内の複製、tip から消えても Git の履歴・refs・remote から到達できる複製を含む。
候補を渡されない arm に対しても、対象名は cwd と兄弟ディレクトリ名、プロセス引数、環境変数、Git metadata、隣に置かれた無関係な skill の description など、複数の経路から漏れる。
skill の無効化、作業ツリーからの削除、名前の置換のいずれも、この条件を満たさない。

既存の run では、この到達可能性レベルの隔離が成立していたことを立証できていない。
したがってそれらは、候補による因果的な効果を示す証拠として引用できない。
schema、comparator、gate をどれだけ厳密にしても、測定結果の因果的妥当性は補強できない。

隔離境界の提供主体は問わない。
first-party の機能でも、クリーンな VM やコンテナでも、境界が検証できるなら要件を満たす。

## Considered options

- **汎用 eval platform を完成させる。**
  厳密な隔離と cross-host 共通測定を得るが、隔離境界の構成という未解決問題を repo が所有し続ける。
  host は4つあり model は変わるため、この保守は恒常的に発生する。
- **評価を行わない。**
- **static audit と first-party tooling を優先し、隔離境界を構成できた具体的な未解決点だけを custom measurement で補う。**

三つ目を採用した。

## Consequences

tracked な custom eval infrastructure、対応する CI ステップ、README の利用案内、AGENTS.md の運用規則は、この ADR と同じ PR で削除する。
ADR だけ先に入れると、「維持しない」と書いた記録と、維持されている実体が、同時に main に存在する期間ができる。

`empirical-prompt-tuning` skill は削除せず、first-party-first の方法論に縮小する。
隔離境界の要件(到達経路と対象名の漏洩経路)は短縮して同 skill に残す。
削除対象のうちこれだけは、次に測定を検討する人が必要とするその瞬間に到達できる場所に無ければ意味がないからである。
Git 履歴は、その瞬間には参照されない。

過去の測定値は、この決定に至った経緯としては残るが、因果的な効果の証拠としては扱わない。

将来あらためて具体的な未解決点が生じても、過去の汎用 framework を当然には復活させない。
その時点の first-party tooling と、そこで構成できる隔離境界から再判断する。

host または model の前提が変わったときは、全体 benchmark ではなく health check を行う。
対象は、常時ルールと新しい system/tool description の競合確認、暗黙起動して副作用を持つ skill の near-miss、実利用で観測された失敗に限る。
host/model をまたいだ結果を平均して単一の総合評価にはしない。
