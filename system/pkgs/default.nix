{ pkgs
, lib
, ... }:

let
  inherit (pkgs) callPackage;
in {
  system76-scheduler = callPackage ./system76-scheduler.nix { };
  maubot = callPackage ./maubot.nix { };
  pineapplebot = callPackage ./pineapplebot.nix { };
  inherit lib;
}
/*
// (lib.optionalAttrs (pkgs.system == "...") {
  fdroidserver = pkgs.fdroidserver.overridePythonAttrs (oldAttrs: {
    # remove apksigner, since official Android SDK is unavailable on arm64
    makeWrapperArgs = [ ];
  });
})
*/
