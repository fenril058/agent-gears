# zsh の NOMATCH による失敗の health check と canary(2026-10-21)

zsh を実行シェルにしたエージェントが、glob 文字を含む引数を引用せずに渡して `no matches found` で失敗する。
これを常時ルールで減らせるかを検討し、health check と canary を行った。
結論は、候補ルールを現時点では採用しない、である。

この文書は ADR 0001 に従う。
health check は実利用で観測された失敗の非因果的な点検であり、候補の効果を主張しない。
canary は ADR 0001 の再開条件を満たす隔離境界を構成して始めたが、事前に定めた停止条件に達し、比較までは行っていない。

## 観測された失敗

zsh は既定で `NOMATCH` が有効で、どのファイルにもマッチしない glob を含む単純コマンドを実行せずにエラーにする。
bash はマッチしない glob をそのまま引数として渡すので、同じコマンドが bash では通る。

`zsh -c` では、エラーになった単純コマンド(パイプラインの1段)だけが実行されず、後続のコマンドは続けて実行される。
コマンド列全体の終了コードが 0 になることもある。

```console
$ zsh -fc 'echo first; grep -r foo --include=*.ts . | head -1; echo after'; echo "exit=$?"
first
zsh:1: no matches found: --include=*.ts
after
exit=0
```

## Health check(Claude Code の transcript)

対象は、2026-10-21 時点で `~/.claude/projects/` に残っていた1利用者の transcript 36 件(Bash 呼び出し 5,555 回)である。
シェルのエラー行 `(eval):N: no matches found: X` のうち、`X` がそのコマンドの文字列に含まれるものだけを数えた。
出力に過去のログが含まれていただけの偽陽性を除くためである。

| 項目 | 値 |
| --- | --- |
| NOMATCH を含む transcript | 36 件中 18 件 |
| NOMATCH(transcript・コマンド・語の組で一意) | 59 件(Bash 呼び出しの約 1.1%) |
| うち `claude-opus-5-5` | Bash 呼び出し 3,686 回中 39 件 |
| `--include=*.ts` などのオプション引数 | 44 件 |
| 意図した展開がマッチしなかったもの(`ls dir/*.ts` など) | 12 件 |
| URL のクエリ、リビジョン指定 | 3 件 |

件数には、transcript 上で同じコマンドが重複して記録されたものと、調査中に意図して起こした失敗が一部含まれる。
概算として扱う。

失敗は現行モデルでも 2026-10 中ほぼ毎日起きていた。
オプション引数の失敗から無作為に5件を抽出して直後の行動を読むと、いずれも次の1〜2回の呼び出しで、`--include` を外す、`git grep` に切り替えるなどして回復していた。
検索が実行されなかったことを「該当なし」と誤読して結論を誤った例は、抽出した範囲には無かった。
全件は確認していない。

この記録を作成する作業の途中でも、長いセッションの中で `grep -rn ... --include=*.md` を引用せずに実行して同じ失敗が起きた。

## 候補ルール

`rules/always-on.md` に次の節を足す案を検討した。

