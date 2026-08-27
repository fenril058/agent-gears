このリポジトリの編集で間違えやすい点(更新の追従漏れ):

- `SKILL.md`(英語=正本)を直したら `SKILL-ja.md` も手動で追従。
  例外: `writing` の `japanese-tech-writing` / `argument-gap-edit` は日本語 `SKILL.md` が正本／`TEMPLATE.md` は日本語のまま。
  各 `SKILL.md` は agentskills.io 仕様に準拠(公式 `skills-ref` で検証)。
  CI の `scripts/check-skill-spec.sh`(flake の `packages.skills-ref` を使う)が検証する。
  skills-ref は Claude 拡張フィールド(argument-hint 等)を一律エラーにするが、スクリプト側で
  既知の Claude 拡張(`CLAUDE_EXT`)のみの Unexpected fields エラーは合格に読み替える。
  未知フィールドや name/description 違反は失格。Claude 拡張フィールドを増やしたら CLAUDE_EXT も追従。
  skills-ref 本体の nix 定義は `nix/skills-ref.nix`(由来: yasunori0418/skills, MIT)。
- 配布は `install.sh`(命令的)と `nix/hm-module.nix`(宣言的)の2系統。
  両者は skill/agent をディレクトリ構成から自動列挙するので名前の追従は要らない。
  配布先(`~/.claude` 等)やレイアウト規約を変えたら両方直す。
  配布先集合の一致は CI の `scripts/check-distribution.sh` が検証する。
- plugin の `name`/`version`/`keywords` は `marketplace.json` と各 `plugin.json` に重複。
  一致は CI の `scripts/check-plugin-meta.sh` が検証する。
  `description` は粒度が違う(marketplace=詳細／plugin.json=短縮)ので手動。
  `marketplace.json` の `source` は `"./plugins/<name>"` 形式で書く。
  Claude Code は `"./"` 始まりの相対パスしか受け付けず、`"<name>"` だと一覧表示は通るのに
  `plugin install` が `source: Invalid input` で落ちる。
  `metadata.pluginRoot` は schema にはあるが解決時に使われないので当てにしない。
- 常時ルールは `rules/always-on.md` に不変則だけ。手順は skill 側へ。
- skill の eval corpus は `plugins/<plugin>/skills/<skill>/evals/cases.json`。
  形式定義は `plugins/agent-instructions/skills/empirical-prompt-tuning/EVAL-CORPUS.md` ただ1つ。
  CI の `scripts/check-evals.sh` が schema・`[critical]` の存在・結果ファイルの
  success/accuracy の検算まで見る(未知フィールドは失格)。
  結果ファイルを検証するときは参照先 corpus も検証する。`[critical]` ゼロの corpus を
  指すと success の判定が空虚に真になるので、この経路を塞いだままにする。
  case id と requirement id は既存の結果から参照されるのでリネームしない。text だけ直す。
  **実行プロンプトに requirements を入れない。** baseline(skill なし)に checklist を
  見せると、それをそのまま実装できてしまい uplift がゼロに潰れる。採点は
  `eval-render.sh --part judgment` で別 evaluator が行う。
  host/model をまたいだ総合スコアのフィールドを足さない。比較単位は
  `(case, host, model, candidate)` で、平均すると model 固有の regression が消える。
  run の突き合わせは `eval-compare.sh`。主出力は accuracy の差ではなく
  **requirement 単位の差分行列**で、accuracy を先に見せると「非 critical が1件動いただけ」を
  「候補の方が良い」と読み違える(実測で踏んだ)。比較の前提は機械的に拒否する。
  テストは同じディレクトリの `eval-compare.test.sh`(CI の consistency job)。
  case 集合の一致は run どうしの相対比較で、corpus の網羅性は強制しない。
  1 case だけの run が corpus 全体の run を名乗れないよう、網羅数と未実行 case 名を出す。
  candidate identity は `(kind, revision)`(label は identity ではない)。相異は等値関係では
  ないので全ペアで見る —— 先頭を錨にすると `A, B, B` を見逃す。
  trial をまたいだ計算をしない。`tool_uses` の集計は `(arm, trial)` ごと、
  「全 arm 同一」の判定と表示キーは `(case, trial, requirement)` ごと。
  `unevaluated` の集合が run 間で違えば比較を拒否する。`unevaluated -> pass` は
  候補の改善ではなく証拠の有無で、accuracy の分母も片方だけ変わる。
  `tool_uses` が case 単位で部分欠損したら位置を `-` で残し、min/max/range は出さない
  (部分観測から skew を読ませない)。
  `unevaluated` は第四の verdict ではないので「全 arm 同一」の節に混ぜず、別節に出す。
  surface/semantic の突き合わせでも数えない(semantic の判定が無いので一致も不一致も無い)。
  run ファイル・corpus 由来の自由文字列は表示境界でエスケープする。本文だけでなく
  比較拒否の診断行も対象(診断は1件1行が前提で、行頭に印を付けて出すため)。
  `check-evals.sh` は非空しか見ないので、`label` の改行で偽の測定行を、`host.id` の
  改行で偽の診断行を出せる(どちらも実測で踏んだ)。
  `host.version` は比較条件ではないが、arm ごとに違えば先頭 run のものを共通表示しない。
  arm の隔離は runner の責任で、host の skill 無効化だけでは足りない
  (無効化してもファイルは `~/.claude/skills/` に残り読める)。不変条件は
  EVAL-CORPUS.md「Runner isolation contract」。skill が別 skill に委譲する場合、
  その依存は corpus でも candidate でもなく runner environment の性質として扱い、
  baseline を含む全 arm へ等しく与える(schema には足さない)。
  `host.model` は必須。取得できない host では `"unknown"` と明記し、その run は比較に使わない。
  LLM を呼ぶ評価自体は CI に入れない。
