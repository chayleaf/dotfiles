# [ (import (builtins.fetchTarball "https://github.com/oxalica/rust-overlay/archive/master.tar.gz")) ]
[ (import <self>).overlays.default (import <rust-overlay>) (import <nix-gaming>).overlays.default ]
