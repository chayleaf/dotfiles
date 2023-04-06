{ lib, rustPlatform, nix-gitignore }:
rustPlatform.buildRustPackage {
  pname = "home-daemon";
  version = "0.1";

  src = nix-gitignore.gitignoreSource ["/target" "default.nix"] (lib.cleanSource ./.);

  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "My custom home daemon";
    license = licenses.bsd0;
  };
}
