{ lib
, replaceVars
, nix-gitignore 
, rustPlatform
, xdg-utils
, ... }:

rustPlatform.buildRustPackage {
  pname = "rofi-steam-game-list";
  version = "0.1";

  src = nix-gitignore.gitignoreSource ["/target" "default.nix"] (lib.cleanSource ./.);

  patches = [
    (replaceVars ./hardcode_xdg_open.patch {
      xdg_open = "${xdg-utils}/bin/xdg-open";
    })
  ];

  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "A program to list Steam games for Rofi";
    license = licenses.bsd0;
  };
}
