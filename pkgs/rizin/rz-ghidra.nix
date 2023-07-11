{ lib
, stdenv
, fetchFromGitHub
, cmake
# buildInputs
, rizin
, openssl
, pugixml
# optional buildInputs
, enableCutterPlugin ? true
, cutter
, qtbase
, qtsvg
}:

stdenv.mkDerivation rec {
  pname = "rz-ghidra";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "rizinorg";
    repo = "rz-ghidra";
    rev = "v${version}";
    hash = "sha256-2QQEj4TIBmiZgbb66R7q6iEp2WitUc8Ui6Nr71JelXs=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [
    openssl
    pugixml
    rizin
  ] ++ lib.optionals enableCutterPlugin [
    cutter
    qtbase
    qtsvg
  ];

  dontWrapQtApps = true;

  cmakeFlags = [
    "-DUSE_SYSTEM_PUGIXML=ON"
  ] ++ lib.optionals enableCutterPlugin [
    "-DBUILD_CUTTER_PLUGIN=ON"
    "-DCUTTER_INSTALL_PLUGDIR=share/rizin/cutter/plugins/native"
  ];

  meta = with lib; {
    description = "Deep ghidra decompiler and sleigh disassembler integration for rizin";
    homepage = src.meta.homepage;
    license = licenses.lgpl3;
    maintainers = with maintainers; [ chayleaf ];
  };
}
