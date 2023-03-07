{ lib, rustPlatform, nix-gitignore }:
rustPlatform.buildRustPackage {
  pname = "rofi-steam-game-list";
  version = "0.1";

  src = nix-gitignore.gitignoreSource ["/target" "default.nix"] (lib.cleanSource ./.);

  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "A program to list Steam games for Rofi";
    license = licenses.bsd0;
  };
}
