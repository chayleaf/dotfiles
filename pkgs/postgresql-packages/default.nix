{ pkgs
, pkgs'
, ... }:

let
  inherit (pkgs') callPackage;

  extraPackages = {
    tsja = callPackage ./tsja.nix { };
  };
  gen' = postgresql: builtins.mapAttrs (k: v: v.override { inherit postgresql; }) extraPackages;
  gen = ver: pkgs."postgresql${toString ver}Packages" // gen' pkgs."postgresql${if ver == "" then "" else "_" + toString ver}";
  psql = ver: let
    old = pkgs."postgresql${if ver == "" then "" else "_" + toString ver}";
  in old // { pkgs = old.pkgs // gen' old; };
  self = {
    mecab = pkgs.mecab.overrideAttrs (old: {
      postInstall = ''
        mkdir -p $out/lib/mecab/dic
        ln -s ${callPackage /${pkgs.path}/pkgs/tools/text/mecab/ipadic.nix {
          mecab-nodic = callPackage /${pkgs.path}/pkgs/tools/text/mecab/nodic.nix { };
        }} $out/lib/mecab/dic/ipadic
      '';
    });
    postgresqlPackages = gen "";
    postgresql = psql "";
    postgresql11Packages = gen 11;
    postgresql_11 = psql 11;
    postgresql12Packages = gen 12;
    postgresql_12 = psql 12;
    postgresql13Packages = gen 13;
    postgresql_13 = psql 13;
    postgresql14Packages = gen 14;
    postgresql_14 = psql 14;
    postgresql15Packages = gen 15;
    postgresql_15 = psql 15;
    postgresql16Packages = gen 16;
    postgresql_16 = psql 16;
  };
in self
