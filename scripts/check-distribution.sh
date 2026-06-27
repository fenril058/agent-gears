#!/usr/bin/env bash
#
# check-distribution.sh — 2系統の配布(install.sh と nix/hm-module.nix)が
# 同じ配布先集合を生成することを検証する。
#
# install.sh(命令的)と hm-module.nix(宣言的)は skill/agent をディレクトリ構成
# から自動列挙するので名前自体はずれない。ずれうるのは配布先(~/.claude 等)や
# レイアウト規約で、片方だけ変えると食い違う。ここでその食い違いを検出する。
#
# 必要: nix(ambient)/ jq。CI では `nix shell nixpkgs#jq --command` 経由で実行する。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

# install.sh 側: dry-run の link/ok 行から配布先を取り、HOME 相対に正規化する。
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
inst="$(CLAUDE_HOME="$tmp/.claude" CODEX_HOME="$tmp/.codex" AGENTS_HOME="$tmp/.agents" \
  bash install.sh --dry-run \
  | grep -E '^[[:space:]]+(link|ok)[[:space:]]' \
  | awk '{print $2}' \
  | sed "s#^$tmp/##" \
  | sort)"

# hm-module 側: home-manager 本体なしで評価し home.file の配布先名を取る。
# 配布先の名前だけが要るので、編集即反映(out-of-store symlink)・mdidx ビルドは
# 評価しなくてよい(mutable = false, tools.enable = false)。
hm="$(nix eval --impure --json --expr "
  let
    pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
    flakeSrc = $REPO;
    agModule = import (flakeSrc + \"/nix/hm-module.nix\") { inherit flakeSrc; };
    # home-manager が普段提供する options/lib をこのテスト用に最小限だけ用意する。
    stub = { lib, ... }: {
      options.home.file = lib.mkOption { type = lib.types.attrsOf lib.types.attrs; default = {}; };
      options.home.packages = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = []; };
      options.lib.file.mkOutOfStoreSymlink = lib.mkOption { type = lib.types.unspecified; default = (p: p); };
      options.assertions = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = []; };
      config.lib.file.mkOutOfStoreSymlink = (p: p);
    };
    eval = lib.evalModules {
      modules = [
        agModule
        stub
        { programs.agent-gears = { enable = true; mutable = false; tools.enable = false; }; }
      ];
      specialArgs = { pkgs = {}; };
    };
  in builtins.attrNames eval.config.home.file
" | jq -r '.[]' | sort)"

if diff <(printf '%s\n' "$hm") <(printf '%s\n' "$inst"); then
  echo "OK: install.sh と hm-module.nix の配布先は一致($(printf '%s\n' "$hm" | grep -c .) 件)"
else
  echo "NG: install.sh と hm-module.nix の配布先がずれています(< hm-module, > install.sh)" >&2
  exit 1
fi
