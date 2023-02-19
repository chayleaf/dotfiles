{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "home-daemon";
  version = "0.1";

  src = ../home-daemon;

  cargoLock.lockFile = ../home-daemon/Cargo.lock;

  meta = with lib; {
    description = "My custom home daemon";
    license = licenses.bsd0;
  };
}
