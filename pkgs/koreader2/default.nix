{
  lib,
  stdenv,
  makeWrapper,
  dpkg,
  glib,
  gnutar,
  sdcv,
  SDL2,
  openssl,
  autoPatchelfHook,
  koreader
}:
stdenv.mkDerivation rec {

  inherit (koreader) pname version src src_repo;

  nativeBuildInputs = [
    makeWrapper
    dpkg
    autoPatchelfHook
  ];
  buildInputs = [
    glib
    gnutar
    sdcv
    SDL2
    openssl
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out
    dpkg-deb -x $src .
    cp -R usr/* $out/

    # Link required binaries
    ln -sf ${sdcv}/bin/sdcv $out/lib/koreader/sdcv
    ln -sf ${gnutar}/bin/tar $out/lib/koreader/tar

    # Link SSL/network libraries
    ln -sf ${openssl.out}/lib/libcrypto.so.3 $out/lib/koreader/libs/libcrypto.so.1.1
    ln -sf ${openssl.out}/lib/libssl.so.3 $out/lib/koreader/libs/libssl.so.1.1

    # Copy fonts
    find ${src_repo}/resources/fonts -type d -execdir cp -r '{}' $out/lib/koreader/fonts \;

    # Remove broken symlinks
    find $out -xtype l -print -delete

    HOST_PATH="$out/lib/koreader" patchShebangs --host "$out/lib/koreader/reader.lua"
    wrapProgram $out/bin/koreader --prefix LD_LIBRARY_PATH : $out/lib/koreader/libs:${
      lib.makeLibraryPath [
        SDL2
      ]
    }
  '';

  inherit (koreader) meta;
}
