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
  home.stateVersion = "22.11";
  home.username = "user";
  home.homeDirectory = "/home/user";
  termShell = {
    enable = true;
    path = "${pkgs.fish}/bin/fish";
  };
  xsession.windowManager.i3.enable = true;
  wayland.windowManager.sway.enable = true;
  terminals = ["kitty" "urxvt"];
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
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam-run"
    "steam"
    "steam-original"
    "steam-runtime"
    "steamcmd"
    "osu-lazer-bin"
  ];
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
    ((osu-lazer-bin.override {
      gmrun_enable = false;
    }).overrideAttrs (old: {
      paths = assert builtins.length old.paths == 2;
      let
        osu = builtins.head old.paths;
        osu' = osu.overrideAttrs (old: {
          installPhase = builtins.replaceStrings
            ["runHook postInstall"]
            ["sed -i 's:exec :exec ${obs-studio-plugins.obs-vkcapture}/bin/obs-gamecapture :g' $out/bin/osu-lazer\nrunHook postInstall"]
            old.installPhase;
        });
      in assert osu.pname == "osu-lazer-bin"; [
        osu'
        (makeDesktopItem {
          name = osu'.pname;
          exec = "${osu'.outPath}/bin/osu-lazer";
          icon = "${osu'.outPath}/osu.png";
          comment = "A free-to-win rhythm game. Rhythm is just a *click* away!";
          desktopName = "osu!";
          categories = ["Game"];
        })
      ];
    }))
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
    gimp krita blender
    tdesktop
    clang_latest rustc rustfmt cargo clippy
    kdenlive
    mediainfo
    glaxnimate
    lalrpop
    looking-glass-client
  ];
  xdg.configFile."looking-glass/client.ini".text = ''
    [app]
    shmFile=/dev/kvmfr0

    [input]
    rawMouse=yes
    escapeKey=KEY_INSERT
  '';
}
