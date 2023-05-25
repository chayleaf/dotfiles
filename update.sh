#!/usr/bin/env bash
cp ~/.config/nixpkgs/overlays.nix ./overlays.nix || (mkdir -p ~/.config/nixpkgs && cp ./overlays.nix ~/.config/nixpkgs)
nvfetcher \
  -o ./pkgs/_sources \
  -c ./pkgs/nvfetcher.toml || echo "failed to update nvfetcher sources"
mozilla-addons-to-nix \
  ./pkgs/firefox-addons/addons.json \
  ./pkgs/firefox-addons/generated.nix || echo "failed to update firefox addons"
nix flake update
if [ -z ${SUDO_ASKPASS+x} ]; then
  sudo nixos-rebuild switch --flake . --option extra-builtins-file "$(pwd)/extra-builtins.nix"
else
  sudo -A nixos-rebuild switch --flake . --option extra-builtins-file "$(pwd)/extra-builtins.nix"
fi
home-manager switch --flake . --option extra-builtins-file "$(pwd)/extra-builtins.nix"
