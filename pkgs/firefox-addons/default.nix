{
  lib,
  stdenv,
  fetchurl,
  nur,
  # , pkgs
  ...
}:

# let
#   buildExtension = { pname, version, src, id, meta ? { } }: pkgs.stdenvNoCC.mkDerivation {
#     inherit pname version src meta;
#     preferLocalBuild = true;
#     allowSubstitutes = true;
#     buildCommand = ''
#       dst="$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
#       mkdir -p "$dst"
#       install -v -m644 "$src" "$dst/"'${id}'
#     '';
#   };
#   <ext> = buildExtension {
#     inherit (sources.<ext>) pname version src;
#     id = "<addon id>";
#     meta = with lib; { platforms = platforms.all; };
#   };
# in

import ./generated.nix {
  inherit lib stdenv fetchurl;
  inherit (nur.repos.rycee.firefox-addons) buildFirefoxXpiAddon;
}
