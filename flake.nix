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

      # mdidx: markdown-context skill が使う Markdown→索引変換ツール。
      # upstream md2idx(MIT, Node)の忠実な Go 再実装で、Node ランタイム/npm 依存を
      # 持たない単一静的バイナリ。出力は md2idx とバイト互換。
      packages = forAll (system:
        let pkgs = pkgsFor system; in {
          mdidx = import ./nix/mdidx.nix { inherit pkgs; src = ./cmd/mdidx; };
          default = self.packages.${system}.mdidx;
        });

      # skill が使う周辺ツール(mdidx は同梱の Go バイナリ、jq は mdidx の出力処理に必須)。
      # mq / fastcontext は nixpkgs 外のため別途導入する。
      devShells = forAll (system:
        let pkgs = pkgsFor system; in {
          default = pkgs.mkShell {
            packages = [ pkgs.jq pkgs.git self.packages.${system}.mdidx ];
          };
        });

      formatter = forAll (system: (pkgsFor system).nixpkgs-fmt);
    };
}
