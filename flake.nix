{
  description = "agent-gears: token削減・効率agent運用の skill/agent を Claude Code / Codex / 共有ストアへ配布する";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      # home-manager モジュール: imports に足して programs.agent-gears.enable = true。
      homeManagerModules.agent-gears = import ./nix/hm-module.nix { flakeSrc = self; };
      homeManagerModules.default = self.homeManagerModules.agent-gears;

      # skill が使う周辺ツール(md2idx は npx 経由、jq は md2idx の出力処理に必須)。
      # mq / fastcontext は nixpkgs 外のため別途導入する。
      devShells = forAll (system:
        let pkgs = pkgsFor system; in {
          default = pkgs.mkShell {
            packages = [ pkgs.jq pkgs.nodejs pkgs.git ];
          };
        });

      formatter = forAll (system: (pkgsFor system).nixpkgs-fmt);
    };
}
