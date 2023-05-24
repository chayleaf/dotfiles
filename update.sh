#!/usr/bin/env bash
cp ~/.config/nixpkgs/overlays.nix ./overlays.nix || (mkdir -p ~/.config/nixpkgs && cp ./overlays.nix ~/.config/nixpkgs)
nix flake update
nvfetcher \
  -o ./pkgs/_sources \
  -c ./pkgs/nvfetcher.toml || echo "failed to update nvfetcher sources"
mozilla-addons-to-nix \
  ./pkgs/firefox-addons/addons.json \
  ./pkgs/firefox-addons/generated.nix || echo "failed to update firefox addons"
if [ -z ${SUDO_ASKPASS+x} ]; then
  sudo nixos-rebuild switch --flake .
else
  sudo -A nixos-rebuild switch --flake .
fi
home-manager switch --flake .
