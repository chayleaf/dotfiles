{ pkgs
, lib
, nur
, nix-gaming
, pkgs' ? pkgs
, ... }:
let
  inherit (pkgs) callPackage;
  sources = import ./_sources/generated.nix {
    inherit (pkgs) fetchgit fetchurl fetchFromGitHub dockerTools;
  };
  nixForNixPlugins = pkgs.nixVersions.nix_2_15;
in

{
  inherit (nix-gaming) faf-client osu-lazer-bin;
  inherit nixForNixPlugins;
  nix-plugins = pkgs.nix-plugins.overrideAttrs (old: {
    src = old.src.override {
      rev = "8b9d06ef5b1b4f53cc99fcfde72bae75c7a7aa9c";
      hash = "sha256-7Lo+YxpiRz0+ZLFDvYMJWWK2j0CyPDRoP1wAc+OaPJY=";
    };
  });
  nix = nixForNixPlugins;
  nixVersions = pkgs.nixVersions.extend (self: super: {
    stable = nixForNixPlugins;
    unstable = nixForNixPlugins;
  });
  /* Various patches to change Nix version of existing packages so they don't error out because of nix-plugins in nix.conf
  hydra_unstable = pkgs.hydra_unstable.override { nix = nixForNixPlugins; };
  harmonia = pkgs.harmonia.override { nix = nixForNixPlugins; };
  nix-init = pkgs.nix-init.override { nix = nixForNixPlugins; };
  nix-serve = pkgs.nix-serve.override { nix = nixForNixPlugins; };
  nix-serve-ng = pkgs.nix-serve-ng.override { nix = nixForNixPlugins; };
  nurl = pkgs.nurl.override { nixVersions = builtins.mapAttrs (k: v: nixForNixPlugins) pkgs.nixVersions; };
  */

  clang-tools_latest = pkgs.clang-tools_16;
  clang_latest = pkgs.clang_16;
  /*ghidra = pkgs.ghidra.overrideAttrs (old: {
    patches = old.patches ++ [ ./ghidra-stdcall.patch ];
  });*/
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
  pineapplebot = callPackage ./pineapplebot.nix { };
  proton-ge = pkgs.stdenvNoCC.mkDerivation {
    inherit (sources.proton-ge) pname version src;
    installPhase = ''
      mkdir -p $out
      tar -C $out --strip=1 -x -f $src
    '';
  };
  rofi-steam-game-list = callPackage ./rofi-steam-game-list { };
  searxng = pkgs'.python3.pkgs.toPythonModule (pkgs.searxng.overrideAttrs (old: {
    inherit (sources.searxng) src;
    version = "unstable-" + sources.searxng.date;
  }));
  # system76-scheduler = callPackage ./system76-scheduler.nix { };
  techmino = callPackage ./techmino { };

  firefox-addons = lib.recurseIntoAttrs (callPackage ./firefox-addons { inherit nur sources; });
  mpvScripts = pkgs.mpvScripts // (callPackage ./mpv-scripts { });

  qemu_7 = callPackage ./qemu_7.nix {
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
  virtiofsd = callPackage ./qemu_virtiofsd.nix {
    qemu = pkgs'.qemu_7;
    stdenv = pkgs'.ccacheStdenv;
  };

  cutter2 = pkgs.callPackage ./rizin/wrapper.nix {
    unwrapped = pkgs.cutter;
  } [ (pkgs.libsForQt5.callPackage ./rizin/rz-ghidra.nix {
    enableCutterPlugin = true;
  }) ];
} // (import ../system/hardware/bpi-r3/pkgs.nix { inherit pkgs pkgs' lib sources; })
