#!/usr/bin/env bash
#
# check-plugin-meta.sh — marketplace.json と各 plugin メタデータの整合を検証する。
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

# README の Claude plugin install 例に全 plugin が1回ずつ出ているか。
# marketplace 名も JSON から引き、例の追従漏れや重複を集合比較で検出する。
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
if [ "$mp_names" != "$readme_names" ]; then
  echo "NG: README の Claude plugin install 例が marketplace.json のプラグイン集合と不一致(< marketplace, > README)" >&2
  diff <(printf '%s\n' "$mp_names") <(printf '%s\n' "$readme_names") >&2 || true
  fail=1
fi

# 各プラグインの name / version / keywords 一致。source からディレクトリを引く。
# source の相対パスは marketplace のルート(このリポジトリのルート)基準で解決される。
# Claude Code の schema は "./" 始まりの相対パスしか受け付けない(z.string().startsWith("./"))。
# "./" が無いと一覧表示は通るのに plugin install が
# `This plugin's marketplace entry is invalid: source: Invalid input` で落ちる。
# metadata.pluginRoot は schema にはあるが解決時に使われないので、source に plugins/ を含める。
n="$(jq '.plugins | length' "$mp")"
for i in $(seq 0 $((n - 1))); do
  name="$(jq -r ".plugins[$i].name" "$mp")"
  src="$(jq -r ".plugins[$i].source" "$mp")"
  case "$src" in
  ./*) ;;
  *)
    echo "NG: $name の source は \"./\" 始まりの相対パスである必要がある(source=$src)" >&2
    fail=1
    continue
    ;;
  esac
  pj="$src/.claude-plugin/plugin.json"
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
  echo "OK: marketplace.json、各 plugin.json、README の plugin メタデータは一致"
fi
exit "$fail"
