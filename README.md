# My Nix config

To install, simply run `nixos-rebuild switch --flake .` and
`home-manager switch --flake .`.

The reason I don't use the NixOS home-manager module is is because I
want to be able to iterate home config quickly, and `nixos-rebuild`'ing
the entire system for every little change is pretty annoying (not to
mention the necessity of `sudo`). I'll probably merge them later,
especially after [Tvix](https://tvl.fyi/blog/rewriting-nix) becomes
feature-complete.

