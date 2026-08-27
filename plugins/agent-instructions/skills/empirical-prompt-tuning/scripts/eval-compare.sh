#!/usr/bin/env bash
#
# eval-compare.sh — agent-gears/eval-run@1 の結果ファイルを突き合わせる。
#
# 主出力は accuracy の差ではなく【requirement 単位の差分行列】である。
# 最初の実測で、accuracy だけ見ると読み違えることが分かった: with 0.750 /
# tampered 0.833 は「改竄した方が良い」と読めてしまうが、実際に動いたのは
# 非 critical 1件だけだった。accuracy / success / duration / tool_uses は
# secondary summary に置く。
#
# 比較の単位は (case, host, model, candidate) である。host/model をまたいだ
# 平均・勝者・総合スコアは出さない。出せないように、比較の前提を機械的に
# 検査して満たさない組み合わせを拒否する:
#   corpus.digest / host.id / host.model が一致すること
#   host.model が "unknown" でないこと
#   (case_id, trial) の集合が一致すること
#   verdict が unevaluated の (case_id, trial, requirement_id) 集合が一致すること
#   candidate が互いに異なること(identity は (kind, revision))
#
# 入力の結果ファイルは immutable として扱う(書き換えない)。集計の前に
# scripts/check-evals.sh を通し、通らない入力は集計しない。検証していない
# 結果を集計すると、success / accuracy が verdict と食い違ったまま表に載る。
#
# 使い方:
#   eval-compare.sh <run.json> <run.json> [<run.json>...] [--reference <run.json>]
#     --reference   movement の基準にする run(既定: without-skill が1本だけ
#                   あればそれ、無ければ最初の引数)
#
# 必要: jq。git があれば corpus.path をリポジトリルートから解決する。
set -euo pipefail

files=()
reference=""

die() {
  echo "eval-compare: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
eval-compare.sh <run.json> <run.json> [<run.json>...] [--reference <run.json>]

  --reference <run.json>  movement の基準にする run
                          既定: without-skill が1本だけあればそれ、無ければ最初の引数

主出力は requirement 単位の差分行列。accuracy / success / duration / tool_uses は
secondary summary。比較不能な組み合わせは拒否する(digest / host.id / host.model /
model!=unknown / (case_id,trial) 集合 / unevaluated 集合 / candidate が異なること)。
host.version は比較条件ではないが、arm ごとに違えば開示する。
USAGE
}

need_value() {
  [ "$2" -ge 2 ] || die "$1 needs a value"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --reference)
    need_value "$1" "$#"
    reference="$2"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*) die "unknown option: $1" ;;
  *)
    files+=("$1")
    shift
    ;;
  esac
done

[ "${#files[@]}" -ge 2 ] || die "needs at least 2 run files"
for f in "${files[@]}"; do
  [ -f "$f" ] || die "run file not found: $f"
done

# 結果ファイルの corpus.path はリポジトリルート相対で記録されている。
# check-evals.sh もそこで解決するので、同じ根から引く。
first_dir="$(cd "$(dirname "${files[0]}")" && pwd)"
repo="$(git -C "$first_dir" rev-parse --show-toplevel 2>/dev/null || pwd)"

# --- 検証していない入力は集計しない -----------------------------------------
check="${EVAL_CHECK:-$repo/scripts/check-evals.sh}"
[ -f "$check" ] || die "check-evals.sh not found at $check (set EVAL_CHECK)"
if ! bash "$check" "${files[@]}" >/dev/null; then
  die "the input above does not pass $check; a run that fails validation is not aggregated"
fi

corpus_rel="$(jq -r '.corpus.path' "${files[0]}")"
corpus="$repo/$corpus_rel"
[ -f "$corpus" ] || corpus="$corpus_rel"
[ -f "$corpus" ] || die "corpus not found: $corpus_rel (resolved from $repo)"

# --- reference の決定 --------------------------------------------------------
# 既定は without-skill。2本以上あるとどちらが基準か決まらないので、その場合は
# 最初の引数にする(--reference で明示できる)。
if [ -z "$reference" ]; then
  base_idx=-1
  base_n=0
  for i in "${!files[@]}"; do
    if [ "$(jq -r '.candidate.kind' "${files[$i]}")" = "without-skill" ]; then
      base_idx="$i"
      base_n=$((base_n + 1))
    fi
  done
  if [ "$base_n" = 1 ]; then
    reference="${files[$base_idx]}"
  else
    reference="${files[0]}"
  fi
