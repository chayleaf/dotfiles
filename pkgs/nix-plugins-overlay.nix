{ pkgs, ... }:

let
  unpatchedNixForNixPlugins = pkgs.nixVersions.nix_2_24;
  nixForNixPlugins = unpatchedNixForNixPlugins.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./rename-nix-plugin-files.patch ];
    # some tests fail on bcachefs due to insufficient permissions
    doInstallCheck = false;
  });
in {
  inherit unpatchedNixForNixPlugins nixForNixPlugins;
  # Various patches to change Nix version of existing packages so they don't error out because of nix-plugins in nix.conf
  nix-plugins = (pkgs.nix-plugins.override { nix = nixForNixPlugins; })
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
  hydra = (pkgs.hydra.override {
    nix = nixForNixPlugins;
  }).overrideAttrs (old: {
    # version = "2023-12-01";
    # who cares about tests amirite
    doCheck = false;
    # src = old.src.override {
    #   rev = "4d1c8505120961f10897b8fe9a070d4e193c9a13";
    #   hash = "sha256-vXTuE83GL15mgZHegbllVAsVdDFcWWSayPfZxTJN5ys=";
    # };
  });
}
