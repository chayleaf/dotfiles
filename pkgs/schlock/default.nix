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
, wayland-scanner
, wayland-protocols
}:

stdenv.mkDerivation {
  pname = "schlock";
  version = "unstable-2022-02-02";

  src = fetchFromGitHub {
    owner = "chayleaf";
    repo = "schlock";
    rev = "2413a7c2e2d222c9b83729885374fa4b2c6fe891";
    hash = "sha256-F4SMVV5DMmx/y6PwqKAk8cwTIOB4pUJ77/SxZREEFB4=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    scdoc
    wayland-scanner
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
