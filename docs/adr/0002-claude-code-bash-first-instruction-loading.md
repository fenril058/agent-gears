---
status: accepted
date: 2026-09-07
---

# Claude Code の Bash-first regression は暫定回避として扱い、恒久仕様にしない

agent-gears は、Claude Code の Auto mode が file access を dedicated `Read` / `Edit` / `Write` から Bash(`cat` / `sed` / `grep` / heredoc)へ寄せる挙動と、それによって nested `CLAUDE.md` / path-scoped rules がロードされなくなる問題を、**上流の未修正 bug** として扱う。
根本修正は [anthropics/claude-code#90450](https://github.com/anthropics/claude-code/issues/90450) を source of truth として追跡し、agent-gears 側では instruction loading を再実装しない。

上流が未解決である間だけ、次の2つを暫定回避として置く。

- **local runtime**: Claude Code の settings に `CLAUDE_CODE_THRIFTY_SONIC=0` を置いて Bash-first steering を無効化する案内を README に載せる。
- **repo policy**: `rules/claude.md` に「変更するファイルは一度 dedicated `Read` で開く」という Claude Code 固有の compatibility 規則を置く。

どちらも撤去対象である。
`CLAUDE_CODE_THRIFTY_SONIC` は documented user-facing setting ではなく、上流の実装・実験フラグなので、agent-gears の installation contract をこれに依存させない。
`install.sh` と `nix/hm-module.nix` は `~/.claude/settings.json` を含む user settings を読み書きしない。
配布するのは skill / agent 定義 / rules の symlink だけである。

## なぜ

2026-08-06 の `1e065ff3` は、Claude Code の実測(99 sessions / 5,702 Bash calls / 273 tool errors)から「`Write` / `Edit` の前に `Read` する」という Claude 固有規則を入れた。
2026-08-30 の `cfb64572` は、Auto mode の Bash-first steering と tool 名指定の規則が競合するため、これを「変更前に現在の内容を確認する。手段は問わない」という tool 非依存の不変則に置き換えた(`b17d6ae6` で全ての既存ファイル変更へ拡張)。

この一般化は content freshness については妥当だった。
しかし、後から上流で再現が確認された instruction-loading semantics を保存していなかった。

区別すべき concern は2つある。

```text
A. 変更前に現在のファイル内容を確認する
B. 変更対象 path に適用される nested CLAUDE.md / path-scoped rules を context にロードする
```

A は tool 非依存に表現できる。
B は、現行の Claude Code では dedicated `Read` の経路に結び付いており、Bash の読み取りでは代替できない。
これは 2026-09-08 に Claude Code 2.1.263 で再現確認した(Bash 経由の読み取りでは `InstructionsLoaded` hook が発火せず、nested `CLAUDE.md` も path-scoped rule も効かない。手順と結果は `docs/claude-code-instruction-loading.md`)。
[anthropics/claude-code#92271](https://github.com/anthropics/claude-code/issues/92271) では、`CLAUDE_CODE_THRIFTY_SONIC=0` で steering が消えると nested `CLAUDE.md` / path-scoped rules が再びロードされることが end-to-end で確認されている。
この flag の効果は agent-gears 側では未再現である(steering の掛かる host は観測したが、その host で起動時の env を設定して対比を取る経路がまだ無い)。
バンドルの静的読解では、この env var は steering の experiment gate を上書きする tri-state boolean である。

つまり `cfb64572` の一般化は、上流 regression の影響を agent-gears の policy 側にも取り込んでいた。
「手段は問わない」は、A を守りながら B を落とす読み取りを許容する。

一方、agent-gears が B を自力で満たすことはできない。
Bash の file access に nested memory / rules のロードを追加できるのは Claude Code 本体だけである。
残るのは「上流を追跡しつつ、その間の実効性を確保し、直ったら確実に外す」という運用だけになる。

## Considered options

- **何もせず上流の修正を待つ。**
  nested `CLAUDE.md` と path-scoped `.claude/rules/*.md` が適用されないまま作業が進むリスクが残る。
- **全ての file read を恒久的に `Read` へ固定する。**
  B は満たすが、concrete な tool 名を agent 非依存の恒久不変則に昇格させることになる。
  上流が修正されても規則が残り、他の host にも無意味な制約が波及する。
- **agent-gears 側で instruction loading 相当を再実装する(Bash command の解析、hook による強制など)。**
  上流の internal 挙動を API contract として扱うことになり、保守が恒常的に発生する。
- **上流を source of truth として追跡し、撤去条件付きの host 固有 compatibility 規則と local workaround だけを置く。**

四つ目を採用した。

## Consequences

`rules/claude.md` は、A(content freshness、tool 非依存)と B(instruction loading、host 固有・暫定)を別の節として持つ。
B の節は上流 issue の URL と暫定であることを明記し、読み取り全般を `Read` に固定しないことも書く。
`cfb64572` で削除した「複数ファイルの中身を読むときは `Read` を並列に呼ぶ」は復元しない。
これは correctness ではなく tool routing / performance の policy であり、B が求めるものではない。

README には `CLAUDE_CODE_THRIFTY_SONIC=0` を temporary workaround として載せる。
undocumented な上流の実装詳細であること、撤去対象であること、agent-gears が user settings を自動変更しないことを併記する。

この時点の agent-gears には `Read` / `Edit` / `Write` matcher を使う Claude Code hooks が無い。
配布物は skill / agent 定義 / rules だけで、hooks 定義を持たない。
よって「Bash-first steering が hook を silent に迂回する」影響は現状受けない。
将来 hook を追加する場合は、Bash 経路で迂回されないかをこの ADR の前提として確認する。
この Issue の範囲では、汎用の shell parsing や Bash hook enforcement framework は導入しない。

確認手順は `docs/claude-code-instruction-loading.md` に置く。
確認する invariant は tool identity ではなく「変更対象 path に適用される指示が実際に有効になること」で、将来 Anthropic が `Read` 以外の access method にも instruction loading を広げた場合もそのまま通る。

撤去は次を満たしたときに行う。

1. 上流 report に対応する fix または同等の変更がリリースされている。
2. 対象の Claude Code version で `docs/claude-code-instruction-loading.md` の手順を実行する。
3. `CLAUDE_CODE_THRIFTY_SONIC` 未設定でも nested `CLAUDE.md` / path-scoped rules が期待どおり有効になる。
4. その時点で dedicated tool matcher hooks を持っているなら、それらにも回帰が無い。

issue の close や release note だけを根拠に撤去しない。
実際の version で再現確認を行う。

確認できたら、README の workaround 案内と `rules/claude.md` の B の節を削除し、`rules/claude.md` は A の不変則だけに戻す。
この ADR は書き換えず、撤去を決めた ADR を追加して supersede する。
確認手順自体は、将来の harness regression 検出に有用なら残してよい。
