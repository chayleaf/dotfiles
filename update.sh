#!/usr/bin/env bash
rm -rf ./home ./system
cp -r /etc/nixos ./system
cp -r ~/.config/home-manager ./home
cp ~/.config/nixpkgs/overlays.nix ./overlays.nix