fi
ref_idx=-1
for i in "${!files[@]}"; do
  [ "${files[$i]}" = "$reference" ] && ref_idx="$i"
done
[ "$ref_idx" -ge 0 ] || die "--reference must be one of the run files: $reference"

# --- 比較可能性 --------------------------------------------------------------
# 先頭を錨にした総当たり。EVAL-CORPUS.md「Do not fold hosts together」の条件を
# そのまま検査する。満たさない組み合わせは黙って混ぜず、ここで止める。
read -r -d '' JQ_GATE <<'JQ' || true
# 表示境界でのエスケープ。run ファイルの自由文字列(label / revision / note /
# host metadata / id 類)は check-evals.sh が「非空の文字列」としか見ておらず、
# 改行や端末制御列を含みうる。そのまま行指向の出力へ埋めると、schema 検証を
# 通った入力から偽の見出しや偽の測定行を生成できる(実際に、label に改行を
# 入れるだけで requirement-level delta matrix の偽の行を本物の上に出せた)。
# tojson で JSON 文字列にしてから両端の引用符を落とすと、制御文字は \n などの
# 可視な2文字へ落ち、非 ASCII はそのまま残る。
def viz: tojson | .[1:-1];

. as $runs
| ($runs[0]) as $a
| ($names[0] | viz) as $an
| ([ $runs[0].results[] | "\(.case_id)#\(.trial)" ] | sort | unique) as $akeys
| [ range(1; ($runs | length)) as $i
    | $runs[$i] as $b | ($names[$i] | viz) as $bn
    | ([ $b.results[] | "\(.case_id)#\(.trial)" ] | sort | unique) as $bkeys
    | ([ $a.results[] | .case_id as $c | .trial as $t | .requirements[]
         | select(.verdict == "unevaluated") | "\($c)#\($t)/\(.id)" ] | sort) as $aun
    | ([ $b.results[] | .case_id as $c | .trial as $t | .requirements[]
         | select(.verdict == "unevaluated") | "\($c)#\($t)/\(.id)" ] | sort) as $bun
    | [ (if $b.corpus.digest != $a.corpus.digest
         then "corpus.digest mismatch: \($an) is \($a.corpus.digest | viz) but \($bn) is \($b.corpus.digest | viz) — results are only comparable within one corpus digest"
         else empty end),
        (if $b.host.id != $a.host.id
         then "host.id mismatch: \($an) is \"\($a.host.id | viz)\" but \($bn) is \"\($b.host.id | viz)\" — the comparison unit is (case, host, model, candidate)"
         else empty end),
        (if $b.host.model != $a.host.model
         then "host.model mismatch: \($an) is \"\($a.host.model | viz)\" but \($bn) is \"\($b.host.model | viz)\" — the same edit can help one model and hurt another"
         else empty end),
        (if $bkeys != $akeys
         then "case/trial set mismatch: \($an) covers \($akeys | map(viz) | join(", ")) but \($bn) covers \($bkeys | map(viz) | join(", ")) — differing trial protocols are not comparable"
         else empty end),
        # 片方だけ測れた項目があると、その movement は候補の改善ではなく証拠の
        # 有無を映す(unevaluated -> pass は「良くなった」ではない)。accuracy の
        # 分母も片方だけ変わる。EVAL-CORPUS.md:
        # 「A run carrying any unevaluated verdict is not comparable to one that
        #  measured that item.」
        (if $bun != $aun
         then "unevaluated set mismatch: \($an) and \($bn) disagree on which items were measured at all: \((($aun - $bun) + ($bun - $aun)) | sort | map(viz) | join(", ")) — a run carrying an unevaluated verdict is not comparable to one that measured that item, and their accuracy denominators differ"
         else empty end) ]
  ]
