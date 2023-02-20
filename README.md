# My Nix config

To install, put `system` to `/etc/nixos`, put `home` to
`~/.config/nixpkgs`.

The reason they are separate is because I want to be able to iterate
home config quickly, and `nixos-rebuild`'ing the entire sytem for every
little change is pretty annoying (not to mention the necessity of
`sudo`). I'll probably merge them later, especially after
[Tvix](https://tvl.fyi/blog/rewriting-nix) becomes feature-complete.

