{ options, config, pkgs, lib, ... }:
let
modifier = "Mod4";
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
  modifier = modifier;
  startup = [
    { command = "~/scripts/initwm.sh"; }
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
  menu = "${pkgs.bemenu}/bin/bemenu-run --no-overlap --prompt '>' --tb '#24101a' --tf '#ebbe5f' --fb '#24101a' --nb '#24101ac0' --ab '#24101ac0' --nf '#ebdadd' --af '#ebdadd' --hb '#394893' --hf '#e66e6e' --list 30 --prefix '*' --scrollbar autohide --fn 'Noto Sans Mono' --line-height 23 --sb '#394893' --sf '#ebdadd' --scb '#6b4d52' --scf '#e66e6e'";
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
  # TODO merge with colors in gui.nix
  imports = [ ./options.nix ./gui.nix ];
  home.sessionVariables = {
    BEMENU_OPTS = "--no-overlap --prompt '>' --tb '#24101a' --tf '#ebbe5f' --fb '#24101a' --nb '#24101ac0' --ab '#24101ac0' --nf '#ebdadd' --af '#ebdadd' --hb '#394893' --hf '#e66e6e' --list 30 --prefix '*' --scrollbar autohide --fn 'Noto Sans Mono' --line-height 23 --sb '#394893' --sf '#ebdadd' --scb '#6b4d52' --scf '#e66e6e'";
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
      keybindings = genKeybindings options.xsession.windowManager.i3 {
        XF86AudioRaiseVolume = "exec ${pkgs.pamixer}/bin/pamixer --increase 5";
        XF86AudioLowerVolume = "exec ${pkgs.pamixer}/bin/pamixer --decrease 5";
        XF86AudioMute = "exec ${pkgs.pamixer}/bin/pamixer --toggle-mute";
        XF86AudioPlay = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
        XF86AudioNext = "exec ${pkgs.playerctl}/bin/playerctl next";
        XF86AudioPrev = "exec ${pkgs.playerctl}/bin/playerctl previous";
      };
      terminal = config.terminalBinX;
    }; in i3Config // commonConfig // i3Config;
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
    setxkbmap -layout jp,ru -option caps:swapescape,compose:menu,grp:win_space_toggle
  '';
  home.packages = with pkgs; if config.wayland.windowManager.sway.enable then [
    wl-clipboard
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
  ] else [];
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "bottom";
      # position = "bottom";
      ipc = true;
      height = 40;
      modules-left = [ "cpu" "sway/workspaces" "sway/mode" ];
      "sway/workspaces" = {
        disable-scroll = true;
        format = "{value}{icon}";
        format-icons = {
          default = "";
          focused = "";
          urgent = " ";
          "2" = " 󰵅";
          "3" = " ";
          "4" = " ";
          "5" = " ";
        };
        persistent-workspaces = {
          "1" = []; "2" = []; "3" = []; "4" = []; "5" = [];
        };
      };
      "sway/mode" = {
        tooltip = false;
      };
      modules-center = [ "sway/window" ];
      #fixed-center = false;
      "sway/window" = {
        format = "{title}";
        max-length = 50;
        tooltip = false;
        icon = true;
        rewrite = {
          kitty = "";
          zsh = "";
          nheko = "";
          Nextcloud = "";
          "(.*) — LibreWolf" = "$1";
          "(.*) - KeePassXC" = "$1";
        };
      };
      modules-right = [ "memory" "tray" "wireplumber" "clock" "sway/language" ];
      cpu = {
        # format = "{usage}% ";
        format = " {icon0}{icon1}{icon2}{icon3}{icon4}{icon5}{icon6}{icon7}{icon8}{icon9}{icon10}{icon11}{icon12}{icon13}{icon14}{icon15}";
        format-icons = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
        tooltip = false;
      };
      memory = {
        format = " {used}G";
        tooltip = false;
      };
      tray = {
        icon-size = 26;
        spacing = 5;
      };
      wireplumber = {
        format = "{icon} {volume}%";
        format-muted = "ﱝ";
        format-icons = ["奄" "奔" "墳"];
        tooltip = false;
      };
      clock = {
        interval = 5;
        format = "{:%Y-%m-%d %H:%M:%S}";
        tooltip = false;
      };
      "sway/language" = {
        tooltip = false;
      };
    }];
    style = ./waybar.css;
  };
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
      window.commands = [
        { command = "floating enable; move workspace current";
          criteria = {
            app_id = "^org.keepassxc.KeePassXC$";
            title = "^KeePassXC - (?:Browser |ブラウザーの)?(?:Access Request|アクセス要求)$";
          }; }
      ];
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
        "${modifier}+Print" = "exec ${grimshot}/bin/grimshot copy area";
        "${modifier}+Mod1+Print" = "exec ${grimshot}/bin/grimshot copy window";
        "--locked XF86AudioRaiseVolume" = "exec ${pkgs.pamixer}/bin/pamixer --increase 5";
        "--locked XF86AudioLowerVolume" = "exec ${pkgs.pamixer}/bin/pamixer --decrease 5";
        "--locked XF86AudioMute" = "exec ${pkgs.pamixer}/bin/pamixer --toggle-mute";
        "--locked --inhibited XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
        "--locked --inhibited XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
        "--locked --inhibited XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
      });
      startup = [
        {
          always = true;
          command = "systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP";
        }
        {
          command = "~/scripts/initwm.sh";
        }
        {
          always = true;
          command = "${pkgs.wl-clipboard}/bin/wl-paste -t text --watch ${pkgs.clipman}/bin/clipman store --no-persist";
        }
        {
          command = "${pkgs.swayidle}/bin/swayidle -w timeout 300 '' resume '${pkgs.sway}/bin/swaymsg \"output * dpms on\"'";
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
          xkb_options = "caps:swapescape,compose:ralt,grp:win_space_toggle";
        };
      };
    }; in swayConfig // commonConfig // swayConfig;
    extraSessionCommands = ''
      export BEMENU_BACKEND=wayland
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export QT_QPA_PLATFORMTHEME=gnome
      export MOZ_ENABLE_WAYLAND=1
      export GDK_BACKEND=wayland
      export GTK_USE_PORTAL=1
      export XDG_CURRENT_DESKTOP=sway
    '';
  };
  services.swayidle = let swaylock-start = builtins.toString (with pkgs; writeScript "swaylock-start" ''
    #! ${bash}/bin/bash
    ${procps}/bin/pgrep -fx ${swaylock}/bin/swaylock || ${swaylock}/bin/swaylock
  ''); in {
    enable = true;
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
  programs.swaylock.settings = let textColor = "#ebdadd"; bgColor = "#24101ac0"; in {
    image = "${config.home.homeDirectory}/var/wallpaper.jpg";
    font = "Unifont";
    font-size = 64;

    indicator-caps-lock = true;
    indicator-radius = 256;
    indicator-thickness = 32;
    separator-color = "#00000000";

    layout-text-color = textColor;
    layout-bg-color = bgColor;
    layout-border-color = "#00000000";

    line-uses-inside = true;

    inside-color = bgColor;
    text-color = textColor;
    ring-color = "#8cbf73"; # green
    key-hl-color = "#6398bf"; # blue
    bs-hl-color = "#e66e6e"; # red

    inside-caps-lock-color = bgColor;
    text-caps-lock-color = textColor;
    ring-caps-lock-color = "#ebbe5f"; # yellow
    caps-lock-key-hl-color = "#6398bf"; # same as normal key-hl-color
    caps-lock-bs-hl-color = "#e66e6e"; # same as normal bs-hl-color

    inside-clear-color = bgColor;
    text-clear-color = textColor;
    ring-clear-color = "#8cbf73"; # green

    inside-ver-color = bgColor;
    text-ver-color = textColor;
    ring-ver-color = "#a64999"; # purple

    inside-wrong-color = bgColor;
    text-wrong-color = textColor;
    ring-wrong-color = "#e64e4e"; # deep-ish red
  };
}
