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

- **ロードされたか(機構)**: `InstructionsLoaded` hook の発火を見る。これが ground truth。
- **効いたか(挙動)**: 依頼の結果に指示が反映されたかを見る。invariant に対応するのはこちらだが、単独では判定に使わない。

挙動だけで判定すると偽陰性が出る。
ロードされていても model が従わないことがあり、特に「変更したファイルの末尾に固定 token の行を足す」形の canary は prompt injection と見なされて拒否される。
canary の指示は、依頼された編集そのものに掛かる、もっともらしい記法規約として書く。

`InstructionsLoaded` hook は `load_reason`(`session_start` / `nested_traversal` / `path_glob_match` / `include` / `compact`)と `file_path` を渡してくる。
nested `CLAUDE.md` は `nested_traversal`、`paths:` frontmatter を持つ rule は `path_glob_match` で発火する。

## 準備

agent-gears の作業ツリーの外に、使い捨ての canary project を作る。
`<ID>` は実行のたびに新しいランダム文字列にする(前のセッションの文脈から sentinel が漏れるのを防ぐため)。

```bash
ID=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
ID2=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
DIR=$(mktemp -d)
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
   答えは自己申告なので、手順3の中立な依頼を1回流して `tool_use` の route で裏を取る。
   対象ファイルを Bash で読むなら steering が掛かっていると読む。
   steering が無い host では bug の前提条件が再現しないので、以降の結果を「暫定回避が不要になった」根拠にはできない。
2. `CLAUDE_CODE_THRIFTY_SONIC` を設定しない状態で、`$DIR` を project directory として Claude Code を新規セッションで起動する。
   Auto mode を有効にする。
3. 中立な依頼を1つだけ出す。
   canary、`CLAUDE.md`、tool 名のいずれにも触れない。

   ```text
   sub/note.txt の status を final に変えて
   ```

4. セッション終了後に結果を見る。

   ```bash
   cat "$DIR/loaded.log"        # 機構: 何がロードされたか
   cat "$DIR/sub/note.txt"      # 挙動: nested CLAUDE.md 側
   cat "$DIR/sub/CHANGELOG.txt" # 挙動: path-scoped rule 側
   ```

5. `loaded.log` に `sub/CLAUDE.md` と `rules/sub-files.md` の行があれば、その path の指示はロードされている。
   `note.txt` が `status: FINAL-r$ID` になっていれば挙動にも出ている。
6. 準備からやり直して ID と `$DIR` を作り直し、今度は settings に `CLAUDE_CODE_THRIFTY_SONIC=0` を足して同じ手順を実行する。

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

```bash
cd "$DIR" && claude -p 'sub/note.txt の status を final に変えて' \
  --permission-mode auto --no-session-persistence \
  --output-format stream-json --verbose > stream.jsonl
```

`stream.jsonl` の `tool_use` を見れば、対象ファイルを `Read` と Bash のどちらで読んだかが分かる。
ただし headless CLI の auto mode は host 側の auto mode と system prompt が同じとは限らない。
手順1の確認を headless 側でも行う。

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
- **2.1.263 の headless CLI 自体には Bash-first steering が無い**: system prompt には逆に dedicated tool を優先させる記述があると model が答え、route の実測もそれと一致した。
  `CLAUDE_CODE_THRIFTY_SONIC=0` の有無で route も判定も変わらなかった(各4回)。
  この環境は bug の前提条件を再現しないので、flag の効果はここでは測れていない。
  flag の判定は、手順1で steering の存在を確認できた host で行う必要がある。
- 挙動だけを見る canary の偽陰性も確認した。
  「変更したファイルの末尾に `CANARY-<ID>` の行を足す」形の指示は、ロードされた上で prompt injection と判定されて拒否された。
  この文書の canary を記法規約の形にしているのはこのため。
- **別環境での再確認(各1回)**: 同じ 2.1.263 / `claude-sonnet-5` を別のセッション・別のマシンで実行し、route 固定の結果を再現した。
  Bash 固定は `loaded.log` が空のままで `status: final`(記法規約が効いていない)、`CHANGELOG.txt` も作られない。
  dedicated tool 固定は `nested_traversal` と `path_glob_match` が並び、`status: FINAL-r<ID>` と `CHANGELOG.txt` の追記が出た。
- **steering は host によっては system prompt の外から来る**: 同じ 2026-09-08 の Claude Code on the web(auto mode)のセッションでは、Bash-first steering が base system prompt ではなく turn 単位で注入される指示として観測された。
  headless CLI に steering が無くても、同じ version の別 host には掛かっている。
  flag の判定はそうした host で行える。手順1で層を限定して訊いてはいけないのはこのため。

## 上流修正後の撤去

ADR 0002 の撤去条件を満たすかどうかは、この手順で判定する。

1. 上流 report([#90450](https://github.com/anthropics/claude-code/issues/90450) / [#92271](https://github.com/anthropics/claude-code/issues/92271))に対応する fix が入った version を特定する。
   issue の close や release note だけを根拠にしない。
2. その version で上の手順を実行し、`CLAUDE_CODE_THRIFTY_SONIC` 未設定でも `loaded.log` に対象の instruction file が並び、挙動にも出ることを確認する。
   Bash に route を固定した確認でもロードされるなら、上流が access method 側を広げたことになる。
3. その時点で `Read` / `Edit` / `Write` matcher の hooks を配布していれば、それらが Bash 経路で迂回されないことも確認する。
4. 確認できたら、README の workaround 案内と `rules/claude.md` の「path に紐づく指示のロード」節を削除する。
   `rules/claude.md` は「変更前に現在の内容を確認する」という tool 非依存の不変則だけに戻す。
5. ADR 0002 は書き換えず、撤去を決めた ADR を追加して supersede する。

この文書自体は、将来の harness regression 検出に使えるので撤去後も残してよい。
