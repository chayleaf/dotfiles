{ pkgs
, pkgs'
, ... }:

let
  inherit (pkgs') callPackage;

  extraPackages = {
    tsja = callPackage ./tsja.nix { };
  };
  gen' = postgresql: builtins.mapAttrs (k: v: v.override { inherit postgresql; }) extraPackages;
  gen = ver: pkgs."postgresql${toString ver}Packages" // gen' pkgs."postgresql_${toString ver}";
in {
  mecab = pkgs.mecab.overrideAttrs (old: {
    postInstall = ''
      mkdir -p $out/lib/mecab/dic
      ln -s ${callPackage /${pkgs.path}/pkgs/tools/text/mecab/ipadic.nix {
        mecab-nodic = callPackage /${pkgs.path}/pkgs/tools/text/mecab/nodic.nix { };
      }} $out/lib/mecab/dic/ipadic
    '';
  });
  postgresqlPackages = gen "";
  postgresql11Packages = gen 11;
  postgresql12Packages = gen 12;
  postgresql13Packages = gen 13;
  postgresql14Packages = gen 14;
  postgresql15Packages = gen 15;
  postgresql16Packages = gen 16;
}
