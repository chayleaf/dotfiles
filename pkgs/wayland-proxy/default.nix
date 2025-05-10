{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "wayland-proxy";
  version = "1.2";

  src = fetchFromGitHub {
    owner = "stransky";
    repo = "wayland-proxy";
    rev = version;
    hash = "sha256-GGuAyFTHy+vvC3+BAKJtPAzpevQ6V3B1SVPpa/hnAlE=";
  };

  buildPhase = ''
    runHook preBuild
    cd src
    bash compile
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cp wayland-proxy "$out/bin"
    runHook postInstall
  '';

  meta = {
    description = "Wayland proxy is load balancer between Wayland compositor and Wayland client";
    homepage = "https://github.com/stransky/wayland-proxy";
    license = lib.licenses.mpl20;
    maintainers = with lib.maintainers; [ chayleaf ];
    mainProgram = "wayland-proxy";
    platforms = lib.platforms.all;
  };
}
