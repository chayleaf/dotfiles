{ pkgs, ... }: {
  lalrpop = pkgs.callPackage ./lalrpop { };
  home-daemon = pkgs.callPackage ./home-daemon { };
  rofi-steam-game-list = pkgs.callPackage ./rofi-steam-game-list { };
  clang_latest = pkgs.clang_15;
  clang-tools_latest = pkgs.clang-tools_15;
}
