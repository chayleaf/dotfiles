{ pkgs, ... }: let inherit (pkgs) callPackage; in {
  clang-tools_latest = pkgs.clang-tools_15;
  clang_latest = pkgs.clang_15;
  home-daemon = callPackage ./home-daemon { };
  lalrpop = callPackage ./lalrpop { };
  rofi-steam-game-list = callPackage ./rofi-steam-game-list { };
  techmino = callPackage ./techmino { };
}
