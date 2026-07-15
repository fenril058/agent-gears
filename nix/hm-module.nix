# home-manager module: agent-gears の skill / 常時ルール / agent定義を
# Claude Code・Codex・GitHub Copilot へ symlink 配布する。install.sh の宣言的な代替。
#
# flakeSrc はこの flake のソース(store)で、配布対象の「名前」の列挙にだけ使う。
# 実体の symlink 先は cfg.mutable に従って切り替える:
#   mutable = true  (既定): cfg.repoPath(作業ツリー)への out-of-store symlink。
#                            既存 skill の編集は再ビルド不要で即反映。
#   mutable = false        : flake のソース(store)を直接指す。完全に宣言的だが、
#                            編集の反映には home-manager switch が要る。
{ flakeSrc }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.agent-gears;
  inherit (lib)
    mkOption mkEnableOption mkIf types optionalAttrs listToAttrs
    filterAttrs attrNames concatMap;

  dirNames = path: attrNames (filterAttrs (_: t: t == "directory") (builtins.readDir path));
  regNames = path: attrNames (filterAttrs (_: t: t == "regular") (builtins.readDir path));
  exists = sub: builtins.pathExists (flakeSrc + "/${sub}");

  # plugins/<plugin>/skills/<name> と meta/<name> を skill として、
  # plugins/<plugin>/agents/<file> を agent 定義として列挙する。
  # 各エントリは { name(配布先のベース名); sub(repo 内サブパス) }。
  pluginNames = if exists "plugins" then dirNames (flakeSrc + "/plugins") else [ ];
  metaNames = if exists "meta" then dirNames (flakeSrc + "/meta") else [ ];

  pluginSkillEntries = concatMap
    (p:
      let sub = "plugins/${p}/skills"; in
      if exists sub then map (s: { name = s; inherit sub; full = "${sub}/${s}"; }) (dirNames (flakeSrc + "/${sub}"))
      else [ ])
    pluginNames;
  metaSkillEntries = map (m: { name = m; full = "meta/${m}"; }) metaNames;
  skillEntries = pluginSkillEntries ++ metaSkillEntries;

  agentEntries = concatMap
    (p:
      let sub = "plugins/${p}/agents"; in
      if exists sub then map (f: { name = f; full = "${sub}/${f}"; }) (regNames (flakeSrc + "/${sub}"))
      else [ ])
    pluginNames;

  outLink = config.lib.file.mkOutOfStoreSymlink;
  # サブパス sub の配布元(mutable なら作業ツリー、そうでなければ store)
  srcOf = sub:
    if cfg.mutable then outLink "${cfg.repoPath}/${sub}"
    else flakeSrc + "/${sub}";

  mkSkillLinks = base: listToAttrs (map
    (e: { name = "${base}/${e.name}"; value.source = srcOf e.full; })
    skillEntries);

  mkAgentLinks = listToAttrs (map
    (e: { name = ".claude/agents/${e.name}"; value.source = srcOf e.full; })
    agentEntries);

  # mdidx バイナリ。skill 用ツールを PATH に通すため home.packages へ入れる。
  # 編集即反映が要る skill と違いこれは純粋な store ビルドでよいので、cfg.mutable に
  # かかわらず常に flake ソース(store)からビルドする。ビルドは Nix が prebuilt の Go
  # コンパイラを store に取得して行うため、システムへ go を入れる必要はない。
  mdidx = import (flakeSrc + "/nix/mdidx.nix") {
    inherit pkgs;
    src = flakeSrc + "/cmd/mdidx";
  };
in
{
  options.programs.agent-gears = {
    enable = mkEnableOption
      "agent-gears の skill/ルール/agent定義を各エージェントへ配布する";

    repoPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/home/ril/ghq/github.com/fenril058/agent-gears";
      description = ''
        作業ツリー(可変)への絶対パス。mutable = true のとき必須。
        skill 本体はここへの out-of-store symlink になり、既存 skill の編集は
        home-manager の再ビルドなしで即反映される(skill の追加・削除の反映には
        home-manager switch が必要)。
      '';
    };

    mutable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        true: 作業ツリー(repoPath)への out-of-store symlink。編集が即反映。
        false: flake のソース(store)を直接配布。完全に宣言的だが編集反映に switch が要る。
      '';
    };

    claude.enable = mkOption { type = types.bool; default = true; description = "~/.claude へ配布"; };
    codex.enable = mkOption { type = types.bool; default = true; description = "~/.agents/skills と ~/.codex/AGENTS.md へ Codex 向けファイルを配布"; };
    copilot.enable = mkOption { type = types.bool; default = true; description = "~/.copilot へ配布(GitHub Copilot)"; };
    rules.enable = mkOption { type = types.bool; default = true; description = "共通ルールとエージェント固有ルールを対応する instruction file として配布"; };
    agentDefs.enable = mkOption { type = types.bool; default = true; description = "agents/*.md を ~/.claude/agents へ配布(Claude Code 固有)"; };
    tools.enable = mkOption { type = types.bool; default = true; description = "mdidx バイナリを home.packages に入れて PATH へ通す(markdown-context skill 用)"; };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = !cfg.mutable || cfg.repoPath != null;
      message = "programs.agent-gears.repoPath は mutable = true のとき必須です。";
    }];

    home.packages = lib.optionals cfg.tools.enable [ mdidx ];

    home.file =
      (optionalAttrs cfg.claude.enable (mkSkillLinks ".claude/skills"))
      // (optionalAttrs cfg.copilot.enable (mkSkillLinks ".copilot/skills"))
      // (optionalAttrs cfg.codex.enable (mkSkillLinks ".agents/skills"))
      // (optionalAttrs (cfg.agentDefs.enable && cfg.claude.enable) mkAgentLinks)
      // (optionalAttrs (cfg.rules.enable && cfg.claude.enable) {
        ".claude/CLAUDE.md".source = srcOf "rules/always-on.md";
        ".claude/rules/agent-gears.md".source = srcOf "rules/claude.md";
      })
      // (optionalAttrs (cfg.rules.enable && cfg.codex.enable) {
        ".codex/AGENTS.md".source = srcOf "rules/always-on.md";
      })
      // (optionalAttrs (cfg.rules.enable && cfg.copilot.enable) {
        ".copilot/copilot-instructions.md".source = srcOf "rules/always-on.md";
      });
  };
}
