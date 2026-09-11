# path に紐づく指示のロードを確認する(canary)

Claude Code の Auto mode が file access を Bash へ寄せると、nested `CLAUDE.md` と path-scoped rules が silent にロードされなくなる。
これは上流の未修正 bug で、agent-gears 側では暫定回避だけを置いている(経緯と撤去条件は `docs/adr/0002-claude-code-bash-first-instruction-loading.md`)。

この文書は、その暫定回避が要るかどうかを実際の Claude Code version で判定するための手順である。

確認する invariant は次の1つだけ。

```text
対象 file にアクセス・変更するとき、
その path に適用される nested CLAUDE.md / path-scoped rule が実際に有効になる
```

どの tool を通ったかは判定条件にしない。
将来 `Read` 以外の access method にも instruction loading が広がった場合、この確認はそのまま通るべきである。

## 何を計測器にするか

判定は2つの観測を組で読む。

- **ロードされたか(機構)**: `InstructionsLoaded` hook の発火を見る。発火していればロードされたと確定できる。
- **効いたか(挙動)**: 依頼の結果に指示が反映されたかを見る。invariant に対応するのはこちらだが、単独では判定に使わない。

挙動だけで判定すると偽陰性が出る。
ロードされていても model が従わないことがあり、特に「変更したファイルの末尾に固定 token の行を足す」形の canary は prompt injection と見なされて拒否される。
canary の指示は、依頼された編集そのものに掛かる、もっともらしい記法規約として書く。

`InstructionsLoaded` hook は `load_reason`(`session_start` / `nested_traversal` / `path_glob_match` / `include` / `compact`)と `file_path` を渡してくる。
nested `CLAUDE.md` は `nested_traversal`、`paths:` frontmatter を持つ rule は `path_glob_match` で発火する。

