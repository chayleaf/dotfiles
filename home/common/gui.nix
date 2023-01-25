{ config, pkgs, lib, ... }:
{
  imports = [ ./terminal.nix ];
  home.sessionVariables."ALSOFT_CONF" = "${config.xdg.configHome}/.config/alsoft.conf";
  xdg.configFile."alsoft.conf".text = ''
    [general]
    hrtf = true
    stereo-encoding = hrtf
    drivers = pipewire,pulseaudio,jack,alsa,oss,
    periods = 2
    hrtf-paths = ${pkgs.openal}/share/openal/hrtf

    [decoder]
    hq-mode = true

    [pipewire]
    rt-mix = true

    [pulse]
    allow-moves = true
  '';

  xdg.userDirs.enable = true;

  # TODO sort out this mess with colors
  programs.mpv = {
    enable = true;
    defaultProfiles = [ "main" ];
    profiles.main = {
      vo = "vdpau";
      alang = "jpn,en,ru";
      slang = "jpn,en,ru";
      vlang = "jpn,en,ru";
    };
    scripts = [ ];
  };
  i18n.inputMethod = let fcitx5-qt = pkgs.libsForQt5.fcitx5-qt; in {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-lua fcitx5-gtk fcitx5-mozc fcitx5-configtool fcitx5-qt ];
  };
  xresources.properties = {
    # special colors
    "*.foreground" = "#ebdadd";
    "*.background" = "[75]#24101a";
    "*.cursorColor" = "#ebdadd";
    # black
    "*.color0" = "#523b3f"; # "#3b4252";
    "*.color8" = "#6b4d52"; # "#4c566a";
    # red
    "*.color1" = "#e66e6e";
    "*.color9" = "#e66e6e";
    # green
    "*.color2" = "#8cbf73";
    "*.color10" = "#8cbf73";
    # yellow
    "*.color3" = "#ebbe5f";
    "*.color11" = "#ebbe5f";
    # blue
    "*.color4" = "#5968b3";
    "*.color12" = "#5968b3";
    # magenta
    "*.color5" = "#a64999";
    "*.color13" = "#a64999";
    # cyan
    "*.color6" = "#77c7c2";
    "*.color14" = "#77c7c2";
    # white
    "*.color7" = "#f0e4e6";
    "*.color15" = "#f7f0f1";
    "*antialias" = true;
    "*autohint" = true;
    # "*fading" = 0;
    # "*fadeColor" = "#6b4d52";
  };
  # home.file.".Xdefaults".source = /. + "/${config.home.homeDirectory}/.Xresources";
  home.file.".Xdefaults".source = config.home.file."${config.home.homeDirectory}/.Xresources".source;
  services.gammastep.enable = true;
  services.kdeconnect.enable = true;
  fonts.fontconfig.enable = true;
  gtk = {
    enable = true;
    font.name = "Noto Sans";
    font.size = 10;
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    theme = {
      package = pkgs.breeze-gtk;
      name = "Breeze-Dark";
    };
  };
  programs.fzf = {
    enable = true;
  };

  systemd.user.services = {
    fcitx5-daemon = {
      Unit.After = "graphical-session-pre.target";
      Service = {
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
  # i run this manually instead
  #services.nextcloud-client = {
  #  enable = true;
  #  startInBackground = true;
  #};
  # and this too
  #programs.nheko = {
  #  enable = true;
  #  settings = {
  #  };
  #};

  # some packages require a pointer theme
  home.pointerCursor.gtk.enable = true;
  home.pointerCursor.package = pkgs.vanilla-dmz;
  home.pointerCursor.name = "Vanilla-DMZ";
  programs.yt-dlp.enable = true;
  home.packages = with pkgs; [
    # wayland
    grim slurp
    # gui compat stuff
    qt5ct qgnomeplatform
    # various programs i use
    keepassxc nheko qbittorrent anki mumble
    nextcloud-client gnome.zenity
    # cli tools
    imagemagick ffmpeg
    # fonts
    noto-fonts noto-fonts-cjk noto-fonts-emoji
    (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
    # might check out some day (tm)
    # nyxt qutebrowser
  ];
}
