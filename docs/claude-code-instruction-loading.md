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

## 準備

agent-gears の作業ツリーの外に、使い捨ての canary project を作る。
`<ID>` は実行のたびに新しいランダム文字列にする(前のセッションの文脈から sentinel が漏れるのを防ぐため)。

```bash
ID=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
DIR=$(mktemp -d)
mkdir -p "$DIR/sub"

cat > "$DIR/sub/CLAUDE.md" <<EOF
このディレクトリ配下のファイルを変更するときは、
変更内容にかかわらず、変更後のファイルの末尾に \`CANARY-$ID\` の行を1行足す。
EOF

cat > "$DIR/sub/note.txt" <<'EOF'
status: draft
EOF

echo "$DIR  CANARY-$ID"
```

## 手順

1. `CLAUDE_CODE_THRIFTY_SONIC` を設定しない状態で、`$DIR` を project directory として Claude Code を新規セッションで起動する。
   Auto mode を有効にする。
2. 中立な依頼を1つだけ出す。
   canary、`CLAUDE.md`、tool 名のいずれにも触れない。

   ```text
   sub/note.txt の status を final に変えて
   ```

3. セッション終了後に結果を見る。

   ```bash
   cat "$DIR/sub/note.txt"
   ```

4. `CANARY-$ID` の行があれば、その path の指示は有効になっている。
   無ければロードされていない。
5. 準備からやり直して `<ID>` と `$DIR` を作り直し、今度は settings に `CLAUDE_CODE_THRIFTY_SONIC=0` を置いて同じ手順を実行する。

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
| 無効 | 有効 | 上流 bug が再現している。暫定回避を続ける。 |
| 無効 | 無効 | この flag では回避できない。ADR 0002 の前提が変わったので再検討する。 |

1回の実行は決定的ではないので、判定を変える(特に「有効」へ転じる)ときは ID を変えて数回繰り返す。

## path-scoped rules の変種

nested `CLAUDE.md` の代わりに、同じ sentinel を持つ path 限定の rule を `.claude/rules/<name>.md` に置いて同じ手順を繰り返す。
frontmatter の書式はその時点の Claude Code のドキュメントに従い、この文書で固定しない。
nested `CLAUDE.md` と結果が分かれることがあるので、両方を確認する。

## 上流修正後の撤去

ADR 0002 の撤去条件を満たすかどうかは、この手順で判定する。

1. 上流 report([#90450](https://github.com/anthropics/claude-code/issues/90450) / [#92271](https://github.com/anthropics/claude-code/issues/92271))に対応する fix が入った version を特定する。
   issue の close や release note だけを根拠にしない。
2. その version で上の手順を実行し、`CLAUDE_CODE_THRIFTY_SONIC` 未設定でも sentinel が有効になることを確認する。
3. その時点で `Read` / `Edit` / `Write` matcher の hooks を配布していれば、それらが Bash 経路で迂回されないことも確認する。
4. 確認できたら、README の workaround 案内と `rules/claude.md` の「path に紐づく指示のロード」節を削除する。
   `rules/claude.md` は「変更前に現在の内容を確認する」という tool 非依存の不変則だけに戻す。
5. ADR 0002 は書き換えず、撤去を決めた ADR を追加して supersede する。

この文書自体は、将来の harness regression 検出に使えるので撤去後も残してよい。
