{ pkgs, ... }:

let
  # TODO: remove after full update
  unpatchedNixForNixPlugins = if pkgs?nixVersions.nix_2_25 then pkgs.nixVersions.nix_2_24 else pkgs.nixVersions.nix_2_18;
  nixForNixPlugins = unpatchedNixForNixPlugins.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./rename-nix-plugin-files.patch ];
    # some tests fail on bcachefs due to insufficient permissions
    doInstallCheck = false;
  });
  patchedNixVersions = builtins.mapAttrs (k: v: nixForNixPlugins) pkgs.nixVersions;
in {
  inherit unpatchedNixForNixPlugins nixForNixPlugins;
  # Various patches to change Nix version of existing packages so they don't error out because of nix-plugins in nix.conf
  nix-plugins = (pkgs.nix-plugins.override { nixVersions = patchedNixVersions; })
  .overrideAttrs (old: {
    # version = "13.0.0";
    patches = [
      /*(pkgs.fetchpatch {
        # pull 16
        url = "https://github.com/chayleaf/nix-plugins/commit/8f945cadad7f2e60e8f308b2f498ec5e16961ede.patch";
        hash = "sha256-pOogMtjXYkSDtXW12TmBpGr/plnizJtud2nP3q2UldQ=";
      })*/
      ./nix-plugins-fix.patch
    ];
  });
  nix-eval-jobs = (pkgs.nix-eval-jobs.override {
    nix = nixForNixPlugins;
  }).overrideAttrs (old:{
    doCheck = false;
    src = old.src.override {
      rev = "889ea1406736b53cf165b6c28398aae3969418d1";
      hash = "sha256-3wwtKpS5tUBdjaGeSia7CotonbiRB6K5Kp0dsUt3nzU=";
    };
  });
  hydra = (pkgs.hydra.override {
    nix = nixForNixPlugins;
  }).overrideAttrs (old: {
    # version = "2023-12-01";
    # who cares about tests amirite
    doCheck = false;
    src = old.src.override {
      rev = "9ad8ac586c76ef78401a2e0279ad2be28a557505";
      hash = "sha256-3RffcSar9FrKggwHW4WZ1NdQ3vRzFG0grWaQkG3czdc=";
    };
  });
}
