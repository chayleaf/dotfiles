{ lib
, stdenv
, fetchFromGitHub
, meson
, ninja
, pkg-config
, scdoc
, cairo
, gdk-pixbuf
, libsodium
, libxkbcommon
, wayland
, wayland-protocols
}:

stdenv.mkDerivation {
  pname = "schlock";
  version = "unstable-2022-02-02";

  src = fetchFromGitHub {
    owner = "telent";
    repo = "schlock";
    rev = "f3dde16f074fd5b7482a253b9d26b4ead66dea82";
    hash = "sha256-Ot86vALt1kkzbBocwh9drCycbRIw2jMKJU4ODe9PYQM=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    scdoc
    wayland
  ];

  buildInputs = [
    cairo
    gdk-pixbuf
    libsodium
    libxkbcommon
    wayland-protocols
    wayland
  ];

  mesonFlags = [
    "-Dgdk-pixbuf=enabled"
    "-Dman-pages=enabled"
  ];

  meta = with lib; {
    description = "";
    homepage = "https://github.com/telent/schlock";
    license = licenses.mit;
    maintainers = with maintainers; [ chayleaf ];
    mainProgram = "schlock";
    platforms = platforms.all;
  };
}
