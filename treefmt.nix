# treefmt 設定: nix fmt / nix flake check を通す唯一のフォーマッタ定義。
# 対象は .nix(nixpkgs-fmt)/ .go(gofmt)/ .sh(shfmt)。
# shfmt のインデントは .editorconfig(space/2)に従う。switch_case_indent は
# treefmt 経由では効かず、残すと直接 shfmt と食い違うため .editorconfig に置かない。
# Markdown は CLAUDE.md の「一文一行」規約と衝突するため対象外(手動整形)。
{
  projectRootFile = "flake.nix";
  programs.nixpkgs-fmt.enable = true;
  programs.gofmt.enable = true;
  programs.shfmt.enable = true; # インデント設定は .editorconfig 由来
}
