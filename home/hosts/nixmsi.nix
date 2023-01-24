{ config, pkgs, lib, ... }:
{
  imports = [
    ../common/general.nix
    ../common/firefox.nix
    ../common/i3-sway.nix
    ../common/vim.nix
    ../common/helix.nix
    ../common/kakoune.nix
  ];
  home.stateVersion = "22.11";
  home.username = "user";
  home.homeDirectory = "/home/user";
  xsession.windowManager.i3.enable = true;
  wayland.windowManager.sway.enable = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam-run"
    "steam"
    "steam-original"
    "steam-runtime"
    "steamcmd"
  ];
  home.packages = with pkgs; [
    steam-run steam
    easyeffects
    wineWowPackages.waylandFull
    winetricks
    protontricks proton-caller
    bottles
    gimp krita blender
    tdesktop
    # waiting until the PR gets merged
    (looking-glass-client.overrideAttrs (old: {
      version = "B6";
      src = fetchFromGitHub {
        owner = "gnif";
        repo = "LookingGlass";
        rev = "B6";
        sha256 = "sha256-6vYbNmNJBCoU23nVculac24tHqH7F4AZVftIjL93WJU=";
        fetchSubmodules = true;
      };
      buildInputs = old.buildInputs ++ (with pkgs; [ pipewire libsamplerate ]);
      cmakeFlags = old.cmakeFlags ++ [ "-DENABLE_PULSEAUDIO=no" ];
    }))
  ];
  home.file."${config.xdg.configHome}/looking-glass/client.ini".text = ''
    [app]
    shmFile=/dev/kvmfr0
    capture=dxgi

    [dxgi]
    copyBackend=d3d12
    d3d12CopySleep=5
    disableDamage=false

    [input]
    rawMouse=yes
    escapeKey=KEY_INSERT

    [egl]
    vsync=yes

    [opengl]
    vsync=yes

    [win]
    jitRender=yes
  '';
}
