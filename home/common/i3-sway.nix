{ options, config, pkgs, lib, ... }:
let
modifier = "Mod4";
rofiSway = config.programs.rofi.finalPackage;
rofiI3 = pkgs.rofi.override { plugins = config.programs.rofi.plugins; };
barConfig = {
  mode = "dock";
  hiddenState = "hide";
  position = "bottom";
  workspaceButtons = true;
  workspaceNumbers = true;
  fonts = {
    names = [ "Noto Sans Mono" "Symbols Nerd Font Mono" ];
    size = 16.0;
  };
  trayOutput = "*";
  colors = {
    background = "#24101a";
    statusline = "#ebdadd";
    separator = "#6b4d52";
    focusedWorkspace = {
      border = "#782a2a";
      background = "#782a2a";
      text = "#ebdadd";
    };
    activeWorkspace = {
      border = "#913131";
      background = "#913131";
      text = "#ebdadd";
    };
    inactiveWorkspace = {
      border = "#472222";
      background = "#4d2525";
      text = "#8c8284";
    };
    urgentWorkspace = {
      border = "#734545";
      background = "#993d3d";
      text = "#ebdadd";
    };
    bindingMode = {
      border = "#734545";
      background = "#993d3d";
      text = "#ebdadd";
    };
  };
};
commonConfig = {
  inherit modifier;
  startup = [
    { command = builtins.toString (with pkgs; writeShellScript "init-wm" ''
      ${callPackage ./home-daemon.nix {}}/bin/dotfiles-home-daemon system76-scheduler&
      ${gnome.zenity}/bin/zenity --password | (${keepassxc}/bin/keepassxc --pw-stdin ~/Nextcloud/keepass.kdbx&)
      # nextcloud and nheko need secret service access
      ${nextcloud-client}/bin/nextcloud --background&
      ${nheko}/bin/nheko&
      ${tdesktop}/bin/telegram-desktop -startintray&
    ''); }
  ];
  colors = {
    focused = {
      childBorder = "#b0a3a5c0";
      # background = "#24101ac0";
      background = "#4c4042e0";
      # border = "#24101ac0";
      border = "#4c4042e0";
      indicator = "#b35656";
      text = "#ebdadd";
    };
    focusedInactive = {
      # background = "#24101ac0";
      background = "#4c4042e0";
      # border = "#24101ac0";
      border = "#4c4042e0";
      childBorder = "#24101ac0";
      indicator = "#b32d2d";
      text = "#ebdadd";
    };
    unfocused = {
      background = "#24101ac0";
      # border = "#24101ac0";
      border = "#4c4042e0";
      childBorder = "#24101ac0";
      indicator = "#661a1a";
      text = "#ebdadd";
    };
    urgent = {
      background = "#993d3d";
      border = "#734545";
      childBorder = "#734545";
      indicator = "#993d3d";
      text = "#ebdadd";
    };
  };
  floating.criteria = [
    { class = "Anki"; title = "Add"; }
    { class = "Anki"; title = "Statistics"; }
    { class = "Anki"; title = "Preferences"; }
  ];
  floating.titlebar = true;
  fonts = {
    names = [ "Noto Sans Mono" "Symbols Nerd Font Mono" ];
    size = 16.0;
  };
  gaps = {
    smartBorders = "on";
    smartGaps = true;
    inner = 10;
  };
  window.hideEdgeBorders = "smart";
  workspaceAutoBackAndForth = true;
};
genKeybindings = (default_options: kb:
  kb // {
    "${modifier}+Shift+g" = "floating toggle";
    "${modifier}+g" = "focus mode_toggle";
    XF86AudioMicMute = "exec ${pkgs.pamixer}/bin/pamixer --default-source --toggle-mute";
    XF86MonBrightnessDown = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
    XF86MonBrightnessUp = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
  }
  // (lib.attrsets.filterAttrs
    (k: v:
      !(builtins.elem
        k
        ["${modifier}+space" "${modifier}+Shift+space"]))
    (lib.lists.head
      (lib.lists.head
        default_options.config.type.getSubModules)
      .imports)
    .options.keybindings.default)
);
in
{
  # TODO merge with colors in gui.nix and terminal.nix
  imports = [ ./options.nix ./gui.nix ./waybar.nix ];
  home.sessionVariables = {
    _JAVA_AWT_WM_NONREPARENTING = "1";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    XIM_SERVERS = "fcitx";
    INPUT_METHOD = "fcitx";
    SUDO_ASKPASS = pkgs.writeScript "sudo-askpass" ''
      #! ${pkgs.bash}/bin/bash
      ${pkgs.libsecret}/bin/secret-tool lookup root password
    '';
  };
  xdg.configFile."xdg-desktop-portal-wlr/config".source = (pkgs.formats.ini {}).generate "xdg-desktop-portal-wlr.ini" {
    screencast = {
      max_fps = 60;
      chooser_type = "simple";
      chooser-cmd = "''${pkgs.slurp}/bin/slurp -f %o -or";
      # exec_before
      # exec_after
    };
  };
  systemd.user.services = lib.mkIf config.wayland.windowManager.sway.enable {
    gammastep.Unit.ConditionEnvironment = "WAYLAND_DISPLAY";
  };
  programs.mako = {
    enable = lib.mkDefault config.wayland.windowManager.sway.enable;
    # ms
    defaultTimeout = 7500;
    font = "Noto Sans Mono 12";
  };
  xsession.windowManager.i3 = {
    config = let i3Config = {
      bars = [
        (barConfig // {
          statusCommand = "${pkgs.i3status}/bin/i3status";
        })
      ];
      menu = "${rofiI3}/bin/rofi -show drun";
      keybindings = genKeybindings options.xsession.windowManager.i3 {
        "${modifier}+c" = "exec ${rofiI3}/bin/rofi -show calc -no-show-match -no-sort -no-persist-history";
        XF86AudioRaiseVolume = "exec ${pkgs.pamixer}/bin/pamixer --increase 5";
        XF86AudioLowerVolume = "exec ${pkgs.pamixer}/bin/pamixer --decrease 5";
        XF86AudioMute = "exec ${pkgs.pamixer}/bin/pamixer --toggle-mute";
        XF86AudioPlay = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
        XF86AudioNext = "exec ${pkgs.playerctl}/bin/playerctl next";
        XF86AudioPrev = "exec ${pkgs.playerctl}/bin/playerctl previous";
      };
      terminal = config.terminalBinX;
    }; in commonConfig // i3Config;
  };
  home.file.".xinitrc".text = ''
    if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
      eval $(dbus-launch --exit-with-session --sh-syntax)
    fi
    systemctl --user import-environment DISPLAY XAUTHORITY
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
      dbus-update-activation-environment DISPLAY XAUTHORITY
    fi
    exec i3
  '';
  xsession.initExtra = ''
    setxkbmap -layout jp,ru -option compose:ralt,grp:win_space_toggle
  '';
  wayland.windowManager.sway = {
    wrapperFeatures.gtk = true;
    config = let swayConfig = {
      bars = [
        {
          command = "${config.programs.waybar.package}/bin/waybar";
          mode = "dock";
          position = "top";
          hiddenState = "hide";
        }
      ];
      terminal = config.terminalBin;
      window = commonConfig.window // { commands = [
        { command = "floating enable; move workspace current";
          criteria = {
            app_id = "^org.keepassxc.KeePassXC$";
            title = "^KeePassXC - (?:Browser |ブラウザーの)?(?:Access Request|アクセス要求)$";
          }; }
      ]; };
      assigns = {
        "2" = [
          { app_id = "org.telegram.desktop"; }
          { app_id = "nheko"; }
        ];
        "3" = [{ app_id = "org.keepassxc.KeePassXC"; }];
      };
      keybindings = genKeybindings options.wayland.windowManager.sway (with pkgs.sway-contrib;
      let
        modifiers = [
          "shift"
          "lock" # caps lock
          "control"
          "mod1" # alt
          "mod2" # num lock
          # "mod3" # no keys are here by default
          "mod4" # super/hyper
          "mod5" # alt gr?
        ];
        modifierPairs =
          builtins.filter
            (x: x != null)
            (builtins.map
              ({a, b}: if a >= b then null else "${a}+${b}")
              (lib.attrsets.cartesianProductOfSets {
                a = modifiers;
                b = modifiers;
              }));
        modifierTriples = ["control+shift+mod1" "control+shift+mod4" "control+mod1+mod4" "control+shift+mod5"];
        modifierCombos = modifiers ++ modifierPairs ++ modifierTriples;
        # god this is so annoying... sway doesn't provide the option to ignore
        # modifiers in a binding because i3 doesn't have it, and I'm not about
        # to ask i3 to add it just so I can ask sway to add it.. this will do
        forAllModifiers = (prefix: key: cmd:
          lib.attrsets.genAttrs
            ((builtins.map
              (mod: "${prefix}${mod}+${key}")
              modifierCombos)
            ++ ["${prefix}${key}"])
            (name: cmd));
      in (forAllModifiers
        "--inhibited --no-repeat "
        "Scroll_Lock"
        "exec ${pkgs.mumble}/bin/mumble rpc starttalking")
      // (forAllModifiers
        "--inhibited --no-repeat --release "
        "Scroll_Lock"
        "exec ${pkgs.mumble}/bin/mumble rpc stoptalking")
      // {
        "${modifier}+c" = "exec ${rofiSway}/bin/rofi -show calc -no-show-match -no-sort -no-persist-history";
        "${modifier}+Print" = "exec ${grimshot}/bin/grimshot copy area";
        "${modifier}+Mod1+Print" = "exec ${grimshot}/bin/grimshot copy window";
        "--locked XF86AudioRaiseVolume" = "exec ${pkgs.pamixer}/bin/pamixer --increase 5";
        "--locked XF86AudioLowerVolume" = "exec ${pkgs.pamixer}/bin/pamixer --decrease 5";
        "--locked XF86AudioMute" = "exec ${pkgs.pamixer}/bin/pamixer --toggle-mute";
        "--locked --inhibited XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
        "--locked --inhibited XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
        "--locked --inhibited XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
      });
      startup = commonConfig.startup ++ [
        {
          always = true;
          command = "systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP";
        }
        {
          command = "${pkgs.wl-clipboard}/bin/wl-paste -t text --watch ${pkgs.clipman}/bin/clipman store --no-persist";
        }
      ];
      output = {
        "*" = {
          bg = "~/var/wallpaper.jpg fill";
          # improved screen latency, apparently
          max_render_time = "2";
        };
      };
      input = {
        "*" = {
          xkb_layout = "jp,ru";
          xkb_options = "compose:ralt,grp:win_space_toggle";
        };
      };
      menu = "${rofiSway}/bin/rofi -show drun";
    }; in commonConfig // swayConfig;
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export QT_QPA_PLATFORMTHEME=gnome
      export MOZ_ENABLE_WAYLAND=1
      export GDK_BACKEND=wayland,x11
      export GTK_USE_PORTAL=1
      export XDG_CURRENT_DESKTOP=sway
      export XDG_SESSION_DESKTOP=sway
      # TODO: set to sdl3 compat when SDL3 releases
      # this is for steam games, I set the launch options to:
      # `SDL_DYNAMIC_API=$SDL2_DYNAMIC_API %command%`
      # Steam itself doesn't work with SDL_DYNAMIC_API set, so it's
      # a bad idea to set SDL_DYNAMIC_API globally
      export SDL2_DYNAMIC_API=${pkgs.SDL2.out}/lib/libSDL2.so
    '';
  };
  services.swayidle = let swaylock-start = builtins.toString (with pkgs; writeScript "swaylock-start" ''
    #! ${bash}/bin/bash
    ${procps}/bin/pgrep -fx "${swaylock}/bin/swaylock -f" || ${swaylock}/bin/swaylock -f
  ''); in {
    enable = config.wayland.windowManager.sway.enable;
    events = [
      { event = "before-sleep"; command = swaylock-start; }
      # after-resume, lock, unlock
    ];
    timeouts = [
      { timeout = 300; 
        command = "${pkgs.sway}/bin/swaymsg \"output * dpms off\"";
        resumeCommand = "${pkgs.sway}/bin/swaymsg \"output * dpms on\""; }
      { timeout = 600;
        command = swaylock-start; }
    ];
  };
  programs.swaylock.settings = rec {
    image = "${config.home.homeDirectory}/var/wallpaper.jpg";
    font = "Unifont";
    font-size = 64;

    indicator-caps-lock = true;
    indicator-radius = 256;
    indicator-thickness = 32;
    separator-color = "#00000000";

    layout-text-color = text-color;
    layout-bg-color = inside-color;
    layout-border-color = "#00000000";

    line-uses-inside = true;

    inside-color = "#24101ac0";
    text-color = "#ebdadd";
    ring-color = "#8cbf73"; # green
    key-hl-color = "#6398bf"; # blue
    bs-hl-color = "#e66e6e"; # red

    inside-caps-lock-color = inside-color;
    text-caps-lock-color = text-color;
    ring-caps-lock-color = "#ebbe5f"; # yellow
    caps-lock-key-hl-color = key-hl-color;
    caps-lock-bs-hl-color = bs-hl-color;

    inside-clear-color = inside-color;
    text-clear-color = text-color;
    ring-clear-color = ring-color; # green

    inside-ver-color = inside-color;
    text-ver-color = text-color;
    ring-ver-color = "#a64999"; # purple

    inside-wrong-color = inside-color;
    text-wrong-color = text-color;
    ring-wrong-color = "#e64e4e"; # deep-ish red
  };
  home.packages = with pkgs; if config.wayland.windowManager.sway.enable then [
    wl-clipboard
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
  ] else [];
  programs.rofi = {
    enable = true;
    font = "Noto Sans Mono 16";
    package = lib.mkIf config.wayland.windowManager.sway.enable pkgs.rofi-wayland;
    plugins = with pkgs; [
      rofi-calc
    ];
    theme = with config.lib.formats.rasi; let transparent = mkLiteral "transparent"; in {
      "*" = rec {
        highlight = mkLiteral "bold italic";
        scrollbar = true;

        background = transparent;
        background-color = mkLiteral "#24101a80";
        foreground = mkLiteral "#ebdadd";
        border-color = foreground;
        separatorcolor = border-color;
        scrollbar-handle = border-color;

        normal-background = transparent;
        normal-foreground = foreground;
        alternate-normal-background = transparent;
        alternate-normal-foreground = normal-foreground;
        selected-normal-background = mkLiteral "#394893";
        selected-normal-foreground = mkLiteral "#e66e6e";

        active-background = foreground;
        active-foreground = mkLiteral "#24101a";
        alternate-active-background = active-background;
        alternate-active-foreground = active-foreground;
        selected-active-background = mkLiteral "#e66e6e";
        selected-active-foreground = mkLiteral "#394893";

        urgent-background = mkLiteral "#e66e6e";
        urgent-foreground = foreground;
        alternate-urgent-background = urgent-background;
        alternate-urgent-foreground = urgent-foreground;
        selected-urgent-background = mkLiteral "#394893";
        selected-urgent-foreground = mkLiteral "#ebbe5f";
      };
      "@import" = "gruvbox-common.rasi";
    };
    terminal = config.terminalBin;
    extraConfig = {
      modi = [ "calc" "drun" "run" "ssh" ];
      icon-theme = "hicolor";
      drun-match-fields = [ "name" "generic" "exec" "keywords" ];
      show-icons = true;
      matching = "fuzzy";
      sort = true;
      sorting-method = "fzf";
      steal-focus = true;
    };
  };
}
