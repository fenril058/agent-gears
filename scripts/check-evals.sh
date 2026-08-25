#!/usr/bin/env bash
#
# check-evals.sh — skill に併置された eval corpus(evals/cases.json)と、
# runner が書き出す実行結果(agent-gears/eval-run@1)の形式を決定的に検証する。
#
# LLM を呼ぶ評価そのものは CI の必須ジョブにしない。ここで見るのは「呼ぶ前に
# 壊れていると分かること」だけ、つまり JSON として妥当か・参照先の skill と case が
# 実在するか・[critical] 要件が最低1つあるか、である。
#
# 結果ファイル側では empirical-prompt-tuning の判定規則そのものを検算する:
#   success  = [critical] 要件が全て pass のときだけ true
#   accuracy = (pass + 0.5 * partial) / 要件数
# 判定規則を人手で書き写す運用だと、ここがずれても誰も気づかない。
#
# 未知フィールドは失格にする。これは厳しさのためではなく、host/model をまたいだ
# 総合スコアのような集約フィールドが schema の議論を経ずに紛れ込むのを防ぐため。
#
# 結果ファイルを検証するときは、参照先 corpus も併せて検証する。corpus を信用して
# しまうと、[critical] が1つも無い corpus を指した run で「全要件 fail なのに
# success=true」が合格する(空虚な真)。この不変条件がこの検証の存在理由なので、
# 参照先を検証しない経路を残さない。
#
# 使い方:
#   bash scripts/check-evals.sh                  # plugins/ 配下の cases.json を全部
#   EVALS_SCAN_ROOT=<dir> bash scripts/check-evals.sh   # 走査ルートの差し替え(テスト用)
#   bash scripts/check-evals.sh <file>...        # 指定ファイル(.schema で振り分け)
#
# 必要: jq。CI では `nix shell nixpkgs#jq --command` 経由で実行する。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

CASES_SCHEMA="agent-gears/eval-cases@1"
RUN_SCHEMA="agent-gears/eval-run@1"

# 共通ヘルパ。エラーは文字列の配列で返し、呼び出し側で flatten する。
read -r -d '' JQ_LIB <<'JQ' || true
def unknown($path; $allowed):
  [ keys_unsorted[] as $k
    | select($allowed | index($k) | not)
    | "\($path): unknown field \"\($k)\"" ];

def str($path; $obj; $k):
  if ($obj | has($k) | not) then ["\($path): missing \"\($k)\""]
  elif ($obj[$k] | type) != "string" then ["\($path).\($k): must be a string"]
  elif ($obj[$k] | length) == 0 then ["\($path).\($k): must not be empty"]
  else [] end;

def optstr($path; $obj; $k):
  if ($obj | has($k) | not) then []
  else str($path; $obj; $k) end;

def obj($path; $obj; $k):
  if ($obj | has($k) | not) then ["\($path): missing \"\($k)\""]
  elif ($obj[$k] | type) != "object" then ["\($path).\($k): must be an object"]
  else [] end;

def nonNegInt($path; $obj; $k):
  if ($obj | has($k) | not) then []
  elif ($obj[$k] | type) != "number" or ($obj[$k] | floor) != $obj[$k] or $obj[$k] < 0
  then ["\($path).\($k): must be a non-negative integer"]
  else [] end;

def strArray($path; $obj; $k):
  if ($obj | has($k) | not) then []
  elif ($obj[$k] | type) != "array" then ["\($path).\($k): must be an array"]
  else [ $obj[$k] | to_entries[]
         | select((.value | type) != "string" or (.value | length) == 0)
         | "\($path).\($k)[\(.key)]: must be a non-empty string" ]
  end;

def dups($path; $ids; $what):
  [ $ids | group_by(.) | .[] | select(length > 1) | .[0]
    | "\($path): duplicate \($what) \"\(.)\"" ];
JQ