# candidate の相異は等値関係ではないので、先頭を錨にした比較では足りない。
# A, B, B の後ろ2本は「先頭と違う」だけで通ってしまう。全 i<j ペアで見る。
# identity は (kind, revision)。label は identity ではない —— EVAL-CORPUS.md の
# 「Variant exploration」が draft の身元を revision に置けと言っているのは、
# label は何も検証しないからである。without-skill は revision を持てないので、
# label が違っても同じ candidate になる(baseline 2本は比較ではない)。
+ [ range(0; ($runs | length)) as $i
    | range($i + 1; ($runs | length)) as $j
    | select(($runs[$i].candidate | {kind, revision}) == ($runs[$j].candidate | {kind, revision}))
    | "candidate is identical in \($names[$i] | viz) and \($names[$j] | viz) — a comparison needs the candidate to differ, and its identity is (kind, revision); a different label is not a different candidate" ]
+ [ range(0; ($runs | length)) as $i
    | (if $runs[$i].host.model == "unknown"
       then "host.model is \"unknown\" in \($names[$i] | viz) — a run whose model is unknown is not comparable to anything"
       else empty end) ]
| flatten
| .[]
JQ

# 診断は「1件 = 1行」が前提である(すぐ下で sed が行頭に "  - " を付ける)。補間する値に
# 改行が混じると、injected line まで正規の診断 bullet として表示される。run 由来の
# 文字列は check-evals.sh が非空しか見ないので、host.id に改行を入れた schema-valid な
# run を作れてしまう。gate 内の補間も本文側と同じく viz を通すこと。
# 診断に出すファイル名は jq へ配列で渡す(引数順と索引を一致させる)。
names_json="$(printf '%s\n' "${files[@]}" | jq -R . | jq -s .)"
gate="$(jq -s -r --argjson names "$names_json" "$JQ_GATE" "${files[@]}")"
if [ -n "$gate" ]; then
  echo "NG: not comparable" >&2
  printf '%s\n' "$gate" | sed 's/^/  - /' >&2
  exit 2
fi

# --- 本体 -------------------------------------------------------------------
read -r -d '' JQ_MAIN <<'JQ' || true
# 桁揃えは切り捨てない。id が長い corpus で列が揃わなくなるのは構わないが、
# 表から文字が消えるのは困る(切り捨てた id は別物と区別できなくなる)。
# jq では " " * 0 が null になるので、最低1文字は空ける。
def pad($n): . + (" " * (if ($n - length) > 0 then ($n - length) else 1 end));
# 表示境界でのエスケープ。run ファイルの自由文字列(label / revision / note /
# host metadata / id 類)は check-evals.sh が「非空の文字列」としか見ておらず、
# 改行や端末制御列を含みうる。そのまま行指向の出力へ埋めると、schema 検証を
# 通った入力から偽の見出しや偽の測定行を生成できる(実際に、label に改行を
# 入れるだけで requirement-level delta matrix の偽の行を本物の上に出せた)。
# tojson で JSON 文字列にしてから両端の引用符を落とすと、制御文字は \n などの
# 可視な2文字へ落ち、非 ASCII はそのまま残る。
def viz: tojson | .[1:-1];

($corpus[0]) as $cor
| ($cor.cases | map({key: .id, value: .}) | from_entries) as $byCase
| . as $runs
| ($runs | length) as $n
# arm のタグは引数順。reference には * を付ける。
| [ range(0; $n) | "#\(. + 1)" + (if . == $ref then "*" else "" end) ] as $tag
# run ごとに (case#trial -> requirement id -> 結果) の索引を作る。
| [ $runs[]
    | .results
    | map({key: "\(.case_id)#\(.trial)",
           value: (.requirements | map({key: .id, value: .}) | from_entries)})
    | from_entries ] as $idx
