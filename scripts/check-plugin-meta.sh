#!/usr/bin/env bash
#
# check-plugin-meta.sh — marketplace.json と各 plugin.json の整合を検証する。
#
# plugin の name / version / keywords は marketplace.json と plugin.json に重複する。
# 片方だけ更新するとずれるので一致を必須にする(特に version bump で漏れやすい)。
# description は意図的に粒度が違う(marketplace=詳細 / plugin.json=短縮)ので対象外、手動。
#
# 必要: jq。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
mp=".claude-plugin/marketplace.json"
fail=0

# プラグインの集合: marketplace の name と plugins/*/.claude-plugin/plugin.json の name。
mp_names="$(jq -r '.plugins[].name' "$mp" | sort)"
fs_names="$(for f in plugins/*/.claude-plugin/plugin.json; do jq -r '.name' "$f"; done | sort)"
if [ "$mp_names" != "$fs_names" ]; then
  echo "NG: marketplace.json のプラグイン集合が plugins/ と不一致(< marketplace, > plugins/)" >&2
  diff <(printf '%s\n' "$mp_names") <(printf '%s\n' "$fs_names") >&2 || true
  fail=1
fi

# 各プラグインの name / version / keywords 一致。source からディレクトリを引く。
n="$(jq '.plugins | length' "$mp")"
for i in $(seq 0 $((n - 1))); do
  name="$(jq -r ".plugins[$i].name" "$mp")"
  src="$(jq -r ".plugins[$i].source" "$mp")"
  pj="plugins/$src/.claude-plugin/plugin.json"
  if [ ! -f "$pj" ]; then
    echo "NG: $pj が無い(marketplace source=$src)" >&2
    fail=1
    continue
  fi
  for field in name version; do
    a="$(jq -r ".plugins[$i].$field" "$mp")"
    b="$(jq -r ".$field" "$pj")"
    if [ "$a" != "$b" ]; then
      echo "NG: $name の $field 不一致: marketplace=$a plugin.json=$b" >&2
      fail=1
    fi
  done
  ka="$(jq -c ".plugins[$i].keywords | sort" "$mp")"
  kb="$(jq -c '.keywords | sort' "$pj")"
  if [ "$ka" != "$kb" ]; then
    echo "NG: $name の keywords 不一致: marketplace=$ka plugin.json=$kb" >&2
    fail=1
  fi
done

if [ "$fail" = 0 ]; then
  echo "OK: marketplace.json と各 plugin.json の name/version/keywords は一致"
fi
exit "$fail"
