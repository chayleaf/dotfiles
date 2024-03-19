{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:

pkgs.mkShell rec {
  name = "shell-rust";
  nativeBuildInputs = with pkgs; [ pkg-config rustc cargo ];
  buildInputs = with pkgs; [ alsa-lib ];
  LD_LIBRARY_PATH = "${lib.makeLibraryPath buildInputs}";
}