# --- corpus (agent-gears/eval-cases@1) ------------------------------------
# $dir は skill ディレクトリ名。cases.json の .skill と一致しなければならない
# (skill が plugin 間を移動しても、置き場所と宣言のずれをここで捕まえる)。
read -r -d '' JQ_CASES <<'JQ' || true
[
  unknown("$"; ["schema", "skill", "notes", "cases"]),
  (if .schema != $schema then ["$.schema: must be \"\($schema)\""] else [] end),
  str("$"; .; "skill"),
  (if $dir != "" and (.skill | type) == "string" and .skill != $dir
   then ["$.skill: \"\(.skill)\" does not match the skill directory \"\($dir)\""] else [] end),
  optstr("$"; .; "notes"),
  (if (.cases | type) != "array" then ["$.cases: must be an array"]
   elif (.cases | length) < 2
   then ["$.cases: needs at least 2 scenarios (SKILL.md: \"One scenario overfits. Minimum 2, ideally 3.\")"]
   else [
     dups("$.cases"; [.cases[].id | select(type == "string")]; "case id"),
     (.cases | to_entries | map(
       .key as $i | .value as $c | "$.cases[\($i)]" as $p |
       [
         ($c | unknown($p; ["id", "scenario", "prompt", "requirements", "tags", "notes"])),
         str($p; $c; "id"),
         (if ($c.id | type) == "string" and ($c.id | test("^[a-z0-9]+(-[a-z0-9]+)*$") | not)
          then ["\($p).id: must be kebab-case (stable across runs)"] else [] end),
         str($p; $c; "scenario"),
         str($p; $c; "prompt"),
         optstr($p; $c; "notes"),
         strArray($p; $c; "tags"),
         (if ($c.requirements | type) != "array" then ["\($p).requirements: must be an array"]
          elif ($c.requirements | length) < 3 or ($c.requirements | length) > 7
          then ["\($p).requirements: must hold 3 to 7 items (SKILL.md, Baseline preparation), found \($c.requirements | length)"]
          else [
            dups("\($p).requirements"; [$c.requirements[].id | select(type == "string")]; "requirement id"),
            (if [$c.requirements[] | select(.critical == true)] | length == 0
             then ["\($p).requirements: at least one requirement must have \"critical\": true (otherwise the success judgment is vacuous)"]
             else [] end),
            ($c.requirements | to_entries | map(
              .key as $j | .value as $r | "\($p).requirements[\($j)]" as $rp |
              [
                ($r | unknown($rp; ["id", "critical", "text", "surface"])),
                str($rp; $r; "id"),
                str($rp; $r; "text"),
                (if ($r | has("critical") | not) then ["\($rp): missing \"critical\""]
                 elif ($r.critical | type) != "boolean" then ["\($rp).critical: must be a boolean"]
                 else [] end),
                optstr($rp; $r; "surface"),
                (if ($r | has("surface")) and ($r.surface | type) == "string"
                    and ($r.surface | test("[[:cntrl:]]"))
                 then ["\($rp).surface: must not contain control characters"] else [] end)
              ] | flatten))
          ] | flatten end)
       ] | flatten))
   ] | flatten end)
] | flatten
JQ

