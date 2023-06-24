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
in

{
  osu-lazer-bin = nix-gaming.osu-lazer-bin;
  clang-tools_latest = pkgs.clang-tools_16;
  clang_latest = pkgs.clang_16;
  home-daemon = callPackage ./home-daemon { };
  /*ghidra = pkgs.ghidra.overrideAttrs (old: {
    patches = old.patches ++ [ ./ghidra-stdcall.patch ];
  });*/
  lalrpop = callPackage ./lalrpop { };
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
  maubot = callPackage ./maubot.nix { };
  pineapplebot = callPackage ./pineapplebot.nix { };
  proton-ge = pkgs.stdenvNoCC.mkDerivation {
    inherit (sources.proton-ge) pname version src;
    installPhase = ''
      mkdir -p $out
      tar -C $out --strip=1 -x -f $src
    '';
  };
  rofi-steam-game-list = callPackage ./rofi-steam-game-list { };
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

  hostapd = (pkgs.hostapd.override { stdenv = pkgs'.ccacheStdenv; }).overrideAttrs (old: {
    # also remove 80211N
    extraConfig = old.extraConfig + ''
      CONFIG_OCV=y
      CONFIG_WPS=y
      CONFIG_WPS_NFC=y
      CONFIG_WNM=y
      CONFIG_IEEE80211AX=y
      CONFIG_IEEE80211BE=y
      CONFIG_ELOOP_EPOLL=y
      CONFIG_MBO=y
      CONFIG_TAXONOMY=y
      CONFIG_OWE=y
      CONFIG_AIRTIME_POLICY=y
    '';
  });
} // (import ../system/hardware/bpi-r3/pkgs.nix { inherit pkgs pkgs' lib sources; })
