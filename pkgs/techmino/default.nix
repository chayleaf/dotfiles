{
  lib,
  stdenv,
  fetchurl,
  callPackage,
  makeWrapper,
  makeDesktopItem,
  love,
  luajit,
}:

let
  pname = "techmino";
  description = "A Tetris clone with many features";

  desktopItem = makeDesktopItem {
    name = pname;
    exec = "techmino";
    icon = fetchurl {
      url = "https://user-images.githubusercontent.com/9590981/230777581-ecd7e03e-8fbd-496a-977e-ad293d7d4f18.png";
      sha256 = "sha256-c0Tk5BOGbXahbtvrknZWNblfi1l8LVFRxd5SiKnD6go=";
    };
    comment = description;
    desktopName = "Techmino";
    genericName = "Tetris Clone";
    categories = [ "Game" ];
  };

  libcoldclear = callPackage ./libcoldclear.nix { };
  ccloader = callPackage ./ccloader.nix { inherit libcoldclear luajit; };
in

stdenv.mkDerivation rec {
  inherit pname;
  version = "0.17.12";

  src = fetchurl {
    url = "https://github.com/26F-Studio/Techmino/releases/download/v${version}/Techmino_Bare.love";
    sha256 = "sha256-gQr3VUjkW1byzQP9yWKWNTLmG343zy521FEbnlW+Cnk=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    love
    ccloader
  ];

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/share/games/lovegames
    cp $src $out/share/games/lovegames/techmino.love

    mkdir -p $out/bin
    makeWrapper ${love}/bin/love $out/bin/techmino \
      --add-flags $out/share/games/lovegames/techmino.love \
      --suffix LUA_CPATH : ${ccloader}/lib/lua/${luajit.luaversion}/CCLoader.so

    mkdir -p $out/share/applications
    ln -s ${desktopItem}/share/applications/* $out/share/applications/
  '';

  meta = with lib; {
    inherit description;
    downloadPage = "https://github.com/26F-Studio/Techmino/releases";
    homepage = "https://github.com/26F-Studio/Techmino/";
    license = licenses.lgpl3;
    maintainers = with maintainers; [ chayleaf ];
  };
}
