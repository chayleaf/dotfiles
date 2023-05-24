{ pkgs
, lib
, nur
, nix-gaming
, ... }:
let
  inherit (pkgs) callPackage;
  sources = import ./_sources/generated.nix {
    inherit (pkgs) fetchgit fetchurl fetchFromGitHub dockerTools;
  };
in

{
  osu-lazer-bin = nix-gaming.osu-lazer-bin;
  clang-tools_latest = pkgs.clang-tools_15;
  clang_latest = pkgs.clang_15;
  home-daemon = callPackage ./home-daemon { };
  /*ghidra = pkgs.ghidra.overrideAttrs (old: {
    patches = old.patches ++ [ ./ghidra-stdcall.patch ];
  });*/
  lalrpop = callPackage ./lalrpop { };
  # pin version
  looking-glass-client = pkgs.looking-glass-client.overrideAttrs (old: {
    version = "B6";
    src = pkgs.fetchFromGitHub {
      owner = "gnif";
      repo = "LookingGlass";
      rev = "B6";
      sha256 = "sha256-6vYbNmNJBCoU23nVculac24tHqH7F4AZVftIjL93WJU=";
      fetchSubmodules = true;
    };
  });
  maubot = callPackage ./maubot.nix { };
  pineapplebot = callPackage ./pineapplebot.nix { };
  proton-ge = pkgs.stdenvNoCC.mkDerivation {
    inherit (sources.proton-ge) pname version src;
    installPhase = ''
      mkdir -p $out
      tar -C $out --strip=1 -x -f $src
    '';
  };
  rofi-steam-game-list = callPackage ./rofi-steam-game-list { };
  techmino = callPackage ./techmino { };

  firefox-addons = lib.recurseIntoAttrs (callPackage ./firefox-addons { inherit nur sources; });
  mpvScripts = pkgs.mpvScripts // (callPackage ./mpv-scripts { });
}
