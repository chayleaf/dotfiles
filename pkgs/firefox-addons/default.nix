{ pkgs
, lib
, stdenv
, fetchurl
, nur
, sources
, ... }:

let
  buildExtension = { pname, version, src, id, meta ? { } }: pkgs.stdenvNoCC.mkDerivation {
    inherit pname version src meta;
    preferLocalBuild = true;
    allowSubstitutes = true;
    buildCommand = ''
      dst="$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
      mkdir -p "$dst"
      install -v -m644 "$src" "$dst/"'${id}'
    '';
  };
in
(import ./generated.nix {
  inherit lib stdenv fetchurl;
  inherit (nur.repos.rycee.firefox-addons) buildFirefoxXpiAddon;
}) // {
  # addons.mozilla.org's version is horribly outdated for whatever reason
  # I guess the extension normally autoupdates by itself?
  # this is an unsigned build
  yomichan = buildExtension {
    inherit (sources.yomichan) pname version src;
    id = "alex.testing@foosoft.net.xpi";
    meta = with lib; {
      homepage = "https://foosoft.net/projects/yomichan";
      description = "Yomichan turns your browser into a tool for building Japanese language literacy by helping you to decipher texts which would be otherwise too difficult tackle. It features a robust dictionary with EPWING and flashcard creation support";
      license = licenses.gpl3;
      platforms = platforms.all;
    };
  };
  fastforward = buildExtension {
    inherit (sources.fastforward) pname version src;
    id = "addon@fastforward.team";
    meta = with lib; {
      homepage = "https://fastforward.team";
      description = "Don't waste time with compliance. Use FastForward to skip annoying URL \"shorteners\"";
      license = licenses.unlicense;
      platforms = platforms.all;
    };
  };
}
