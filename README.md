# My Nix config

To install, simply run `nixos-rebuild switch --flake .` and
`home-manager switch --flake .`... just kidding, this config relies on a
bunch of secrets that I'm too lazy to make defaults for (such as initial
root password for impermanence), so you won't be able to run it as-is.

Home-manager config and modules are in `./home`, NixOS config and
modules are in `./system`.
