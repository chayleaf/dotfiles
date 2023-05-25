# My Nix config

Home-manager config and modules are in `./home`, NixOS config and
modules are in `./system`.

Secrets are fetched using a nix plugin at evaluation time to avoid using
`--impure`. I plan to implement a more robust secrets system later
though.

To install, simply run `nixos-rebuild switch --flake . --option
extra-builtins-file $(pwd)/extra-builtins.nix` and
`home-manager switch --flake . --option extra-builtins-file
$(pwd)/extra-builtins.nix`, since this repo relies on build-time
decryption of secrets using a Nix plugin (to be fair you won't be able
to use it since you don't have the secrets, such as initial root
password). If you don't have `nix-plugins` though, you can put the
secrets in plaintext to `/etc/nixos/private` and add `--impure` flag to
bootstrap the config.

