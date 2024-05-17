{ pkgs, pkgs', ... }:

let
  nixForNixPlugins = pkgs.nixVersions.nix_2_18;
in {
  inherit nixForNixPlugins;
  nix = nixForNixPlugins;
  nixVersions = pkgs.nixVersions // {
    stable = nixForNixPlugins;
    unstable = nixForNixPlugins;
  };
  # Various patches to change Nix version of existing packages so they don't error out because of nix-plugins in nix.conf
  /*nix-plugins = (pkgs.nix-plugins.override { nix = nixForNixPlugins; }).overrideAttrs (old: {
    version = "13.0.0";
    patches = [
      (pkgs.fetchpatch {
        # pull 16
        url = "https://github.com/chayleaf/nix-plugins/commit/8f945cadad7f2e60e8f308b2f498ec5e16961ede.patch";
        hash = "sha256-pOogMtjXYkSDtXW12TmBpGr/plnizJtud2nP3q2UldQ=";
      })
    ];
  });*/
  harmonia = (pkgs.harmonia.override { nixVersions.nix_2_21 = nixForNixPlugins; }).overrideAttrs (old: rec {
    version = "0.7.3";
    src = old.src.override {
      rev = "refs/tags/${old.pname}-v${version}";
      hash = "sha256-XtnK54HvZMKZGSCrVD0FO5PQLMo3Vkj8ezUlsfqStq0=";
    };
    cargoDeps = pkgs'.rustPlatform.importCargoLock { lockFile = "${src}/Cargo.lock"; };
  });
  nix-init = pkgs.nix-init.override { nix = nixForNixPlugins; };
  nix-serve = pkgs.nix-serve.override { nix = nixForNixPlugins; };
  nix-serve-ng = pkgs.nix-serve-ng.override { nix = nixForNixPlugins; };
  hydra_unstable = (pkgs.hydra_unstable.override {
    nix = nixForNixPlugins;
  }).overrideAttrs (old: {
    version = "2023-12-01";
    # who cares about tests amirite
    doCheck = false;
    src = old.src.override {
      rev = "4d1c8505120961f10897b8fe9a070d4e193c9a13";
      hash = "sha256-vXTuE83GL15mgZHegbllVAsVdDFcWWSayPfZxTJN5ys=";
    };
  });
  nurl = pkgs.nurl.override { nix = nixForNixPlugins; };
}
