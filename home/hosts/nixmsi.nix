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
  termShell = {
    enable = true;
    path = "${pkgs.zsh}/bin/zsh";
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
  ];
  home.sessionVariables = let sources = (import ../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchurl fetchFromGitHub dockerTools;
  });
  proton-ge = pkgs.stdenv.mkDerivation {
    inherit (sources.proton-ge) pname version src;
    nativeBuildInputs = [];
    installPhase = ''
      mkdir -p $out
      tar -C $out --strip=1 -x -f $src
    '';
  }; in {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${proton-ge}";
  };
  home.packages = with pkgs; [
    steam-run steam
    easyeffects
    # wineWowPackages.waylandFull
    winetricks
    protontricks # proton-caller
    bottles
    virtmanager
    gimp krita blender
    tdesktop
    clang rustc rustfmt cargo clippy
    (import ../common/home-daemon.nix { inherit lib pkgs; })
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
  xdg.configFile."looking-glass/client.ini".text = ''
    [app]
    shmFile=/dev/kvmfr0

    [input]
    rawMouse=yes
    escapeKey=KEY_INSERT
  '';
}
