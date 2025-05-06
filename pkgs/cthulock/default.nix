{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  pkg-config,
  libxkbcommon,
  pam,
  udev,
  wayland,
  libGL,
  fontconfig,
  withPatches ? false,
}:

rustPlatform.buildRustPackage rec {
  pname = "cthulock";
  version = "unstable-2024-09-06";

  src =
    if withPatches then
      fetchFromGitHub {
        owner = "chayleaf";
        repo = "cthulock";
        rev = "8e8bf6f439f76b190244ee94a849078d286faa47";
        hash = "sha256-b33m+OZ5GunYf94SYLk5DDwF6HWgcA0jVXosTKmmYDk=";
      }
    else
      fetchFromGitHub {
        owner = "FriederHannenheim";
        repo = "cthulock";
        rev = "07e0b1a19866d64a8793ee1dc2713975e126da30";
        hash = "sha256-pLg4tZMdh+Ap3z06iGj4gFfViz1PKyK/wjCFmataYrY=";
      };

  cargoLock.lockFile = "${src}/Cargo.lock";
  doCheck = !withPatches;

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
    makeWrapper
  ];

  buildInputs = [
    libxkbcommon
    pam
    udev
    wayland
    libGL
  ];

  postInstall = ''
    wrapProgram $out/bin/cthulock \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ fontconfig ]}"
  '';

  meta = {
    description = "Wayland screen locker focused on customizability";
    homepage = "https://github.com/FriederHannenheim/cthulock";
    changelog = "https://github.com/FriederHannenheim/cthulock/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ chayleaf ];
    mainProgram = "cthulock";
  };
}
