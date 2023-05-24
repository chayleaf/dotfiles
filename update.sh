#!/usr/bin/env bash
cp ~/.config/nixpkgs/overlays.nix ./overlays.nix || echo "probably no overlays exist"
nix flake update
nvfetcher \
  -o ./home/_sources \
  -c ./home/nvfetcher.toml || echo "failed to update nvfetcher sources"
mozilla-addons-to-nix \
  ./home/pkgs/firefox-addons/addons.json \
  ./home/pkgs/firefox-addons/generated.nix || echo "failed to update firefox addons"
s nixos-rebuild switch --flake . || sudo nixos-rebuild switch --flake .
home-manager switch --flake .
