{
  description = "agent-gears: token削減・効率agent運用の skill/agent を Claude Code / Codex / GitHub Copilot へ配布する";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, treefmt-nix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      # treefmt: nix fmt / checks.formatting の唯一のフォーマッタ定義(./treefmt.nix)。
      treefmtEval = forAll (system: treefmt-nix.lib.evalModule (pkgsFor system) ./treefmt.nix);
    in
    {
      # home-manager モジュール: imports に足して programs.agent-gears.enable = true。
      homeManagerModules.agent-gears = import ./nix/hm-module.nix { flakeSrc = self; };
      homeManagerModules.default = self.homeManagerModules.agent-gears;

      # mdidx: markdown-context skill が使う Markdown→索引変換ツール。
      # upstream md2idx(MIT, Node)の忠実な Go 再実装で、Node ランタイム/npm 依存を
      # 持たない単一静的バイナリ。出力は md2idx とバイト互換。
      packages = forAll (system:
        let pkgs = pkgsFor system; in {
          mdidx = import ./nix/mdidx.nix { inherit pkgs; src = ./cmd/mdidx; };
          # 公式 agentskills.io バリデータ。scripts/check-skill-spec.sh が使う。
          skills-ref = pkgs.callPackage ./nix/skills-ref.nix { };
          default = self.packages.${system}.mdidx;
        });

      # skill が使う周辺ツール(mdidx は同梱の Go バイナリ、jq は mdidx の出力処理に必須)。
      # mq / fastcontext は nixpkgs 外のため別途導入する。
      # mdidx など Go ツールの開発用に Go ツールチェーン(go / gopls / gotools)も入れる。
      devShells = forAll (system:
        let pkgs = pkgsFor system; in {
          default = pkgs.mkShell {
            packages = [
              pkgs.jq
              pkgs.git
              self.packages.${system}.mdidx
              # scripts/check-skill-spec.sh が使う公式 agentskills.io バリデータ。
              self.packages.${system}.skills-ref
              pkgs.go
              pkgs.gopls
              pkgs.gotools
              # treefmt が使う shell フォーマッタ(直接 shfmt を叩く用)。
              pkgs.shfmt
            ];
          };
        });

      # nix fmt = treefmt(nixpkgs-fmt + gofmt を一括実行)。
      formatter = forAll (system: treefmtEval.${system}.config.build.wrapper);

      # nix flake check が整形も検査する(未整形なら fail)。個別の CI ステップは不要。
      checks = forAll (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });
    };
}
