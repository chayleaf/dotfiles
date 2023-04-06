{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "shell-rust";
  buildInputs = [
    pkgs.rustc pkgs.cargo
  ];
}
