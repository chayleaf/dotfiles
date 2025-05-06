{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  scdoc,
  wayland-scanner,
  wayland,
  wayland-protocols,
  libxkbcommon,
  cairo,
  gdk-pixbuf,
  pam,
}:

stdenv.mkDerivation {
  pname = "sxmo-swaylock";
  version = "unstable-2023-04-27";

  src = fetchFromGitHub {
    owner = "KaffeinatedKat";
    repo = "sxmo_swaylock";
    rev = "63619c857d9fb5f8976f0380c6670123a4028211";
    hash = "sha256-vs0VHO1QBstwLXyLJ/6SSypQmh2DyFJZd40+73JsIaQ=";
  };

  patches = [ ./fix.patch ];

  strictDeps = true;
  depsBuildBuild = [ pkg-config ];
  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    scdoc
    wayland-scanner
  ];
  buildInputs = [
    wayland
    wayland-protocols
    libxkbcommon
    cairo
    gdk-pixbuf
    pam
  ];

  mesonFlags = [
    "-Dpam=enabled"
    "-Dgdk-pixbuf=enabled"
    "-Dman-pages=enabled"
  ];

  meta = with lib; {
    description = "sxmo lockscreen with swaylock";
    homepage = "https://github.com/KaffeinatedKat/sxmo_swaylock";
    license = licenses.mit;
    maintainers = with maintainers; [ chayleaf ];
    mainProgram = "swaylock";
    platforms = platforms.all;
  };
}
