# home-manager module: context-engineering の skill / 常時ルール / agent定義を
# Claude Code・Codex・共有ストアへ symlink 配布する。install.sh の宣言的な代替。
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
  cfg = config.programs.context-engineering;
  inherit (lib)
    mkOption mkEnableOption mkIf types optionalAttrs listToAttrs
    filterAttrs attrNames elem;

  dirNames = path: attrNames (filterAttrs (_: t: t == "directory") (builtins.readDir path));
  regNames = path: attrNames (filterAttrs (_: t: t == "regular") (builtins.readDir path));
  exists = sub: builtins.pathExists (flakeSrc + "/${sub}");

  skillNames = dirNames (flakeSrc + "/skills");
  metaNames = if exists "meta" then dirNames (flakeSrc + "/meta") else [ ];
  allSkillNames = skillNames ++ metaNames;
  agentFiles = if exists "agents" then regNames (flakeSrc + "/agents") else [ ];

  outLink = config.lib.file.mkOutOfStoreSymlink;
  # サブパス sub の配布元(mutable なら作業ツリー、そうでなければ store)
  srcOf = sub:
    if cfg.mutable then outLink "${cfg.repoPath}/${sub}"
    else flakeSrc + "/${sub}";

  skillSub = name: if elem name metaNames then "meta/${name}" else "skills/${name}";

  mkSkillLinks = base: listToAttrs (map
    (name: { name = "${base}/${name}"; value.source = srcOf (skillSub name); })
    allSkillNames);

  mkAgentLinks = listToAttrs (map
    (f: { name = ".claude/agents/${f}"; value.source = srcOf "agents/${f}"; })
    agentFiles);
in
{
  options.programs.context-engineering = {
    enable = mkEnableOption
      "context-engineering の skill/ルール/agent定義を各エージェントへ配布する";

    repoPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/home/ril/ghq/github.com/fenril058/context-engineering";
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
    codex.enable = mkOption { type = types.bool; default = true; description = "~/.codex へ配布"; };
    sharedStore.enable = mkOption { type = types.bool; default = true; description = "~/.agents/skills へ配布"; };
    rules.enable = mkOption { type = types.bool; default = true; description = "AGENTS.md を CLAUDE.md / AGENTS.md として配布"; };
    agentDefs.enable = mkOption { type = types.bool; default = true; description = "agents/*.md を ~/.claude/agents へ配布(Claude Code 固有)"; };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = !cfg.mutable || cfg.repoPath != null;
      message = "programs.context-engineering.repoPath は mutable = true のとき必須です。";
    }];

    home.file =
      (optionalAttrs cfg.claude.enable (mkSkillLinks ".claude/skills"))
      // (optionalAttrs cfg.codex.enable (mkSkillLinks ".codex/skills"))
      // (optionalAttrs cfg.sharedStore.enable (mkSkillLinks ".agents/skills"))
      // (optionalAttrs (cfg.agentDefs.enable && cfg.claude.enable) mkAgentLinks)
      // (optionalAttrs (cfg.rules.enable && cfg.claude.enable) {
        ".claude/CLAUDE.md".source = srcOf "AGENTS.md";
      })
      // (optionalAttrs (cfg.rules.enable && cfg.codex.enable) {
        ".codex/AGENTS.md".source = srcOf "AGENTS.md";
      });
  };
}
