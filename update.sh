#!/usr/bin/env bash
rm -rf ./home ./system
cp -r /etc/nixos ./system
cp -r ~/.config/nixpkgs ./home

