{ pkgs, lib, ... }:
{
  imports = [
    ../common/general.nix
    ../common/firefox.nix
    ../common/i3-sway.nix
    ../common/nvim.nix
    ../common/helix.nix
    ../common/kakoune.nix
  ];

  nix.settings = {
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      # "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    ];
    trusted-substituters = [
      "https://cache.nixos.org"
      # "https://nixpkgs-wayland.cachix.org"
    ];
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam-run"
    "steam"
    "steam-original"
    "steam-runtime"
    "steamcmd"
    "osu-lazer-bin"
  ];

  home.stateVersion = "22.11";
  home.username = "user";
  home.homeDirectory = "/home/user";
  termShell = {
    enable = true;
    path = "${pkgs.fish}/bin/fish";
  };
  # xsession.windowManager.i3.enable = true;
  wayland.windowManager.sway.enable = true;
  terminals = [ "kitty" "urxvt" ];
  services.mpd = {
    enable = true;
    network.startWhenNeeded = true;
  };
  services.mpdris2 = {
    enable = true;
  };
  programs.ncmpcpp = {
    enable = true;
  };
  services.kdeconnect.enable = true;
  home.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${pkgs.proton-ge}";
    CARGO_PROFILE_DEV_INCREMENTAL = "true";
    RUSTC_LINKER = "${pkgs.clang_latest}/bin/clang";
    RUSTFLAGS = "-C link-arg=--ld-path=${pkgs.mold}/bin/mold";
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "${pkgs.clang_latest}/bin/clang";
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS = "-C link-arg=--ld-path=${pkgs.mold}/bin/mold";
  };
  home.packages = with pkgs; [
    mold
    ghidra cutter
    openrgb piper
    steam-run steam
    (osu-lazer-bin.override {
      command_prefix = "${obs-studio-plugins.obs-vkcapture}/bin/obs-gamecapture";
    })
    taisei
    techmino
    (wrapOBS {
      plugins = with obs-studio-plugins; [ wlrobs obs-vkcapture ];
    })
    easyeffects
    # wineWowPackages.waylandFull
    winetricks
    protontricks # proton-caller
    # bottles
    virtmanager
    gimp krita blender-hip
    tdesktop
    clang_latest rustc rustfmt cargo clippy
    kdenlive
    mediainfo
    glaxnimate
    lalrpop
    looking-glass-client
    tio
  ];
  xdg.configFile."looking-glass/client.ini".text = ''
    [app]
    shmFile=/dev/kvmfr0

    [input]
    rawMouse=yes
    escapeKey=KEY_INSERT
  '';
}
