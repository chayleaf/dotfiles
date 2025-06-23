{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  libinput,
  libxkbcommon,
  libevdev,
}:

stdenv.mkDerivation {
  pname = "buffyboard";
  version = "unstable-2023-11-20";

  src = fetchFromGitLab {
    owner = "postmarketOS";
    repo = "buffybox";
    rev = "14b30c60183d98e8d0b4dadf66198e08badf631e";
    hash = "sha256-9wLuTAqYoFl+IAR1ixp0nHwh6jBWl+1jDPhhxqE+LHQ=";
    fetchSubmodules = true;
  };

  # https://gitlab.com/postmarketOS/buffybox/-/issues/1
  hardeningDisable = [ "fortify3" ];

  postPatch = ''
    cd buffyboard
  '';

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    libevdev
    libinput
    libxkbcommon
  ];

  meta = with lib; {
    description = "";
    homepage = "https://gitlab.com/postmarketOS/buffybox/-/tree/master/buffyboard";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ chayleaf ];
    mainProgram = "buffyboard";
    platforms = platforms.all;
  };
}