```markdown
## シェル

- シェルにファイル名として展開させない引数は、glob 文字（`*` `?` `[` `]`）を含むなら単一引用符で囲む。
  例: `grep -r --include='*.ts'`、`find . -name '*.json'`、`rg -g '*.md'`、`?` を含む URL。
  ファイル名の展開を意図するパターン（`ls src/*.ts`）は引用しない。
```

「glob 文字を常に引用する」形にしなかったのは、意図した展開まで引用されると、展開されずに別の失敗になるからである。

## Canary

### 判断に使う問い

候補ルールを足すと、リテラル引数による NOMATCH が減るか。
その代わりに、意図した展開の誤った引用、再試行、ツール呼び出し回数、トークン消費が増えないか。
結果で採用・修正・不採用を決める。

### 時間箱と停止条件

実行は最大 24 回とし、次のいずれかで停止する。

- 隔離 probe で、到達してはならない経路が見える。
- 対照群のパイロットで NOMATCH が起きない(シナリオが測定対象の失敗を引き出せない)。
- 認証または通信の問題で実行できない。

### 隔離境界

各 run を新しい bubblewrap の名前空間で実行した。

- `HOME` と `/tmp` は run ごとに空の tmpfs にし、PID・IPC・UTS 名前空間を分離する。
- 見えるのは `/usr`、`/etc`、WSL の `/mnt/wsl/resolv.conf`、Claude Code のバイナリ(いずれも読み取り専用)と、合成したプロジェクトだけにする。
- arm 間の差は sandbox 内の `~/.claude/CLAUDE.md` だけにする。
  対照群は `origin/main` の `rules/always-on.md`、処置群はそれに候補ルールを足したものを置く。
- `CLAUDE.md` と認証ファイルは `--ro-bind-data` で中身だけを渡す。
  bind mount にすると `/proc/self/mountinfo` に元のパスが出て、arm 名が漏れるからである。
- プロジェクトは tar にして `--file` で渡し、sandbox 内で展開したあと tar を消す。
- 候補ルールは、run の間どの Git repository にも Nix store にも置かない。

```bash
bwrap --die-with-parent --unshare-pid --unshare-ipc --unshare-uts --hostname box \
  --ro-bind /usr /usr --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64 --symlink usr/sbin /sbin \
  --ro-bind /etc /etc --ro-bind /mnt/wsl/resolv.conf /mnt/wsl/resolv.conf \
  --ro-bind "$CLAUDE_BIN" /opt/claude/claude \
  --proc /proc --dev /dev --tmpfs /tmp \
  --dir /home/dev/.claude --dir /work \
  --ro-bind-data 3 /home/dev/.claude/.credentials.json \
  --ro-bind-data 4 /home/dev/.claude/CLAUDE.md \
  --file 5 /tmp/s.tar \
  --clearenv --setenv HOME /home/dev --setenv USER dev --setenv SHELL /usr/bin/zsh \
  --setenv PATH /usr/local/bin:/usr/bin:/bin --setenv LANG C.UTF-8 --setenv TERM dumb \
  --chdir /work \
  /usr/bin/bash -c 'tar -xf /tmp/s.tar -C /work && rm -f /tmp/s.tar && cd /work/shop && exec /opt/claude/claude -p "$1" --output-format stream-json --verbose --dangerously-skip-permissions --max-turns 20 < /dev/null' _ "$prompt" \
  3< "$HOME/.claude/.credentials.json" 4< "$ARM_CLAUDE_MD" 5< "$REPO_TAR"
```

WSL では `/etc/resolv.conf` が `/mnt/wsl/resolv.conf` への symlink なので、それも bind しないと名前解決が `EAI_AGAIN` で失敗する。
初回の run はこれで失敗した。

両 arm で、次の probe を Claude Code の代わりに実行して境界を確認した。

- 利用者の home、`/nix`、エージェントのスクラッチ領域、transcript の保存先は存在しない。
- 環境変数は `HOME`、`LANG`、`PATH`、`SHELL`、`TERM`、`USER` と shell が設定するものだけである。
- 見えるプロセスは sandbox 内のものだけである。
- `/proc/self/mountinfo` に arm 名、対象名、スクラッチ領域のパスは出ない。
  Claude Code のバイナリの元パス(利用者名を含む)は出るが、両 arm で同じである。
- 候補ルールに固有の語句は、対照群では見つからず、処置群では `~/.claude/CLAUDE.md` にだけある。

### シナリオ

合成した小さな TypeScript プロジェクトで、次の3問を出した。
いずれも、カレントディレクトリにマッチするファイルが無いので、パターンを引用しないと zsh では NOMATCH になる。

| ID | 依頼 | 引用しないと失敗する例 | 正解 |
| --- | --- | --- | --- |
| T1 | `formatPrice` を呼ぶ TypeScript のソースファイル(テストを除く) | `grep -rn formatPrice --include=*.ts .` | 3 ファイル |
| T2 | `src/server` 直下の `.ts` ファイルの行数の合計 | `find src/server -name *.ts` | 8 |
| T3 | `config` 以下の `app-` で始まる JSON ファイル | `find config -name app-*.json` | 3 ファイル |

### 結果

Claude Code 2.1.305、`claude-opus-5-5` で、対照群のパイロットを1回ずつ実行した。

| ID | 実行したコマンド | NOMATCH | 回答 | ツール呼び出し |
| --- | --- | --- | --- | --- |
| T1 | `git ls-files \| grep -E '\.(ts\|tsx\|mts\|cts)$' \| xargs grep -n 'formatPrice'` | 0 | 正解 | 1 |
| T2 | `find src/server -maxdepth 1 -type f -name '*.ts' -print0 \| xargs -0 wc -l` | 0 | 正解 | 1 |
| T3 | `find /work/shop/config -type f -name 'app-*.json'` ほか1回 | 0 | 正解 | 2 |

候補ルールが無くても、パターンを自分で引用するか、`--include` を使わない書き方を選んだ。
停止条件に達したので、処置群は実行していない。
DNS で失敗した1回を含めて4回実行し、費用は合計約 0.27 USD だった。

実利用の失敗は、長い調査の途中で `grep` を続けて書くときに起きている。
新しい文脈で1問だけを出すシナリオでは、この条件を再現できなかったと推定する。
長いセッションを隔離して再現するのは、今回の時間箱とコストに収まらない。

## 判断

候補ルールは現時点では採用しない。

- 実利用で、現行モデルでも Bash 呼び出しの約 1% で失敗が起きており、問題は存在する。
- しかし canary では、候補ルールの効果も、誤った引用、再試行、ツール呼び出し回数、トークン消費への影響も測れなかった。
- 失敗のコストは、抽出した例では追加の呼び出し1回程度で、誤読による誤った結論は見つかっていない。
- 候補ルールは全セッションの常時ルールに約 350 バイトを加える。

次のどちらかが起きたら再検討する。

- 検索の空振りを誤読して結論を誤った実例が見つかる。
- 長いセッションを隔離して再現できる手段が、first-party tooling または検証可能な sandbox で用意できる。

確実に効く代替として次も比較したが、採らなかった。

- `PreToolUse` hook で、引用されていない `--include=*` などを拒否する。
  効果は確実だが、新しい仕組みの保守が要り、Claude Code にしか効かない。
- 非対話の zsh で `NO_NOMATCH` を設定する。
  マッチした場合の展開は残るので引用の代わりにならず、エージェント以外の zsh スクリプトの意味も変える。

Codex は評価していない。
ADR 0001 に従い、host をまたいだ結果は合算しない。
