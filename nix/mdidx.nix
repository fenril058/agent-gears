# mdidx パッケージ定義(flake.nix の packages と hm-module.nix の home.packages で共用)。
# 外部依存ゼロの Go 実装なので vendorHash は null。ビルドは Nix が prebuilt の Go
# コンパイラを store に取得して行う(システムへ go を入れる必要はない)。
{ pkgs, src }:
pkgs.buildGoModule {
  pname = "mdidx";
  version = "0.1.0";
  inherit src;
  vendorHash = null;
}