# --- run results (agent-gears/eval-run@1) ---------------------------------
# $corpus は参照先 cases.json(1要素の配列)。case / requirement の実在と、
# success / accuracy の判定規則をここで検算する。
read -r -d '' JQ_RUN <<'JQ' || true
($corpus[0]) as $cor |
($cor.cases | map({key: .id, value: .}) | from_entries) as $byId |
[
  unknown("$"; ["schema", "run_id", "started_at", "corpus", "host", "candidate", "notes", "results"]),
  (if .schema != $schema then ["$.schema: must be \"\($schema)\""] else [] end),
  str("$"; .; "run_id"),
  optstr("$"; .; "started_at"),
  optstr("$"; .; "notes"),

  # eval-render.sh --result-stub の未記入マーカー。埋めないまま合格させない。
  # 雛形が実際に置くフィールドだけを見る。全文走査にすると、こちらが予約して
  # いない名前空間(corpus 側の id 等)の正当な値まで巻き込む。
  ([ [["run_id"], ["started_at"], ["host", "id"], ["host", "model"],
      ["candidate", "label"], ["candidate", "revision"]][] as $q
     | select(getpath($q) == "REPLACE-ME")
     | "$." + ($q | join(".")) + ": still the REPLACE-ME placeholder from --result-stub" ]),

  obj("$"; .; "corpus"),
  (if (.corpus | type) == "object" then
    [ (.corpus | unknown("$.corpus"; ["skill", "path", "digest"])),
      str("$.corpus"; .corpus; "skill"),
      str("$.corpus"; .corpus; "path"),
      str("$.corpus"; .corpus; "digest"),
      (if (.corpus.skill | type) == "string" and .corpus.skill != $cor.skill
       then ["$.corpus.skill: \"\(.corpus.skill)\" but the corpus at that path declares \"\($cor.skill)\""] else [] end),
      (if (.corpus.digest | type) == "string" and .corpus.digest != $digest
       then ["$.corpus.digest: \(.corpus.digest) but the corpus now hashes to \($digest) — results are only comparable within one corpus digest"] else [] end)
    ] | flatten else [] end),

  obj("$"; .; "host"),
  (if (.host | type) == "object" then
    [ (.host | unknown("$.host"; ["id", "model", "version"])),
      str("$.host"; .host; "id"),
      str("$.host"; .host; "model"),
      optstr("$.host"; .host; "version")
    ] | flatten else [] end),

  obj("$"; .; "candidate"),
  (if (.candidate | type) == "object" then
    [ (.candidate | unknown("$.candidate"; ["kind", "label", "revision"])),
      str("$.candidate"; .candidate; "kind"),
      str("$.candidate"; .candidate; "label"),
      ((.candidate.kind) as $kind
       | if ($kind | type) == "string" and (["with-skill", "without-skill"] | index($kind) | not)
         then ["$.candidate.kind: must be \"with-skill\" or \"without-skill\""] else [] end),
      (if .candidate.kind == "with-skill" then str("$.candidate"; .candidate; "revision")
       elif (.candidate | has("revision")) then ["$.candidate.revision: only meaningful when kind is \"with-skill\""]
       else [] end)
    ] | flatten else [] end),

  (if (.results | type) != "array" then ["$.results: must be an array"]
   elif (.results | length) == 0 then ["$.results: must not be empty"]
   else [
     dups("$.results"; [.results[] | select((.case_id | type) == "string") | "\(.case_id)#\(.trial)"]; "case_id#trial"),
     (.results | to_entries | map(
       .key as $i | .value as $t | "$.results[\($i)]" as $p |
       ($byId[$t.case_id // ""]) as $case |
       [
         ($t | unknown($p; ["case_id", "trial", "success", "accuracy", "requirements",
                            "tool_uses", "duration_ms", "retries", "token_usage",
                            "issues", "discretionary", "unevaluated", "notes"])),
         str($p; $t; "case_id"),
         (if $case == null and ($t.case_id | type) == "string"
          then ["\($p).case_id: \"\($t.case_id)\" is not a case in \($cor.skill)'s corpus"] else [] end),
         (if ($t | has("trial") | not) then ["\($p): missing \"trial\""]
          elif ($t.trial | type) != "number" or ($t.trial | floor) != $t.trial or $t.trial < 1
          then ["\($p).trial: must be an integer >= 1"] else [] end),
         (if ($t.success | type) != "boolean" then ["\($p).success: must be a boolean"] else [] end),
         (if ($t.accuracy | type) != "number" or $t.accuracy < 0 or $t.accuracy > 1
          then ["\($p).accuracy: must be a number in [0, 1]"] else [] end),
         nonNegInt($p; $t; "tool_uses"),
         nonNegInt($p; $t; "duration_ms"),
         nonNegInt($p; $t; "retries"),
         strArray($p; $t; "discretionary"),
         strArray($p; $t; "unevaluated"),
         optstr($p; $t; "notes"),
         (if ($t | has("token_usage") | not) then []
          elif ($t.token_usage | type) != "object" then ["\($p).token_usage: must be an object"]
          else [ ($t.token_usage | unknown("\($p).token_usage"; ["input", "output", "cache_read", "cache_write", "total"])),
                 [ $t.token_usage | to_entries[]
                   | select((.value | type) != "number" or (.value | floor) != .value or .value < 0)
                   | "\($p).token_usage.\(.key): must be a non-negative integer" ] ] | flatten end),
         (if ($t | has("issues") | not) then []
          elif ($t.issues | type) != "array" then ["\($p).issues: must be an array"]
          else ($t.issues | to_entries | map(
            .key as $j | .value as $x | "\($p).issues[\($j)]" as $xp |
            [ ($x | unknown($xp; ["phase", "issue", "cause", "general_fix_rule"])),
              str($xp; $x; "phase"),
              (if ($x.phase | type) == "string"
                  and (["understanding", "planning", "execution", "formatting"] | index($x.phase) | not)
               then ["\($xp).phase: must be one of understanding / planning / execution / formatting"] else [] end),
              str($xp; $x; "issue"),
              str($xp; $x; "cause"),
              str($xp; $x; "general_fix_rule")
            ] | flatten)) | flatten end),
         (if ($t.requirements | type) != "array" then ["\($p).requirements: must be an array"]
          else [
            ($t.requirements | to_entries | map(
              .key as $j | .value as $r | "\($p).requirements[\($j)]" as $rp |
              [ ($r | unknown($rp; ["id", "verdict", "surface", "note"])),
                str($rp; $r; "id"),
                str($rp; $r; "verdict"),
                (if ($r.verdict | type) == "string"
                    and (["pass", "fail", "partial"] | index($r.verdict) | not)
                 then ["\($rp).verdict: must be one of pass / fail / partial"] else [] end),
                (if ($r | has("surface") | not) then []
                 elif (["hit", "miss"] | index($r.surface) | not)
                 then ["\($rp).surface: must be \"hit\" or \"miss\""] else [] end),
                optstr($rp; $r; "note")
              ] | flatten)),
            (if $case == null then [] else
              ([$case.requirements[].id] | sort) as $want |
              ([$t.requirements[].id | select(type == "string")] | sort) as $got |
              (if $want != $got
               then ["\($p).requirements: ids must cover the case exactly — missing \($want - $got), unexpected \($got - $want)"]
               else
                 ([$case.requirements[] | select(.critical == true) | .id]) as $crit |
                 ($t.requirements | map({key: .id, value: .verdict}) | from_entries) as $v |
                 ([$crit[] | select($v[.] != "pass")] | length == 0) as $expectSuccess |
                 (([$t.requirements[] | if .verdict == "pass" then 1 elif .verdict == "partial" then 0.5 else 0 end] | add)
                   / ($t.requirements | length)) as $expectAcc |
                 [ (if ($t.success | type) == "boolean" and $t.success != $expectSuccess
                    then ["\($p).success: \($t.success) but [critical] verdicts say \($expectSuccess) (success is true only when every critical requirement is pass)"]
                    else [] end),
                   (if ($t.accuracy | type) == "number" and (($t.accuracy - $expectAcc) | fabs) > 0.000001
                    then ["\($p).accuracy: \($t.accuracy) but the verdicts compute to \($expectAcc) (pass=1, partial=0.5, fail=0)"]
                    else [] end) ] | flatten
               end)
            end)
          ] | flatten end)
       ] | flatten))
   ] | flatten end)
] | flatten
JQ

fail=0
n_corpus=0
n_run=0

# エラーがあれば表示して 1 を返す。呼び出し側が共有 fail の前後比較に頼らずに
# 済むよう、必ず戻り値で成否を伝える。
report() { # report <file> <errors-json>
  local file="$1" errs="$2" n
  n="$(jq 'length' <<<"$errs")"
  if [ "$n" -eq 0 ]; then return 0; fi
  echo "NG: $file" >&2
  jq -r '.[] | "  - " + .' <<<"$errs" >&2
  fail=1
  return 1
}

check_cases() {
  local file="$1" dir errs bad=0
  # plugins/<plugin>/skills/<skill>/evals/cases.json の <skill>。
  # 正規レイアウト上のファイルでないと <skill> を名乗れないので、そのときだけ
  # 突き合わせる(temp ディレクトリ等から検証したときの偽陽性を出さない)。
  dir=""
  case "$file" in
  */skills/*/evals/cases.json) dir="$(basename "$(dirname "$(dirname "$file")")")" ;;
  esac
  errs="$(jq -c --arg schema "$CASES_SCHEMA" --arg dir "$dir" "$JQ_LIB $JQ_CASES" "$file")"
  report "$file" "$errs" || bad=1
  # surface パターンは ERE。コンパイルできないものはここで落とす(grep は
  # 不正な正規表現で終了コード 2、一致なしなら 1)。
  local re
  while IFS= read -r re; do
    [ -n "$re" ] || continue
    if printf '' | grep -Eq -- "$re" 2>/dev/null; then :; elif [ $? -gt 1 ]; then
      echo "NG: $file" >&2
      echo "  - surface pattern is not a valid ERE: $re" >&2
      fail=1
      bad=1
    fi
  done < <(jq -r '.cases[]?.requirements[]?.surface // empty' "$file")
  n_corpus=$((n_corpus + 1))
  return "$bad"
}

check_run() {
  local file="$1" corpus digest errs corpus_ok
  corpus="$(jq -r '.corpus.path // empty' "$file")"
  if [ -z "$corpus" ] || [ ! -f "$corpus" ]; then
    echo "NG: $file" >&2
    echo "  - \$.corpus.path: \"${corpus:-<missing>}\" does not resolve to a corpus file (results cannot be validated without it)" >&2
    fail=1
    return 0
  fi
  # 参照先 corpus を先に検証する。ここを飛ばすと [critical] が1つも無い corpus を
  # 指すことで success の判定を空虚に真にできる。
  corpus_ok=0
  check_cases "$corpus" || corpus_ok=1
  n_corpus=$((n_corpus - 1)) # run の巻き添えで corpus を二重に数えない
  if [ "$corpus_ok" != 0 ]; then
    echo "  ^ the corpus referenced by $file is invalid; its results are not trustworthy" >&2
    return 0
  fi
  digest="sha256:$(sha256sum "$corpus" | cut -d' ' -f1)"
  errs="$(jq -c --arg schema "$RUN_SCHEMA" --arg digest "$digest" \
    --slurpfile corpus "$corpus" "$JQ_LIB $JQ_RUN" "$file")"
  report "$file" "$errs"
  n_run=$((n_run + 1))
}

check_file() {
  local file="$1" schema
  if ! schema="$(jq -r '.schema // empty' "$file" 2>/dev/null)"; then
    echo "NG: $file" >&2
    echo "  - not valid JSON" >&2
    fail=1
    return 0
  fi
  case "$schema" in
  "$CASES_SCHEMA") check_cases "$file" ;;
  "$RUN_SCHEMA") check_run "$file" ;;
  "")
    echo "NG: $file" >&2
    echo "  - \$.schema is missing (expected \"$CASES_SCHEMA\" or \"$RUN_SCHEMA\")" >&2
    fail=1
    ;;
  *)
    echo "NG: $file" >&2
    echo "  - \$.schema: unknown schema \"$schema\"" >&2
    fail=1
    ;;
  esac
}

if [ "$#" -gt 0 ]; then
  for f in "$@"; do
    if [ ! -f "$f" ]; then
      echo "NG: $f does not exist" >&2
      fail=1
      continue
    fi
    check_file "$f"
  done
else
  # evals/ の中身は cases.json 1枚だけ。綴り違い(case.json)、退避ファイル
  # (cases.json.bak)、symlink、想定外の階層(evals/nested/evals/cases.json)を
  # 黙って未検証にしない。check-licenses.sh / check-plugin-meta.sh と同じく、
  # 期待どおりかを実集合と突き合わせる。
  #
  # シェルの glob は `*` が `/` をまたぐので、パス一致だけでは階層を固定できない。
  # 深さを数えて要素ごとに検査する。区切りは NUL(改行を含む名前で分割されない)。
  scan_root="${EVALS_SCAN_ROOT:-plugins}"

  # evals ディレクトリ自体が正規の深さにあるか(plugins/<p>/skills/<s>/evals)。
  while IFS= read -r -d '' d; do
    rel="${d#"$scan_root"/}"
    case "$rel" in
    */skills/*/evals)
      # rel が <plugin>/skills/<skill>/evals ちょうど4要素であることを確かめる。
      if [ "$(awk -F/ '{print NF}' <<<"$rel")" -ne 4 ]; then
        echo "NG: $d" >&2
        echo "  - evals/ must sit at <plugin>/skills/<skill>/evals, not nested deeper" >&2
        fail=1
      fi
      ;;
    *)
      echo "NG: $d" >&2
      echo "  - evals/ must sit at <plugin>/skills/<skill>/evals" >&2
      fail=1
      ;;
    esac
  done < <(find "$scan_root" -type d -name evals -print0 | sort -z)

  # evals/ 直下は cases.json ちょうど1枚の通常ファイルだけ。
  while IFS= read -r -d '' f; do
    if [ -L "$f" ]; then
      echo "NG: $f" >&2
      echo "  - symlinks are not allowed under evals/; the corpus must be a regular file" >&2
      fail=1
      continue
    fi
    if [ "$(basename "$f")" != "cases.json" ]; then
      echo "NG: $f" >&2
      echo "  - unexpected file under evals/; the corpus must be exactly <skill>/evals/cases.json" >&2
      fail=1
      continue
    fi
    check_file "$f"
  done < <(find "$scan_root" -path '*/evals/*' \( -type f -o -type l \) -print0 | sort -z)
fi

if [ "$fail" = 0 ]; then
  echo "OK: eval corpus ${n_corpus} 件 / 実行結果 ${n_run} 件が schema どおり"
fi
exit "$fail"