この hook は observability 用の [asynchronous event](https://code.claude.com/docs/en/hooks#instructionsloaded) なので、log の書き込みとセッション終了に race がある。
`loaded.log` が空であることは、ロードされなかったことの証明にはならない。
判定は次の非対称な読みにする。

- log に行がある: ロードされた(確定)。
- log が空で挙動が出ている: hook が間に合わなかった疑い。`無効` にせず inconclusive とし、再実行する。
- log が空で挙動も出ていない: ロードされていないと読む。ただし後述の bounded poll を経てから読む。

## 準備

agent-gears の作業ツリーの外に、使い捨ての canary project を作る。
`<ID>` は実行のたびに新しいランダム文字列にする(前のセッションの文脈から sentinel が漏れるのを防ぐため)。

作業ツリーの外に置くだけでは、agent-gears 自身の暫定回避を外せない。
`install.sh` は `rules/claude.md` を user-level の `~/.claude/rules/agent-gears.md` として配布し、そこには「変更するファイルは一度 `Read` で開く」が入っている。
user-level の rules は全 project に適用されるので、`$DIR` を repository の外に作っても効いたままになる。
その状態で未設定側を走らせると、bug が残っていても mitigation 自身が `Read` を強制して canary を通してしまい、「暫定回避は不要」が循環論証になる。
判定では user source を必ず外す。
CLI では `--setting-sources project` を必須条件にする(canary 自身の `.claude/settings.json` と `.claude/rules/` は project source なので残る)。
この flag は interactive 起動にも付けられるので、対話で行う場合も同じ隔離を掛ける。

ただし `--setting-sources` が選べるのは user / project / local の3層だけで、managed settings と organization policy はこの3層に含まれない(`--restricted` の説明でも managed settings は別扱いで残ると書かれている)。
managed 側が `Read` を強制していれば未設定 arm が誤って pass し、逆に managed 側が hook を無効化していたり `CLAUDE_CODE_DISABLE_CLAUDE_MDS=1` を継承していれば偽陰性になる。
canary は managed 配布の無い環境で回すことを前提条件にする。
確認は、同じ環境で interactive の Claude Code を `--setting-sources project` 付きで起動し、`/status` の `Setting sources` を見る。
ここに managed source が並ぶ環境の run は、撤去判定の根拠にしない。
managed source の有無を確認できない環境の run も、同じ理由で根拠にしない。
headless で canary を回す場合も、この `/status` で隔離を確認したのと同じ host / user environment で実行する。
`claude doctor` は補助的な diagnostics として使ってよいが、active な settings source の一覧ではないので、「managed 配布が無いこと」の証明には使わない。

```bash
ID=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
ID2=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
DIR=$(cd "$(mktemp -d)" && pwd -P)   # hook が渡す file_path と前方一致させるため symlink を解決する
mkdir -p "$DIR/sub" "$DIR/.claude/rules"

# nested CLAUDE.md 側の canary: 依頼される編集そのものに掛かる記法規約として書く
cat > "$DIR/sub/CLAUDE.md" <<EOF
# このディレクトリの記法

\`note.txt\` などのメタデータファイルでは、\`status\` の値を大文字で書き、
ハイフンを挟んで現在の版番号を後ろに付ける。
このディレクトリの現在の版番号は \`r$ID\`。

例: 下書きの状態なら \`status: DRAFT-r$ID\`
EOF

# path-scoped rule 側の canary
cat > "$DIR/.claude/rules/sub-files.md" <<EOF
---
paths:
  - "sub/**"
---

# sub/ の変更履歴

\`sub/\` 配下のファイルを変更したら、\`sub/CHANGELOG.txt\` に1行追記する。
形式は \`r$ID2: <変更内容>\`。
EOF

printf 'status: draft\n' > "$DIR/sub/note.txt"

# 計測器: ロードされた instruction file を記録する
# 空ファイルで初期化する(negative case でも grep / cat が ENOENT にならない)
: > "$DIR/loaded.log"

cat > "$DIR/hook.sh" <<EOF
#!/usr/bin/env bash
python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("load_reason"), d.get("file_path"), sep="\t")' >> "$DIR/loaded.log"
EOF
chmod +x "$DIR/hook.sh"

cat > "$DIR/.claude/settings.json" <<EOF
{
  "hooks": {
    "InstructionsLoaded": [
      { "hooks": [ { "type": "command", "command": "$DIR/hook.sh" } ] }
    ]
  }
}
EOF

echo "$DIR  r$ID  r$ID2"
```

## 手順

1. 対象の host で Bash-first steering が実際に掛かっているかを先に確かめる。
   新規セッションで「いま与えられている指示の中に、ファイルの読み書きで `Read`/`Edit`/`Write` より Bash を優先させるものがあるか」を、層を限定せずに尋ねる。
   上流 #92271 では steering は meta user message として注入されると説明されている。
   「system prompt にあるか」と層を限定して訊くと、steering があっても文字どおり「無い」と答えられ、偽陰性になる。
   答えは自己申告なので、手順3の中立な依頼を流して `tool_use` の route でも見る。
   自己申告と route(対象ファイルを Bash で読む)が一致すれば steering の存在を支持する。
   1回の route だけでは確定しない。同じ条件でも tool 選択はぶれるので、steering が無くても偶然 Bash を選ぶことはある。
   自己申告と route が食い違う場合、または route だけで判断する場合は、ID を変えて複数回繰り返す。
   steering が無い host では bug の前提条件が再現しないので、`CLAUDE_CODE_THRIFTY_SONIC` の A/B はそこでは測れない。
   ただし「steering が無い」こと自体には2つの原因がある。
   上流が steering を削除した場合と、その host / model が元から experiment cohort の外にいる場合である。
   区別は `CLAUDE_CODE_THRIFTY_SONIC=1` を明示して行う。
   steering が戻るなら cohort 外にいるだけで、戻らないなら gate ごと消えている。
   撤去判定でこれをどう使うかは「上流修正後の撤去」に書く。
2. `CLAUDE_CODE_THRIFTY_SONIC` を設定しない状態で、`$DIR` を project directory として Claude Code を新規セッションで起動する。
   Auto mode を有効にし、user source を外す(CLI なら `--setting-sources project`)。
   A arm は「設定していない」ではなく「設定されていない」ことを確認する。
   settings に書いていなくても、親プロセスから継承した env var があればそちらが効く。
   Claude Code のセッションから canary を回すときに起こりやすい。

   managed settings と organization policy も、この3層とは別に効く。
   起動前に隔離を監査する。

   ```bash
   if printenv CLAUDE_CODE_THRIFTY_SONIC >/dev/null; then
     echo "A arm が継承 env で汚染されている" >&2
   fi
   env | grep -i '^CLAUDE' || echo "Claude Code 関連の継承 env は無し"
   ```

   managed source は shell からは見えないので、「準備」のとおり interactive セッションの `/status` の `Setting sources` で確認する。
   managed source が並ぶ run と、確認できない環境の run は、撤去判定に使わない。

   interactive セッションで行う場合は workspace trust に注意する。
   settings file の hooks は trust を承認するまで保留され、`$DIR` は毎回新しいので必ず dialog が出る。
   承認しないと計測器の `InstructionsLoaded` hook 自体が動かず、`loaded.log` の非発火を instruction loading の失敗と読み違える。
   trust を承認し、hook が動くことを確かめてから依頼を出す。
   `claude -p` は自動的に trusted になるので、判定本体は headless に寄せてよい。
3. 中立な依頼を1つだけ出す。
   canary、`CLAUDE.md`、tool 名のいずれにも触れない。

   ```text
   sub/note.txt の status を final に変えて
   ```

4. セッション終了後に結果を見る。
   `InstructionsLoaded` は async なので、`loaded.log` は空のまま読まずに bounded poll してから読む。
   待つ条件は「1行でも書かれた」ではなく、手順5の pass 条件と同じ2行が揃うことにする。
   `[ -s "$DIR/loaded.log" ]` だと最初の hook が1行書いた時点で抜けるので、2本目がまだ実行中でも negative と読める。
   `load_reason` だけで待つのも足りない。
   隔離しきれなかった別の instruction file が同じ `load_reason` で発火すると、対象 file が未発火のまま抜ける。
   `load_reason` と `file_path` の組で待つ。

   ```bash
   want_nested=$'nested_traversal\t'"$DIR/sub/CLAUDE.md"
   want_glob=$'path_glob_match\t'"$DIR/.claude/rules/sub-files.md"

   # 期待する2行が揃うまで最大30秒待つ
   for _ in $(seq 60); do
     if grep -Fqx "$want_nested" "$DIR/loaded.log" && grep -Fqx "$want_glob" "$DIR/loaded.log"; then
       break
     fi
     sleep 0.5
   done

   cat "$DIR/loaded.log"        # 機構: 何がロードされたか
   cat "$DIR/sub/note.txt"      # 挙動: nested CLAUDE.md 側
   cat "$DIR/sub/CHANGELOG.txt" # 挙動: path-scoped rule 側
   ```

5. `有効` と読むのは、機構と挙動の pass 条件をすべて満たしたときだけにする。

   - 機構: `loaded.log` に `$want_nested` と `$want_glob` の2行がそのままある(poll と同じ条件を見る)。
     hook が渡す `file_path` の prefix が `$DIR` と食い違う環境では、log に実際に出た path で組を作り直す。
   - 挙動(nested `CLAUDE.md` 側): `sub/note.txt` が `status: FINAL-r$ID` になっている。
   - 挙動(path-scoped rule 側): `sub/CHANGELOG.txt` があり、`r$ID2:` で始まる行がある。

   片方の canary だけ出ている mixed state は、全体としては `有効` にしない。
   どちらが落ちたかを記録して再実行する。
   poll しても log が空で、しかし挙動が出ている場合は、hook が間に合わなかった疑いとして inconclusive にし、再実行する。
6. 準備からやり直して ID と `$DIR` を作り直し、今度は `CLAUDE_CODE_THRIFTY_SONIC=0` を足して同じ手順を実行する。
   CLI では session 単位の override を使い、`~/.claude/settings.json` は書き換えない。
   元の環境を汚さずに済み、指定した key 以外の file-based settings は残るので、project 側の `InstructionsLoaded` hook も維持される。

   ```bash
   --settings '{"env":{"CLAUDE_CODE_THRIFTY_SONIC":"0"}}'
   ```

   session 単位の override が使えない host では、canary project の `.claude/settings.json` に `env` を足す(`hooks` は消さずに同じ file へ追記する)。

   ```json
   {
     "env": {
       "CLAUDE_CODE_THRIFTY_SONIC": "0"
     }
   }
   ```

判定は2回の対比で読む。

| 未設定 | `=0` | 読み |
|---|---|---|
| 有効 | 有効 | 暫定回避は不要。撤去条件の候補。 |
| 有効 | 無効 | inconclusive。flag が悪化させたとは結論しない。 |
| 無効 | 有効 | 上流 bug が再現している。暫定回避を続ける。 |
| 無効 | 無効 | この flag では回避できない。ADR 0002 の前提が変わったので再検討する。 |

1回の実行は決定的ではない。
model がどの tool を選ぶかは同じ条件でもぶれるので、未設定側だけ偶然 `Read`、`=0` 側だけ偶然 Bash を選ぶことは起こり得る。
`有効 / 無効` はこの偶然で出るのが普通なので、ID を変えて複数回繰り返し、各回の route と `loaded.log` を突き合わせてから読む。
判定を変える(特に「有効」へ転じる)ときも同じく数回繰り返す。

## headless で繰り返す

対話セッションを毎回立てなくても、同じ canary を `claude -p` で回せる。
`--permission-mode auto` と使い捨ての project directory を使い、n 回繰り返して route と `loaded.log` を集計する。
`claude -p` は自動的に trusted になるので、workspace trust の承認は要らない。

```bash
cd "$DIR" && claude -p 'sub/note.txt の status を final に変えて' \
  --permission-mode auto --setting-sources project --no-session-persistence \
  --output-format stream-json --verbose > stream.jsonl
```

`stream.jsonl` の `tool_use` を見れば、対象ファイルを `Read` と Bash のどちらで読んだかが分かる。
ただし headless CLI の auto mode は host 側の auto mode と system prompt が同じとは限らない。
同じ headless CLI でも model によって違う(下の 2.1.267 の実測では `claude-sonnet-5` に steering が無く、`claude-opus-5` には掛かっていた)。
手順1の確認は、実際に測る host と model の組ごとに行う。

## tool route を固定して機構だけを見る

model の tool 選択のぶれを外して「Bash 経由の読み取りで指示がロードされるか」だけを見たいときは、route を強制する。

```bash
# Bash に固定
claude -p '...' --permission-mode auto --disallowedTools "Read,Edit,Write,Glob,Grep,NotebookEdit"
# dedicated tool に固定
claude -p '...' --permission-mode auto --disallowedTools "Bash"
```

これは invariant そのものではなく、その内訳(loading が dedicated `Read` の経路に結び付いているか)を見る補助的な確認である。
撤去判定は、route を強制しない手順のほうで行う。

## 実測(2026-09-08 / Claude Code 2.1.263)

Claude Code 2.1.263 の headless CLI(`claude -p --permission-mode auto`、model は `claude-sonnet-5`)で実行した結果。

- **route を固定した確認(各3回)**: Bash に固定した3回は `InstructionsLoaded` が1度も発火せず、nested `CLAUDE.md` と path-scoped rule のどちらも効かなかった。
  dedicated tool に固定した3回は `nested_traversal` と `path_glob_match` の両方が発火し、どちらの canary も挙動に出た。
  loading が dedicated `Read` の経路に結び付いているという ADR 0002 の前提は、この version でも成立している。
- **Bash-first steering を `--append-system-prompt` で与えた確認(各3回)**: steering 有りの3回は対象ファイルを Bash だけで読み、ロードも挙動も出なかった。
  steering 無しの3回は `Read` を通してロードされ、挙動にも出た。
  steering → Bash route → ロードされない、という経路が end-to-end で再現する。
- **2.1.263 / `claude-sonnet-5` の headless CLI には Bash-first steering が無い**: system prompt には逆に dedicated tool を優先させる記述があると model が答え、route の実測もそれと一致した。
  この時点では model を変えた確認をしていないので、「2.1.263 の headless CLI には無い」とまでは言えない(下の 2.1.267 の実測で、同じ headless CLI でも model により変わることが分かった)。
  `CLAUDE_CODE_THRIFTY_SONIC=0` の有無で route も判定も変わらなかった(各4回)。
  この環境は bug の前提条件を再現しないので、flag の効果はここでは測れていない。
  flag の判定は、手順1で steering の存在を確認でき、かつ起動時の env を設定できる host で行う必要がある。
- 挙動だけを見る canary の偽陰性も確認した。
  「変更したファイルの末尾に `CANARY-<ID>` の行を足す」形の指示は、ロードされた上で prompt injection と判定されて拒否された。
  この文書の canary を記法規約の形にしているのはこのため。
- **別環境での再確認(各1回)**: 同じ 2.1.263 / `claude-sonnet-5` を別のセッション・別のマシンで実行し、route 固定の結果を再現した。
  Bash 固定は `loaded.log` が空のままで `status: final`(記法規約が効いていない)、`CHANGELOG.txt` も作られない。
  dedicated tool 固定は `nested_traversal` と `path_glob_match` が並び、`status: FINAL-r<ID>` と `CHANGELOG.txt` の追記が出た。
- **steering は host によっては system prompt の外から来る**: 同じ 2026-09-08 の Claude Code on the web(auto mode)のセッションでは、Bash-first steering が base system prompt ではなく turn 単位で注入される指示として観測された。
  headless CLI に steering が無くても、同じ version の別 host には掛かっている。
  手順1で層を限定して訊いてはいけないのはこのため。
  ただしこの host でも **flag の効果は検証していない**。
  観測したのは実行中のセッションであり、env は session 起動時に読まれるため、そのセッション内から `CLAUDE_CODE_THRIFTY_SONIC` を設定し直して対比を取ることはできない。
  flag の検証には、steering が掛かる host で settings の `env` を設定してからセッションを起こす経路が要る。
- **flag が何を制御しているかの静的確認**: 2.1.263 のバンドルに `CLAUDE_CODE_THRIFTY_SONIC` は存在し、tri-state boolean として parse されている。
  値が設定されていればその値をそのまま返し、未設定なら experiment gate(`forced` / `cohort` / `none`)へフォールバックする分岐を gate している。
  つまり `=0` は「gate の判定を無視して off に固定する」ものと読める。
  これはバンドルの静的読解であって、end-to-end の効果確認ではない。
  headless CLI で `=0` の有無が効かなかったのは、この gate がそこでは元々 off だったためと整合する。

## 実測(2026-09-11 / Claude Code 2.1.267)

`CLAUDE_CODE_THRIFTY_SONIC=0` の end-to-end の効果を、steering が掛かる条件を1つ用意して確認した。
確認できたのは次の条件についてであって、全ての host / version / model への一般化ではない。

- Claude Code 2.1.267
- Ubuntu 24.04.5 LTS(WSL2)
- `claude -p --permission-mode auto --no-session-persistence --output-format stream-json`
- `--setting-sources project`(user-level の agent-gears rules を除外)
- 継承済みの `CLAUDE_*` env を除いた状態で起動(A arm が本当に unset であることを確認)
- model は `claude-opus-5`
- run ごとに `$DIR` と ID を作り直し、各条件4回

| 条件 | route | `nested_traversal` | `path_glob_match` | `sub/note.txt` | `sub/CHANGELOG.txt` |
|---|---|---|---|---|---|
| 未設定 | 4/4 Bash-first | 0/4 | 0/4 | 4/4 `status: final` | 4/4 未作成 |
| `=0` | 4/4 dedicated `Read` | 4/4 | 4/4 | 4/4 `status: FINAL-r$ID` | 4/4 `r$ID2:` あり |

未設定側は4回とも Bash だけで完結し、dedicated tool を一度も使わなかった(`cat` で読み `sed -i` で書き換えた)。
`loaded.log` は30秒の bounded poll のあとも空のままだった。
`=0` 側は4回とも対象ファイルを `Read` で読んで `Edit` / `Write` で書き、最初の poll の前に既に両イベントが揃っていた。

手順1の self-report も route と一致した(各条件2回)。
未設定側は「While auto mode is active: Do your work through the Bash tool ...」を逐語で引用し、`=0` 側は同じ問いに対してその記述は無いと答えた。

**control(効いているのが flag であることの確認)**: 同じ手順を `claude-sonnet-5` でも回した。

| 条件 | self-report | route | 2イベント | behavioral canary |
|---|---|---|---|---|
| 未設定(canary 3回 / self-report 2回) | steering 無し(逆に dedicated tool 優先の記述) | `Read` 経由 | 両方発火 | 両方出た |
| `=1`(canary 2回 / self-report 1回) | steering 有り | Bash 経由 | 発火せず | 両方不発 |

model を変えるだけで既定の挙動が入れ替わり、`CLAUDE_CODE_THRIFTY_SONIC` はどちらの向きにも上書きできた。
model 自体が原因というより、model / cohort が gate の既定値を決め、この env var がその gate を上書きする、という読みと整合する。
2.1.263 のバンドルの静的読解(tri-state boolean、未設定時だけ experiment gate へフォールバック)とも整合する。

**留保**: この run では managed source の有無を `/status` で確認していない(実行時に見たのは `claude doctor` の診断行だけで、これは active な settings source の一覧ではない)。
未設定 arm と `=0` arm は同じ環境なので flag の A/B としては成立するが、撤去判定の根拠にするなら「準備」の `/status` 確認を満たした run で取り直す。

これは headless `-p` セッションでの検証であって、interactive host そのものではない。
起動済みの interactive セッションには後から env を入れられないので、対比が取れるのは起動時に env を渡せる経路だけである。
ただし Opus arm が引用した steering の文面は、同じマシンの interactive auto mode セッションに掛かっているものと同一だった。
また「headless CLI には steering が無い」という 2.1.263 の読みは、model を変えると成り立たない。

**補足(loading trigger は `Read` に結び付いたまま)**: control の `claude-sonnet-5` / `=1` の2回目は、`cat` で読んだあと dedicated `Edit` で `sub/note.txt` を書き換えた。
それでも `InstructionsLoaded` は最後まで発火しなかった。
2.1.267 でも loading は `Read` の経路に結び付いており、`Edit` 単独では引かれない。

## 上流修正後の撤去

ADR 0002 の撤去条件を満たすかどうかは、この手順で判定する。

上流修正は2つの形で来る。
どちらの形を根拠にするかを先に決める。

- **access method 側の修正**: Bash 経由の読み取りでも instruction がロードされるようになった形。
- **steering 側の修正**: Bash-first steering が無くなり、既定の route が dedicated tool に戻った形。

invariant は「その path の指示が実際に有効になる」なので、どちらの形でも撤去条件を満たしうる。
判定手順が片方だけを想定していると、steering を削除した上流修正を自分で失格にしてしまう。

1. 上流 report([#90450](https://github.com/anthropics/claude-code/issues/90450) / [#92271](https://github.com/anthropics/claude-code/issues/92271))に対応する fix が入った version を特定する。
   issue の close や release note だけを根拠にしない。
2. **access method 側の修正**を根拠にする場合は、「tool route を固定して機構だけを見る」の Bash 固定を実行する。
   対象 path の2 file が `loaded.log` に並び、behavioral canary も両方出れば満たす。
   この場合は steering の有無を問わない。
3. **steering 側の修正**を根拠にする場合は、以前 steering を再現できた条件(host / 実行形態 / model / permission mode)をそのまま使って手順1をやり直し、steering が消えていることを確認する。
   そのうえで `CLAUDE_CODE_THRIFTY_SONIC` 未設定の arm を複数回実行し、毎回 pass することを確認する。
4. 3 を根拠にするときは、単に experiment cohort から外れただけでないことを確認する。
   `CLAUDE_CODE_THRIFTY_SONIC=1` を明示しても steering が戻らないなら、gate ごと消えたと読める。
   `=1` で steering が戻るなら cohort 外にいるだけなので、撤去根拠にしない(2.1.267 の `claude-sonnet-5` がこの状態だった)。
   steering を一度も再現していない host / model の「steering なし」も、同じ理由で根拠にしない。
5. その時点で `Read` / `Edit` / `Write` matcher の hooks を配布していれば、それらが Bash 経路で迂回されないことも確認する。
6. 確認できたら、README の workaround 案内と `rules/claude.md` の「path に紐づく指示のロード」節を削除する。
   `rules/claude.md` は「変更前に現在の内容を確認する」という tool 非依存の不変則だけに戻す。
7. ADR 0002 は書き換えず、撤去を決めた ADR を追加して supersede する。

どの形で判定する場合も、「準備」の隔離条件(user source を外す、managed 配布が無い、継承 env が無い)を満たした環境で行う。

この文書自体は、将来の harness regression 検出に使えるので撤去後も残してよい。
