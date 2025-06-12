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
  nur = import inputs.nur {
    inherit pkgs;
    nurpkgs = pkgs;
  };
in

{
  inherit (inputs.nix-gaming.packages.${pkgs.system}) faf-client osu-lazer-bin;
  inherit (inputs.osu-wine.packages.${pkgs.system}) osu-wine;
  matrix-appservice-discord = pkgs.callPackage ./matrix-appservice-discord { inherit (pkgs) matrix-appservice-discord; };

  krita = pkgs.callPackage ./krita { inherit (pkgs) krita; };

  inherit (inputs.unbound-rust-mod.packages.${pkgs.system}) unbound-mod;
  unbound-full = pkgs.unbound-full.overrideAttrs (old: {
    configureFlags = old.configureFlags ++ [ "--with-dynlibmodule" ];
  });

  buffyboard = pkgs.callPackage ./buffyboard { };
  clang-tools_latest = pkgs.clang-tools_16;
  clang_latest = pkgs.clang_16;
  /*ghidra = pkgs.ghidra.overrideAttrs (old: {
    patches = old.patches ++ [ ./ghidra-stdcall.patch ];
  });*/
  gimp = callPackage ./gimp { inherit (pkgs) gimp; };
  home-daemon = callPackage ./home-daemon { };
  # pin version
  /*looking-glass-client = pkgs.looking-glass-client.overrideAttrs (old: rec {
    version = "B6";
    postUnpack = ''
      echo ${src.rev} > source/VERSION
      export sourceRoot="source/client"
    '';
    src = pkgs.fetchFromGitHub {
      owner = "gnif";
      repo = "LookingGlass";
      rev = "B6";
      sha256 = "sha256-6vYbNmNJBCoU23nVculac24tHqH7F4AZVftIjL93WJU=";
      fetchSubmodules = true;
    };
    patches = [ ];
  });
  kvmfrOverlay = kvmfr: (kvmfr.override { inherit (pkgs') looking-glass-client; }).overrideAttrs (old: {
    patches = [ ./looking-glass.patch ];
  });*/
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
  # scanservjs = callPackage ./scanservjs { };
  searxng = pkgs'.python3.pkgs.toPythonModule (pkgs.searxng.overrideAttrs (old: {
    inherit (sources.searxng) src;
    version = "unstable-" + sources.searxng.date;
    postInstall = builtins.replaceStrings [ "/botdetection" ] [ "" ] old.postInstall;
  }));
  cthulock = callPackage ./cthulock { };
  schlock = callPackage ./schlock { };
  sxmo-swaylock = callPackage ./sxmo-swaylock { };
  swaylock-mobile = callPackage ./swaylock-mobile { };
  techmino = callPackage ./techmino { };
  wayland-proxy = callPackage ./wayland-proxy { };

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
  ccachePkgs = import ./ccache.nix { inherit pkgs pkgs' lib sources; };

  # hardware stuff
  hw.bpi-r3 = import ../system/hardware/bpi-r3/pkgs.nix { inherit pkgs pkgs' lib sources; };
  hw.oneplus-enchilada = import ../system/hardware/oneplus-enchilada/pkgs.nix { inherit inputs pkgs pkgs' lib sources; };
  hw.kobo-clara = import ../system/hardware/kobo-clara/pkgs.nix { inherit pkgs pkgs' lib sources; }; 
  # wlroots = throw "a";
  # sway-unwrapped = throw "a";
}