- repo-local 指示の正本はこの `AGENTS.md`。`CLAUDE.md` は `@AGENTS.md` で取り込むだけ、
  `.github/copilot-instructions.md` はこれへの symlink。全エージェント共通の内容はここに書く。
  `CLAUDE.md` に書いてよいのは Claude Code 固有の指示だけ(Codex は読まない)。
- 外部由来の skill は取り込んで改変する(上流を取り直す運用はしない)。
  由来の宣言元は `PROVENANCE.json` ただ1つ。新たに取り込んだらここに追記する。
  `LICENSE` / `NOTICE` を消さない。plugin 単位の `LICENSE`(shokai/agent-skills)は
  複数 plugin に分散するので、skill を動かしたら移動先への複製と移動元の残骸に注意。
  宣言と実ファイルの一致は CI の `scripts/check-licenses.sh` が検証する。

手順は README:「構成」「常時ルール vs skill」「SKILL.md の言語」「skill の eval corpus」「配布方法」「新しい skill を足すとき」。

shellcheck:

- CI の shellcheck は ubuntu 同梱版、ローカルの `nix shell nixpkgs#shellcheck` は別バージョン。
  info レベルの指摘(SC2015 等)が食い違い、ローカルで通っても CI で落ちることがある。
  `A && B || C` のような曖昧な構文を避けて書けば、どちらでも通る。

コード整形(treefmt):

- フォーマッタの唯一の定義は `treefmt.nix`。`nix fmt` で一括整形、`nix flake check` の
  `checks.formatting` が未整形を落とす(CI の `nix` job が実行)。対象は `.nix`(nixpkgs-fmt)/
  `.go`(gofmt)/ `.sh`(shfmt)。shell のインデントは `.editorconfig`(space/2)に従う。
  `switch_case_indent` は treefmt 経由で効かず直接 shfmt と食い違うので `.editorconfig` に書かない。
  Markdown は「一文一行」規約と衝突するため対象外(手動整形)。
  対象言語を増やすときは `treefmt.nix` に programs を足す。

nix の落とし穴:

- 補助スクリプトや `nix eval` で `<nixpkgs>` / NIX_PATH に依存しない。
  `<nixpkgs>` の解決は各自の nix.conf(`nix-path` / `extra-nix-path`)頼みで、CI の最小 nix には無く落ちる。
  nixpkgs は flake から引く(例: `builtins.getFlake` の `inputs.nixpkgs`)。
