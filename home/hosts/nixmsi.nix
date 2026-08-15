{
  pkgs,
  lib,
  inputs,
  config,
  ...
}:

{
  imports = [
    ../modules/general.nix
    ../modules/firefox.nix
    ../modules/i3-sway.nix
    ../modules/nvim.nix
    ../modules/helix.nix
    ../modules/emacs.nix
    # ../modules/kakoune.nix
    inputs.nur.modules.homeManager.default
  ];

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "steam-run"
      "steam"
      "steam-original"
      "steam-runtime"
      "steam-unwrapped"
      "steamcmd"
      "osu-lazer-bin"
    ];

  home.stateVersion = "22.11";
  home.username = "user";
  home.homeDirectory = "/home/user";
  terminals = [ "kitty" ];
  # xsession.windowManager.i3.enable = true;
  wayland.windowManager.sway.enable = true;
  services.kdeconnect.enable = true;
  home.sessionVariables = {
    # TODO
    # STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${pkgs.proton-ge}";
    CARGO_PROFILE_DEV_INCREMENTAL = "true";
    # RUSTC_LINKER = "${pkgs.llvmPackages_latest.clang}/bin/clang";
    # RUSTFLAGS = "-C link-arg=--ld-path=${pkgs.mold}/bin/mold";
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "${pkgs.llvmPackages_latest.clang}/bin/clang";
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS = "-C link-arg=--ld-path=${pkgs.mold}/bin/mold";
  };
  home.packages = with pkgs; [
    pavucontrol
    wayland-proxy
    firefox-devedition
    anki-bin
    #(gimp.overrideAttrs (old: { doCheck = false; }))
    gimp3
    krita
    xournalpp
    blender
    kdePackages.kdenlive
    glaxnimate
    mediainfo
    ghidra
    (cutter.withPlugins (
      p: with p; [
        sigdb
        rz-ghidra
      ]
    ))
    openrgb
    piper
    steam-run
    steam
    # faf-client
    #(osu-lazer-bin.override {
    #command_prefix = "env SDL_VIDEODRIVER=wayland ${obs-studio-plugins.obs-vkcapture}/bin/obs-gamecapture";
    #})
    # taisei
    techmino
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        wlrobs
        obs-vkcapture
      ];
    })
    easyeffects
    # wineWowPackages.waylandFull
    winetricks
    # protontricks # proton-caller
    # bottles
    virt-manager
    looking-glass-client
    llvmPackages_latest.clang
    mold
    rustc
    rustfmt
    cargo
    clippy
    lalrpop
    tio
    telegram-desktop
    #osu-wine
    dotnet-sdk_9
    # nodejs
    #npm
    yarn
    (ghc.withPackages (p: with p; [cabal-install]))
    maple-mono.opentype
    maple-mono.CN
    # opam
    pkg-config
  ];
  xdg.configFile."looking-glass/client.ini".text = ''
    [app]
    shmFile=/dev/kvmfr0

    [input]
    rawMouse=yes
    escapeKey=KEY_RIGHTALT
  '';
  programs.mpv.config.hwdec = lib.mkForce "vdpau";
  programs.librewolf.profiles.chayleaf.settings = builtins.mapAttrs (k: lib.mkForce) {
    "font.name.serif.x-western" = "Maple Mono";
    "font.name.sans-serif.x-western" = "Maple Mono";
    "font.name.monospace.x-western" = "Maple Mono";
    "font.name.monospace.ja" = "Maple Mono CN";
    "font.name.monospace.ko" = "Maple Mono CN";
    "font.name.monospace.zh-CN" = "Maple Mono CN";
    "font.name.monospace.zh-HK" = "Maple Mono CN";
    "font.name.monospace.zh-TW" = "Maple Mono CN";
    "font.name.serif.ja" = "Maple Mono CN";
    "font.name.serif.ko" = "Maple Mono CN";
    "font.name.serif.zh-CN" = "Maple Mono CN";
    "font.name.serif.zh-HK" = "Maple Mono CN";
    "font.name.serif.zh-TW" = "Maple Mono CN";
    "font.name.sans-serif.ja" = "Maple Mono CN";
    "font.name.sans-serif.ko" = "Maple Mono CN";
    "font.name.sans-serif.zh-CN" = "Maple Mono CN";
    "font.name.sans-serif.zh-HK" = "Maple Mono CN";
    "font.name.sans-serif.zh-TW" = "Maple Mono CN";
    "browser.display.use_document_fonts" = 0;
  };
  programs.librewolf.profiles.cn = {
    id = 1;
    inherit (config.programs.librewolf.profiles.chayleaf) extensions settings;
  };
  programs.librewolf.profiles.de = {
    id = 2;
    inherit (config.programs.librewolf.profiles.chayleaf) extensions settings;
  };
}