| [ $runs[] | .results | map({key: "\(.case_id)#\(.trial)", value: .}) | from_entries ] as $rowIdx
| ([ $runs[0].results[] | {case_id, trial} ]) as $keys
# 走った case が corpus 全体を覆っているか。覆っていなくても比較は成立するので
# 拒否はしない(変えた case だけ走らせ直す使い方は正当)。ただし黙ってはいけない:
# 1 case だけの run が corpus 全体の run を名乗れてしまうのが元の穴だった。
| ($keys | map(.case_id) | unique) as $ran
| ($cor.cases | map(.id)) as $all
| ($all - $ran) as $missing
# host.version は比較条件ではない(EVAL-CORPUS.md の比較単位は host.id と host.model)。
# 許すのは構わないが、先頭 run の version だけをヘッダに出すと、全 arm が同じ version
# だったように読める。全 arm 同一のときだけ共通表示にし、違えば arm ごとに開示する。
| ([ $runs[] | .host.version // null ] | unique) as $vers
| (if ($vers | length) == 1 then $vers[0] else null end) as $commonVer
| (($vers | length) > 1) as $verDiffers
# セル文字列: verdict(+ surface が corpus に宣言されていれば /hit|/miss)
| def cell($r): if $r == null then "-"
    else $r.verdict + (if ($r | has("surface")) then "/" + $r.surface else "" end) end;
[
  "corpus   \($cor.skill | viz)   \($runs[0].corpus.path | viz)",
  "digest   \($runs[0].corpus.digest | viz)",
  "host     \($runs[0].host.id | viz) / \($runs[0].host.model | viz)"
    + (if $verDiffers then "   (host version は arm ごとに違う —— 下の arms を見ること)"
       elif $commonVer then " / \($commonVer | viz)"
       else "" end),
  "cases    \($ran | length) / \($all | length) in corpus   trials   {\($keys | map(.trial) | unique | sort | join(", "))}"
]
+ (if ($missing | length) > 0
   then [ "         PARTIAL CORPUS — not run: \($missing | map(viz) | join(", "))",
          "         この比較は corpus 全体の比較ではない。走っていない case の regression は見えない。" ]
   else [] end)
+ [
  "",
  "arms     (* = reference for movement)"
]
+ [ range(0; $n) as $i
    | "  \($tag[$i] | pad(4)) \($runs[$i].candidate.kind | viz | pad(14)) \($runs[$i].candidate.label | viz)"
      + (if $runs[$i].candidate.revision then "  [\($runs[$i].candidate.revision | viz)]" else "" end)
      + (if $verDiffers then "   host version \(($runs[$i].host.version // "-") | viz)" else "" end) ]
+ [ "",
    "## requirement-level delta matrix",
    "",
    ("case" | pad(27)) + ("trial" | pad(6)) + ("requirement" | pad(28)) + ("crit" | pad(6))
      + ([ range(0; $n) | $tag[.] | pad(14) ] | add) + "movement" ]
+ [ $keys[] as $k
    | "\($k.case_id)#\($k.trial)" as $kk
    | $byCase[$k.case_id].requirements[] as $req
    | [ range(0; $n) | $idx[.][$kk][$req.id] ] as $cells
    | ($cells[$ref] | cell(.)) as $refv
    | ($k.case_id | viz | pad(27)) + ($k.trial | tostring | pad(6)) + ($req.id | viz | pad(28))
      + ((if $req.critical then "*" else "" end) | pad(6))
      + ([ range(0; $n) | ($cells[.] | cell(.)) | pad(14) ] | add)
      + ([ range(0; $n)
           | select(. != $ref)
           | . as $i | ($cells[$i] | cell(.)) as $v
           | select($v != $refv)
           | "\($tag[$i]) \($refv)->\($v)" ] | join("; ")) ]
+ [ "",
    "## secondary summary",
    "",
    ("case" | pad(27)) + ("trial" | pad(6)) + ("arm" | pad(6)) + ("success" | pad(9))
      + ("accuracy" | pad(10)) + ("tool_uses" | pad(11)) + ("duration_ms" | pad(12)) ]
+ [ $keys[] as $k
    | "\($k.case_id)#\($k.trial)" as $kk
    | range(0; $n) as $i
    | ($rowIdx[$i][$kk]) as $row
    | ($k.case_id | viz | pad(27)) + ($k.trial | tostring | pad(6)) + ($tag[$i] | pad(6))
      + (($row.success | tostring) | pad(9))
      + ((if $row.accuracy == null then "null" else ($row.accuracy * 1000 | round / 1000 | tostring) end) | pad(10))
      + ((if ($row | has("tool_uses")) then ($row.tool_uses | tostring) else "-" end) | pad(11))
      + ((if ($row | has("duration_ms")) then ($row.duration_ms | tostring) else "-" end) | pad(12)) ]
# --- 全 arm で verdict が同じ requirement --------------------------------
| . as $out
| ([ $keys[] as $k
     | "\($k.case_id)#\($k.trial)" as $kk
     | $byCase[$k.case_id].requirements[] as $req
     | select([ range(0; $n) | $idx[.][$kk][$req.id].verdict ] | unique | length == 1)
     # unevaluated は第四の verdict ではなく「測定が存在しない」状態なので、
     # この節には入れない。ここは「候補について情報を持たない requirement」を
     # 探す診断で、未測定の項目を混ぜると skill 縮小候補として調べに行かせてしまう。
     # 別節 (unevaluated in every arm) に出す。
     | select($idx[0][$kk][$req.id].verdict != "unevaluated")
     # 判定は (case, trial, requirement) 単位なので、表示キーにも trial が要る。
     # 落とすと trial 1 の全 arm pass と trial 2 の全 arm fail が、同じ case /
     # requirement の区別できない2行になる。
     | "  \($k.case_id | viz | pad(27))\($k.trial | tostring | pad(6))\($req.id | viz | pad(28))\($idx[0][$kk][$req.id].verdict)"
       + (if $req.critical then "   [critical]" else "" end) ]) as $same
| $out
+ [ "", "## same verdict in every arm   (case, trial, requirement ごと)", "" ]
+ (if ($same | length) == 0 then [ "  (none)" ] else $same end)
+ [ "",
    "  これは「不要な requirement」の判定ではない。skill を縮小できる兆候か、",
    "  全 arm に残る skill の欠陥か、corpus の遊びかの分類は人が行う。" ]
# --- 全 arm で未測定の requirement ----------------------------------------
# gate が unevaluated 集合の一致を要求しているので、unevaluated な項目は必ず
# 全 arm で unevaluated である。黙って落とすと、証拠を捕り損ねたことごと消える。
| . as $out
# gate が保証するのは「同じ requirement が全 arm で unevaluated」までで、
# 未測定になった理由が同じことまでは保証しない。note は「何の証拠が欠けたか」の
# 記録なので、先頭 arm のものだけを無印で代表させると差が消える。
# 全 arm 同一のときだけ1行に畳み、違えば arm ごとに出す。
| ([ $keys[] as $k
     | "\($k.case_id)#\($k.trial)" as $kk
     | $byCase[$k.case_id].requirements[] as $req
     | select($idx[0][$kk][$req.id].verdict == "unevaluated")
     | ([ range(0; $n) | ($idx[.][$kk][$req.id].note // "(note なし)") | viz ]) as $notes
     | (($notes | unique | length) == 1) as $sameNote
     | [ "  \($k.case_id | viz | pad(27))\($k.trial | tostring | pad(6))\($req.id | viz | pad(28))"
         + (if $sameNote then $notes[0] else "(欠けた証拠が arm ごとに違う)" end)
         + (if $req.critical then "   [critical]" else "" end) ]
       + (if $sameNote then []
          else [ range(0; $n) as $i | "      \($tag[$i] | pad(6))\($notes[$i])" ] end) ]
   | flatten) as $unev
| $out
+ (if ($unev | length) == 0 then []
   else [ "", "## unevaluated in every arm   (測定が存在しない —— 候補についての所見ではない)", "" ]
        + $unev
        + [ "",
            "  これらは候補の良し悪しではなく、証拠を捕れなかったことの記録である。",
            "  [critical] が未測定でも、別の [critical] が fail か partial なら success は false で確定する。",
            "  未測定だけが true を妨げているときに限り null になる。" ] end)
# --- surface / semantic の食い違い ----------------------------------------
| . as $out
| ([ $keys[] as $k
     | "\($k.case_id)#\($k.trial)" as $kk
     | $byCase[$k.case_id].requirements[] | select(has("surface")) as $req
     | range(0; $n) as $i
     | ($idx[$i][$kk][$req.id]) as $r
     | select($r != null)
     | {req: "\($k.case_id | viz) / \($req.id | viz)", pair: "\($r.surface)+\($r.verdict)",
        unev: ($r.verdict == "unevaluated"),
        odd: (($r.surface == "hit" and ($r.verdict == "fail" or $r.verdict == "partial"))
              or ($r.surface == "miss" and $r.verdict == "pass"))} ]
   | group_by(.req)
   # unevaluated には semantic の判定が存在しないので、surface と突き合わせようがない。
   # 観測として数えると "miss+unevaluated x2 / odd 0" のように、一致を確かめた結果
   # 食い違いが無かったかのように読める。判定済みだけを数え、除いた件数は明示する。
   # 判定済みが1件も無い requirement は行ごと落とす(unevaluated in every arm に出る)。
   | map({req: .[0].req,
          judged: map(select(.unev | not)),
          skipped: (map(select(.unev)) | length)})
   | map(select((.judged | length) > 0))
   | map({req: .req, odd: (.judged | map(select(.odd)) | length),
          pairs: ((.judged | group_by(.pair) | map("\(.[0].pair) x\(length)") | join(", "))
                  + (if .skipped > 0 then "   (未測定 \(.skipped) 件を除く)" else "" end))})) as $sf
| $out
+ [ "", "## surface / semantic   (arm x case x trial の観測を数える)", "" ]
+ (if ($sf | length) == 0 then [ "  (surface pattern を持つ判定済みの requirement が無い)" ]
   else ([ ("  " + ("requirement" | pad(50)) + ("odd" | pad(6)) + "observed (surface+verdict)") ]
         + [ $sf[] | "  " + (.req | pad(50)) + (.odd | tostring | pad(6)) + .pairs ]
         + [ "",
             "  odd = surface hit なのに semantic が partial/fail、または surface miss なのに pass。",
             "  unevaluated は semantic の判定が無いので数えない(除いた件数は行末に出す)。",
             "  1 trial では pattern の欠陥か偶然か決まらない。各 arm の trial を増やして数を見る。",
             "  同じ candidate の run を足すのは比較にならない(candidate の相異が要る)。" ]) end)
# --- arm 内の case 間 tool_uses ------------------------------------------
| . as $out
# trial をまたいで min/max/range を計算しない。SKILL.md の「1 scenario だけ
# 3-5倍」は同一 trial 内での case 間比較で、trial 1 の 3 と trial 2 の 15 を
# 同じ幅に入れると、trial 間のばらつきが case 間のスキューに化ける。
# trial をまたいだ要約は EVAL-CORPUS.md で「まだ設計していない」ものである。
| ([ range(0; $n) as $i
     | ($keys | map(.trial) | unique | sort)[] as $t
     # 欠損 case を黙って落とさない。tool_uses は optional なので「3 case 中1件だけ
     # 未記録」は正当な入力だが、落として計算すると 3, missing, 15 が
     # 「min 3 max 15 range 12」に、3, missing, missing が「range 0(スキュー無し)」に
     # 見える。この節は skew の診断に使うので、部分観測から幅を出してはいけない。
     # case の位置を保って - を残し、1件でも欠ければ min/max/range を出さない。
     | ([ $keys[] | select(.trial == $t)
          | $rowIdx[$i]["\(.case_id)#\(.trial)"]
          | if has("tool_uses") then .tool_uses else null end ]) as $vals
     | ($vals | map(select(. != null))) as $seen
     | "  " + ($tag[$i] | pad(6)) + ("trial \($t)" | pad(9))
       + (($vals | map(if . == null then "-" else tostring end) | join(", ")) | pad(30))
       + (if ($seen | length) == 0 then "(tool_uses 未記録)"
          elif ($seen | length) < ($vals | length)
          then "observed \($seen | length)/\($vals | length) — 欠損があるので min/max/range を出さない"
          else "min \($seen | min)  max \($seen | max)  range \(($seen | max) - ($seen | min))" end) ]) as $tu
| $out
+ [ "", "## tool_uses across cases, within arm", "" ]
+ $tu
+ [ "",
    "  記録の無い run は捏造せず - と出す。case が3件では高度な統計に意味は無い。",
    "  1 case だけ突出していれば、その case の手順が skill 本体に無い兆候(SKILL.md)。" ]
| .[]
JQ

jq -s -r --slurpfile corpus "$corpus" --argjson ref "$ref_idx" "$JQ_MAIN" "${files[@]}"
