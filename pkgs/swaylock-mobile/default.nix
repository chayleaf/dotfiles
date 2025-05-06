{
  lib,
  stdenv,
  fetchFromGitea,
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
  pname = "swaylock-mobile";
  version = "unstable-2022-05-01";

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "slatian";
    repo = "swaylock-mobile";
    rev = "aa5387b822f77390afe0ca7fc8c6c2fe48b0f61c";
    hash = "sha256-4lEKkpqEVvbreZg2xxCtfUJlBZpM8ScvdDBKEY3ObDo=";
  };

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
