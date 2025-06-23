{ config, pkgs, lib, ... }:

{
imports = [ ./terminal.nix ];
config = lib.mkMerge [
(lib.mkIf (!config.minimal) {
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
  home.sessionVariables = {
    SDL_AUDIODRIVER = "pipewire,pulse,dsound";
    # SDL 3
    SDL_AUDIO_DRIVER = "pipewire,pulseaudio,dsound";
    ALSOFT_CONF = "${config.xdg.configHome}/.config/alsoft.conf";
    # TODO: set to sdl3 compat when SDL3 releases?
    # this is for steam games, I set the launch options to:
    # `SDL_DYNAMIC_API=$SDL2_DYNAMIC_API %command%`
    # Steam itself doesn't work with SDL2_DYNAMIC_API set, so it's
    # a bad idea to set SDL_DYNAMIC_API globally
    SDL2_DYNAMIC_API = "${pkgs.SDL2}/lib/libSDL2.so";
  };
  programs.nnn.extraPackages = with pkgs; [
    # drag & drop
    xdragon
    # xembed
    tabbed
    # for preview
    ffmpeg ffmpegthumbnailer nsxiv imagemagick
    zathura /*libreoffice*/ fontpreview djvulibre poppler_utils
  ] ++ lib.optionals (!config.programs.mpv.enable) [ mpv ];
  programs.mpv = {
    enable = true;
    defaultProfiles = [ "gpu-hq" ];
    bindings = rec {
      MBTN_LEFT_DBL = "cycle fullscreen";
      MBTN_RIGHT = "cycle pause";
      MBTN_BACK = "playlist-prev";
      MBTN_FORWARD = "playlist-next";
      WHEEL_DOWN = "seek -5";
      WHEEL_UP = "seek 5";
      WHEEL_LEFT = "seek -60";
      WHEEL_RIGHT = "seek 60";

      h = "no-osd seek -5 exact";
      LEFT = h;
      l = "no-osd seek 5 exact";
      RIGHT = l;
      j = "seek -30";
      DOWN = j;
      k = "seek 30";
      UP = k;

      H = "no-osd seek -1 exact";
      "Shift+LEFT" = "no-osd seek -1 exact";
      L = "no-osd seek 1 exact";
      "Shift+RIGHT" = "no-osd seek 1 exact";
      J = "seek -300";
      "Shift+DOWN" = "seek -300";
      K = "seek 300";
      "Shift+UP" = "seek 300";

      "Ctrl+LEFT" = "no-osd sub-seek -1";
      "Ctrl+h" = "no-osd sub-seek -1";
      "Ctrl+RIGHT" = "no-osd sub-seek 1";
      "Ctrl+l" = "no-osd sub-seek 1";
      "Ctrl+DOWN" = "add chapter -1";
      "Ctrl+j" = "add chapter -1";
      "Ctrl+UP" = "add chapter 1";
      "Ctrl+k" = "add chapter 1";

      "Alt+LEFT" = "frame-back-step";
      "Alt+h" = "frame-back-step";
      "Alt+RIGHT" = "frame-step";
      "Alt+l" = "frame-step";

      PGUP = "add chapter 1";
      PGDWN = "add chapter -1";

      u = "revert-seek";

      "Ctrl++" = "add sub-scale 0.1";
      "Ctrl+-" = "add sub-scale -0.1";
      "Ctrl+0" = "set sub-scale 0";

      q = "quit";
      Q = "quit-watch-later";
      "q {encode}" = "quit 4";
      p = "cycle pause";
      SPACE = p;
      f = "cycle fullscreen";

      n = "playlist-next";
      N = "playlist-prev";

      o = "show-progress";
      O = "script-binding stats/display-stats-toggle";
      "`" = "script-binding console/enable";
      ":" = "script-binding console/enable";

      z = "add sub-delay -0.1";
      x = "add sub-delay 0.1";
      Z = "add audio-delay -0.1";
      X = "add audio-delay 0.1";

      "1" = "add volume -1";
      "2" = "add volume 1";
      "3" = "add contrast -1";
      "4" = "add contrast 1";
      "5" = "add brightness -1";
      "6" = "add brightness 1";
      "7" = "add saturation -1";
      "8" = "add saturation 1";
      "9" = "add gamma -1";
      "0" = "add gamma 1";
      s = "cycle sub";
      v = "cycle video";
      a = "cycle audio";
      S = ''cycle-values sub-ass-override "force" "no"'';
      PRINT = "screenshot";
      c = "add panscan 0.01";
      C = "add panscan -0.01";
      PLAY = "cycle pause";
      PAUSE = "cycle pause";
      PLAYPAUSE = "cycle pause";
      PLAYONLY = "set pause no";
      PAUSEONLY = "set pause yes";
      STOP = "stop";
      CLOSE_WIN = "quit";
      "CLOSE_WIN {encode}" = "quit 4";
      "Ctrl+w" = ''set hwdec "no"'';
      "[" = "multiply speed 1/1.1";
      "]" = "multiply speed 1.1";
      # T = "script-binding generate-thumbnails";
    };
    config = {
      osc = "no";
      hwdec = "vaapi";
      vo = "gpu,dmabuf-wayland,wlshm,vdpau,xv,x11,sdl,drm,";
      alang = "jpn,en,ru";
      slang = "jpn,en,ru";
      vlang = "jpn,en,ru";
      watch-later-directory = "${config.xdg.stateHome}/mpv/watch_later";
      resume-playback-check-mtime = true;
      # vaapi-device / vulkan-device
      # screen / vulkan-display-display
      audio-device = "pipewire";
      # because ao=pipewire doesn't work for audio-only files for whatever reason...
      # TODO: hopefully remove it when it's fixed upstream
      ao = "pulse,alsa,jack,pipewire,"; 
      audio-file-auto = "fuzzy";
      sub-auto = "fuzzy";
      gpu-context = "waylandvk";
      wayland-edge-pixels-pointer = 0;
      wayland-edge-pixels-touch = 0;
      screenshot-format = "webp";
      screenshot-webp-lossless = true;
      screenshot-directory = "${config.home.homeDirectory}/Pictures/Screenshots/mpv";
      screenshot-sw = true;
      input-default-bindings = false;
    };
    # profiles = { };
    package = pkgs.mpv-unwrapped.wrapper {
      mpv = pkgs.mpv-unwrapped.override {
        # many features aren't supported by normal ffmpeg
        ffmpeg = pkgs.ffmpeg-full;
      };
      scripts = with pkgs.mpvScripts; [
        thumbnail
        mpris
        (subserv.override { port = 1337; secondary = false; })
        (subserv.override { port = 1338; secondary = true; })
      ];
    };
  };
  services.gammastep.enable = true;
  programs.ncmpcpp.enable = true;
  services.mpd = {
    enable = true;
    network.startWhenNeeded = true;
  };
  services.mpdris2 = {
    enable = true;
  };
  programs.yt-dlp.enable = true;
  home.packages = with pkgs; [
    qgnomeplatform
    qbittorrent mumble
    keepassxc nheko nextcloud-client 
    # cli tools
    imagemagick ffmpeg-full
    # might check out some day (tm)
    # nyxt qutebrowser

    # for working with nix
    nix-init
    nvfetcher
    pkgs.nur.repos.rycee.mozilla-addons-to-nix
  ];
})
(lib.mkIf (!config.minimal) {
  systemd.user.services.fcitx5-daemon = {
    # Unit.After = "graphical-session-pre.target";
    Service = {
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
  i18n.inputMethod = let fcitx5-qt = pkgs.libsForQt5.fcitx5-qt; in {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-lua fcitx5-gtk fcitx5-mozc fcitx5-configtool fcitx5-qt ];
  };
  home.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    XIM_SERVERS = "fcitx";
    INPUT_METHOD = "fcitx";
  };
})
{
  home.sessionVariables = {
    SUDO_ASKPASS = pkgs.writeScript "sudo-askpass" ''
      #! ${pkgs.bash}/bin/bash
      ${pkgs.libsecret}/bin/secret-tool lookup root password
    '';
  };

  xdg.userDirs.enable = true;
  fonts.fontconfig.enable = true;
  gtk = {
    enable = true;
    font.name = "Noto Sans";
    font.size = 10;
    iconTheme = lib.mkIf (!config.minimal) {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    theme = lib.mkIf (!config.minimal) {
      package = pkgs.kdePackages.breeze-gtk;
      name = "Breeze-Dark";
    };
  };
  programs.fzf = {
    enable = true;
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
  termShell = {
    enable = true;
    path = "${pkgs.fish}/bin/fish";
  };
  systemd.user.services.kdeconnect = lib.mkIf config.services.kdeconnect.enable {
    Service = {
      Restart = lib.mkForce "always";
      RestartSec = "30";
    };
  };

  nixpkgs = lib.mkIf (!config.minimal) {
    config.permittedInsecurePackages = [
      "olm-3.2.16"
    ];
  };

  # some packages require a pointer theme
  home.pointerCursor.gtk.enable = true;
  home.pointerCursor.package = pkgs.vanilla-dmz;
  home.pointerCursor.name = "Vanilla-DMZ";
  home.packages = with pkgs; [
    grim slurp
    # cli tools
    xdg-utils
    # fonts
    noto-fonts noto-fonts-cjk-sans noto-fonts-cjk-serif
    noto-fonts-emoji noto-fonts-extra
    # no idea why this is necessary
    (pkgs.runCommand "nerd-fonts-symbols-only" {} ''
      mkdir -p "$out"
      cp -r "${nerd-fonts.symbols-only}"/* "$out"
      chmod +w "$out/share/fonts/truetype/NerdFonts"
      cp -r "$out/share/fonts/truetype/NerdFonts/Symbols"/* "$out/share/fonts/truetype/NerdFonts"
    '')
  ];
  #++ lib.optional config.services.kdeconnect.enable plasma5Packages.kdeconnect-kde;
}];
}
