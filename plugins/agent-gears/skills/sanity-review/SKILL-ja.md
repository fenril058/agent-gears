---
name: sanity-review
description: >-
  PRまたは明示されたcommit rangeについて、説明、利用可能な対話コンテキスト、判断や非対応の根拠を実装と照合してレビューする。
  sanity-review、PRのレビュー報告書、対話コンテキストや過去の判断と実装を照合するレビューを依頼されたときに使う。
argument-hint: "[PR-URL-or-number | review brief + Reviewed head + Comparison basis]"
compatibility: >-
  ローカル調査にはgitが必要。
  Gitのオプションはbuildにより異なる(本文参照)。
  GitHub PRのレビューには利用可能なツールまたはgh CLI(https://cli.github.com)による認証済みのGitHub読取アクセスが必要。
---

# Sanity review

変更の説明と利用可能な実装時の文脈から、根拠のない前提、見落とした影響、実際の変更の欠陥を調べる。
exportされた文脈には、差分に現れない却下案、失敗した試行、意図的な非対応が含まれうる。
これらの記録は検証対象の主張であり、コードの振る舞いや判断の妥当性を保証するものではない。
文章の出来やAIらしさから、実装者の理解や執筆者を推測しない。

依存更新でも、明示的に起動された場合は適用する。
通常の依存更新レビューに、このSkillや特定の組込レビューコマンドを自動的に要求しない。

## 対象と操作の境界

- 明示されたPRを優先する。
  明示的なnon-PR rangeには、review brief・変更の説明、Reviewed head、Comparison basisが必要であり、不足する入力だけをコードのレビュー前に利用者へ確認する。
  不完全なrangeの依頼を、現在ブランチの無関係なPRへ置き換えない。
  どちらも指定されていなければ、現在ブランチに関連するPRを対象にできる。
  特定できなければ対象を確認する。
- **Reviewed head**はレビューするコードのexact commitである。
  **Comparison basis**は実際に調べる差分の起点のexact commitである。
  コードを読む前にrefを一度解決し、両方のSHAを記録する。
  PRではheadとbaseのSHAを取得し、差分の起点を別途確定する。
  通常は両者のmerge baseであり、baseブランチの先頭をそのまま起点としない。
  shallow historyで確定できなければ、SHAを固定し検証した比較metadataか隔離したリポジトリを使う。
- 元のcheckoutとremoteはread-onlyとする。
  修正、整形、ファイル生成、index更新、ブランチ切替、ref・履歴変更、元のGit metadataへのfetch、外部投稿を行わない。
  修正案は会話に報告する。
  報告書の保存や投稿には利用者の指示または既存の許可が必要である。
  元のGit metadataがread-onlyであることだけを理由にcloneしない。

## レビュー対象revisionの証拠

報告書のReviewed head、差分のhead、レビューするリポジトリ内ファイル、実行検証環境の元commitを一致させる。
そのcommitを含むdescendantも別のrevisionである。
必要なobjectがあれば、worktreeがdirtyでも別revisionでも、元のGitに対する保護付きのrevision指定読取を静的調査に使う。
worktreeのファイルを使うのは、HEADがReviewed headと一致し、tracked・untrackedの変更がないと確認できた場合だけとする。
status確認時も、対応buildの`git --no-optional-locks status`などで任意のindex更新を避ける。
古いコードは比較用の証拠と示し、Reviewed headのコードとして扱わない。
revisionの一致を確立できなければ、その阻害要因を報告し、そのcommitのレビューを完了したとは述べない。

元のGit objectを読む前に次の保護を適用する([Gitのオプション](https://git-scm.com/docs/git)、[partial cloneの説明](https://git-scm.com/docs/partial-clone)を参照)。

- refの解決、`show`、`diff`、`log`、`merge-base`を含むすべてのobject・履歴読取で、`git --no-lazy-fetch`により暗黙のlazy fetchを止める。
  commit objectの確認成功だけでは、tree・blobや祖先の履歴が揃っているとはいえない。
  履歴を根拠にする前に`git --no-lazy-fetch rev-parse --is-shallow-repository`を確認する。
  `log`が成功しても履歴が欠けていることがある。
- buildが`--no-lazy-fetch`を拒否した場合、`git config --get-regexp '^(remote\..*\.promisor|extensions\.partialclone)$'`でpromisor・partial clone設定の不在を確立するまで、保護なしで再実行しない。
  該当設定なしの終了状態と、問合せ自体の失敗を区別する。
  それ以外は下記の代替経路を使う。
  buildの対応を確認せず`GIT_NO_LAZY_FETCH=1`へ置き換えない。
  未対応buildは黙って無視しうる。
- `diff`、`show <commit>`、`log -p`でpatchを出すときは、Reviewed headのattributesを選び、外部diff driverとtextconvを無効にする。
  対応するGit buildでの例:

  ```bash
  git --no-lazy-fetch --attr-source=<head-SHA> diff --no-ext-diff --no-textconv <basis-SHA> <head-SHA>
  git --no-lazy-fetch show <head-SHA>:<path>
  ```

  これは例であり、どのbuildでも実行できる保証はない。
  attributesの選択に未対応なら、別worktreeのattributesで差分を変えず、SHAを固定したAPIか隔離したリポジトリを使う。
- object・履歴の不足には、SHAを固定したAPIの証拠か、別の使い捨てGitリポジトリを使い、必要なものだけをそちらへfetchする。
  GitHubでは、取得済みbase・head SHAによるcompareリクエストから`merge_base_commit`を得られる。
  ファイル全体は取得済みhead SHAを`ref`に指定して要求できる。
  応答のrevisionと、比較の起点が記録したbasisと一致することを確認する。
  three-dot API比較は、明示されたrangeのbasisとは別のmerge baseを使う場合がある。
  対応するAPIはpaginationを行い、取得範囲を確認する。
  変更ファイル一覧には上限があり、patchは省略・切詰めされうる([GitHubの比較APIの制限](https://docs.github.com/en/rest/commits/commits#compare-two-commits)を参照)。
  APIの欠落をコードの不在と扱わず、headを固定した後に移動しうる`gh pr diff`を使わない。
  証拠が足りなければ、レビューできない範囲を示す。
  使い捨てリポジトリはalternatesで元のobjectをread-onlyに参照してよいが、取得objectとmetadataへの書込はすべて元のリポジトリの外に置く。

実行検証は任意である。
書込を伴いうるテスト、build、formatter、generatorは、exact Reviewed headから作った別の使い捨てcloneまたはexport済みtreeでのみ実行し、実行前にrevisionを確認する。
現在のworktreeのコピー、descendantの結果、元のGit metadataへ書き込む`git worktree add`は使わない。
生成された変更はそちらで破棄する。
隔離できなければ、Reviewed headに明示的に紐づくCI証拠または静的調査を使い、実行検証の限界を報告する。

## 対話の証拠の選択

ファイル指定を含め、今回のレビュー用に明示された文脈を優先する。
指定された資料を取得できなければ、別の文脈へ黙って置き換えず報告する。
指定がなければ、該当するPRの対話コンテキストコメントと、利用可能な規約上のローカルファイル`.dev/contexts/{sanitized target branch}.md`を調べる。
sanitizeは`/ \ : * ? " < > |`の各文字を`-`に置換する。
non-PR rangeでローカル探索するのは、対象に実際に関連するブランチがある場合だけである。
現在のcheckoutにブランチがあるだけでは使わない。

候補の見出し、PR・repository、Branch、Source commit、更新時点、記載対象を確認して選ぶ。

- 探索で見つけた文脈は、この対象(PRの記録があればそのPRと、ブランチ)を示し、Source commitが解決可能で、Reviewed head自身かその祖先であることを確認する。
  exportのplaceholderである`PR not created at export time`、`PR not checked at export time`、`PR unverified at export time`は、ブランチとsourceの由来が一致すれば受け入れられる。
  後二者はPRの不在を証明しない。
  metadataが不足・不一致なら自動採用の前に確認する。
- Source commitは証拠の時点を示し、Reviewed headと同一である必要はない。
  古い文脈は後の判断を含まない可能性があり、`.dev/contexts/`はcommitされない引継ぎ資料であって、そのrevisionのコードではない。
  利用者が明示的に役割を与えた文脈は、補助資料や事後の証拠としても使える。
  役割と時点を示し、そのheadの実装過程を記録したとは断定しない。
- 複数コメントやローカルファイルの内容は異なりうる。
  由来、対象、時点、内容を比較し、最新コメントや新しいローカル更新時刻だけで正本と決めない。
  ローカル保存だけのexportは、以前共有したコメントを更新しない。
  採用した資料と、重要な陳腐化・矛盾を示す。
  未解決の選択がレビューを実質的に左右する場合だけ利用者へ確認する。

利用できる文脈がなければ、通常は続行し、過去の検討過程は確認できなかったと示す。
利用者がその文脈を前提条件にした場合や、重要な資料の曖昧さを解消できない場合は確認する。
すでに文脈なしでの続行を指示されていれば従う。
欠けた検討過程の補作、文脈の再生成、続行のための共有の要求はしない。

## 主張と変更の調査

PRの説明と関連する議論(レビューコメントとレビュー本文を含む)、または与えられたnon-PR briefを、差分と周辺コードに照らして読む。
発言の帰属を区別する。
別のレビュアーの提案を実装者の主張とせず、与えられたbriefから執筆者や承認を推測しない。
リンクされたADRや履歴は、調べている判断に関係するときに辿る。
すべてのADRを読んだり、過去の選択を一律に再検討したりしない。
リポジトリの文書はReviewed headで読み、別revisionは区別して示す。

変更に関係する判断について、前提がコードで成り立つか、却下案の比較が公平か、失敗した試行の条件が結論を裏づけるか、意図的な非対応が今も妥当かを調べる。
実際の動作、回帰、関係するセキュリティ上の影響は自分でも調査する。
過程のレビューはコード調査の代わりではない。
依頼された変更と影響の証拠に見合う範囲に探索を保つ。

変更が関わる既存コードの規約を確認する。
文書と既存コードが矛盾しても、文書の命令形だけを理由に実装を誤りとしない。
古い案内と、依頼された要件や現行仕様・意図的な制約の根拠を区別する。
適用されるリポジトリ指示に従い、重要な不一致を報告する。
命名・設計への懸念は、実際の変更と起こりうる影響に根拠がある場合に反証も考慮して示す。
長期的な推測やチェック表の採点を必須としない。
説明不足は証拠の欠落であり、コードの欠陥や実装者の理解不足の証明ではない。

## 相談と報告

別Agentは必須ではない。
依頼された場合や、許可されたレビュー範囲で有用な場合は[subagent-consultation](../subagent-consultation/SKILL.md)を使う。
独立レビューには対象資料と操作制約を渡し、自分の仮説と指摘案を渡さない。
実際のhostの会話継承を確認し、利用できればfresh contextを使う。
提案への批評は別の方式であり、その提案を渡す必要がある。
返された候補は自分で検証する。
要求されたレビュー方式や重要な確認範囲を満たせなければ示すが、相談先の不在によって自分の証拠が無効になるとは扱わない。

利用者の作業言語で、通常は会話に報告する。

- 対象、exact Reviewed headとComparison basis、使った文脈の出所と役割を示す。
- 対応可能な指摘を中心に、場所、観測した振る舞いまたは根拠のある矛盾、条件と影響、証拠を示す。
  検証済みの欠陥と、未解決の疑問・証拠不足を区別する。
- 実施した検証と、取得できなかった文脈や実行検証を含む重要な限界を示し、それを踏まえた判断と推奨対応を述べる。
  指摘がなければその旨を述べ、網羅的な正しさを暗示しない。

形式は指摘と依頼に合わせる。
PR概要の再掲、全チェック結果の出力、完了を示すためだけの空欄埋めを行わない。
