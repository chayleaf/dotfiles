{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "rofi-steam-game-list";
  version = "0.1";

  src = ../rofi-steam-game-list;

  cargoLock.lockFile = ../rofi-steam-game-list/Cargo.lock;

  meta = with lib; {
    description = "A program to list Steam games for Rofi";
    license = licenses.bsd0;
  };
}
