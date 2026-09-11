#!/usr/bin/env bash
# check-plugin-meta.sh — marketplace.json と単一 plugin のメタデータを検証する。
# plugin の name / version / keywords は marketplace.json と plugin.json に重複する。
# 片方だけ更新するとずれるので一致を必須にする。
# description は意図的に粒度が違う(marketplace=詳細 / plugin.json=短縮)ので対象外、手動。
# 必要: jq。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
mp=".claude-plugin/marketplace.json"
fail=0
mp_count="$(jq '.plugins | length' "$mp")"
if [ "$mp_count" -ne 1 ]; then
  echo "NG: marketplace.json の plugin は1件である必要がある(実際: $mp_count 件)" >&2
  exit 1
fi
fs_files="$(find plugins -type f -path '*/.claude-plugin/plugin.json' | sort)"
fs_count="$(printf '%s\n' "$fs_files" | awk 'NF { n++ } END { print n + 0 }')"
if [ "$fs_count" -ne 1 ]; then
  echo "NG: plugins/ 以下の plugin.json は1枚である必要がある(実際: $fs_count 枚)" >&2
  exit 1
fi
name="$(jq -r '.plugins[0].name' "$mp")"
src="$(jq -r '.plugins[0].source' "$mp")"
case "$src" in
./*) ;;
*)
  echo "NG: $name の source は \"./\" 始まりの相対パスである必要がある(source=$src)" >&2
  fail=1
  ;;
esac

# source は marketplace のルート(このリポジトリのルート)基準で解決される。
# Claude Code は "./" 始まりの相対パスしか受け付けない。
# metadata.pluginRoot は schema にはあるが解決時に使われないため、source に plugins/ を含める。
pj="${src#./}/.claude-plugin/plugin.json"
if [ "$pj" != "$fs_files" ]; then
  echo "NG: marketplace source と plugin.json の配置が不一致: marketplace=$pj, plugins=$fs_files" >&2
  fail=1
elif [ ! -f "$pj" ]; then
  echo "NG: $pj が無い(marketplace source=$src)" >&2
  fail=1
else
  for field in name version; do
    a="$(jq -r ".plugins[0].$field" "$mp")"
    b="$(jq -r ".$field" "$pj")"
    if [ "$a" != "$b" ]; then
      echo "NG: $name の $field 不一致: marketplace=$a plugin.json=$b" >&2
      fail=1
    fi
  done

  ka="$(jq -c '.plugins[0].keywords | sort' "$mp")"
  kb="$(jq -c '.keywords | sort' "$pj")"
  if [ "$ka" != "$kb" ]; then
    echo "NG: $name の keywords 不一致: marketplace=$ka plugin.json=$kb" >&2
    fail=1
  fi
fi

# README の Claude plugin install 例にも唯一の plugin が1回だけ出ているか。
marketplace_name="$(jq -r '.name' "$mp")"
readme_names="$(
  awk -v marketplace="$marketplace_name" '
    $1 == "/plugin" && $2 == "install" && NF == 3 {
      suffix = "@" marketplace
      if (length($3) > length(suffix) && substr($3, length($3) - length(suffix) + 1) == suffix) {
        print substr($3, 1, length($3) - length(suffix))
      }
    }
  ' README.md | sort
)"
if [ "$name" != "$readme_names" ]; then
  echo "NG: README の Claude plugin install 例が marketplace.json と不一致(< marketplace, > README)" >&2
  diff <(printf '%s\n' "$name") <(printf '%s\n' "$readme_names") >&2 || true
  fail=1
fi

if [ "$fail" = 0 ]; then
  echo "OK: marketplace.json、plugin.json、README の単一 plugin メタデータは一致"
fi
exit "$fail"
