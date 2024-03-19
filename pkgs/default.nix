{ pkgs
, lib
, inputs
, pkgs' ? pkgs
, isOverlay ? true
, ...
}:

let
  inherit (pkgs') callPackage;
  sources = import ./_sources/generated.nix {
    inherit (pkgs) fetchgit fetchurl fetchFromGitHub dockerTools;
  };
  nixForNixPlugins = pkgs.nixVersions.nix_2_18;
  nur = import inputs.nur {
    inherit pkgs;
    nurpkgs = pkgs;
  };
in

{
  inherit (inputs.nix-gaming.packages.${pkgs.system}) faf-client osu-lazer-bin;
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
    cargoDeps = pkgs.rustPlatform.importCargoLock { lockFile = "${src}/Cargo.lock"; };
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

  buffyboard = pkgs.callPackage ./buffyboard { };
  clang-tools_latest = pkgs.clang-tools_16;
  clang_latest = pkgs.clang_16;
  /*ghidra = pkgs.ghidra.overrideAttrs (old: {
    patches = old.patches ++ [ ./ghidra-stdcall.patch ];
  });*/
  gimp = callPackage ./gimp { inherit (pkgs) gimp; };
  home-daemon = callPackage ./home-daemon { };
  # pin version
  looking-glass-client = pkgs.looking-glass-client.overrideAttrs (old: {
    version = "B6";
    src = pkgs.fetchFromGitHub {
      owner = "gnif";
      repo = "LookingGlass";
      rev = "B6";
      sha256 = "sha256-6vYbNmNJBCoU23nVculac24tHqH7F4AZVftIjL93WJU=";
      fetchSubmodules = true;
    };
  });
  kvmfrOverlay = kvmfr: kvmfr.overrideAttrs (old: {
    inherit (pkgs'.looking-glass-client) version src;
  });
  mobile-config-firefox = callPackage ./mobile-config-firefox { };
  ping-exporter = callPackage ./ping-exporter { };
  proton-ge = pkgs.stdenvNoCC.mkDerivation {
    inherit (sources.proton-ge) pname version src;
    installPhase = ''
      mkdir -p $out
      tar -C $out --strip=1 -x -f $src
    '';
  };
  rofi-steam-game-list = callPackage ./rofi-steam-game-list { };
  scanservjs = callPackage ./scanservjs { };
  searxng = pkgs'.python3.pkgs.toPythonModule (pkgs.searxng.overrideAttrs (old: {
    inherit (sources.searxng) src;
    version = "unstable-" + sources.searxng.date;
    postInstall = builtins.replaceStrings [ "/botdetection" ] [ "" ] old.postInstall;
  }));
  schlock = callPackage ./schlock { };
  techmino = callPackage ./techmino { };

  firefoxAddons = lib.recurseIntoAttrs (callPackage ./firefox-addons { inherit nur sources; });
  mpvScripts = lib.optionalAttrs isOverlay pkgs.mpvScripts // callPackage ./mpv-scripts { };

  qemu_7 = callPackage ./qemu/7.nix {
    stdenv = pkgs'.ccacheStdenv;
    inherit (pkgs.darwin.apple_sdk.frameworks) CoreServices Cocoa Hypervisor vmnet;
    inherit (pkgs.darwin.stubs) rez setfile;
    inherit (pkgs.darwin) sigtool;
  };
  qemu_7_kvm = lib.lowPrio (pkgs'.qemu_7.override { hostCpuOnly = true; });
  qemu_7_full = lib.lowPrio (pkgs'.qemu_7.override { smbdSupport = true; cephSupport = true; glusterfsSupport = true; });
  qemu_7_xen = lib.lowPrio (pkgs'.qemu_7.override { hostCpuOnly = true; xenSupport = true; xen = pkgs.xen-slim; });
  qemu_7_xen-light = lib.lowPrio (pkgs'.qemu_7.override { hostCpuOnly = true; xenSupport = true; xen = pkgs.xen-light; });
  qemu_7_xen_4_15 = lib.lowPrio (pkgs'.qemu_7.override { hostCpuOnly = true; xenSupport = true; xen = pkgs.xen_4_15-slim; });
  qemu_7_xen_4_15-light = lib.lowPrio (pkgs'.qemu_7.override { hostCpuOnly = true; xenSupport = true; xen = pkgs.xen_4_15-light; });
  qemu_7_test = lib.lowPrio (pkgs'.qemu_7.override { hostCpuOnly = true; nixosTestRunner = true; });
  # TODO: when https://gitlab.com/virtio-fs/virtiofsd/-/issues/96 is fixed remove this
  virtiofsd = callPackage ./qemu/virtiofsd.nix {
    qemu = pkgs'.qemu_7;
  };

  qemu_7_ccache = pkgs'.qemu_7.override {
    stdenv = pkgs'.ccacheStdenv;
  };
  virtiofsd_ccache = pkgs'.virtiofsd.override {
    qemu = pkgs'.qemu_7_ccache;
    stdenv = pkgs'.ccacheStdenv;
  };
}
// import ./ccache.nix { inherit pkgs pkgs' lib sources; }
// import ../system/hardware/bpi-r3/pkgs.nix { inherit pkgs pkgs' lib sources; }
// import ../system/hardware/oneplus-enchilada/pkgs.nix { inherit inputs pkgs pkgs' lib sources; }
