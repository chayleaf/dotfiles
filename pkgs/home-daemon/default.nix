{
  lib,
  rustPlatform,
  nix-gitignore,
  pkg-config,
  alsa-lib,
}:

rustPlatform.buildRustPackage {
  pname = "home-daemon";
  version = "0.2.0";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ alsa-lib ];

  src = nix-gitignore.gitignoreSource [ "/target" "default.nix" ] ./.;

  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "My custom home daemon";
    license = licenses.bsd0;
  };
}
