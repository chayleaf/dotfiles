{ options, config, pkgs, lib, ... }:
let
modifier = "Mod4";
commonConfig = {
  modifier = modifier;
  bars = [{
    mode = "dock";
    hiddenState = "hide";
    position = "bottom";
    workspaceButtons = true;
    workspaceNumbers = true;
    statusCommand = "${pkgs.i3status}/bin/i3status";
    fonts = {
      names = [ "Noto Sans Mono" ];
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
  }];
  startup = [
    { command = "~/scripts/initwm.sh"; }
  ];
  colors = {
    focused = {
      background = "#913131";
      border = "#913131";
      childBorder = "#b35656";
      indicator = "#b35656";
      text = "#ebdadd";
    };
    focusedInactive = {
      background = "#782a2a";
      border = "#782a2a";
      childBorder = "#b32d2d";
      indicator = "#b32d2d";
      text = "#ebdadd";
    };
    placeholder = {
      background = "#24101a";
      border = "#24101a";
      childBorder = "#24101a";
      indicator = "#000000";
      text = "#ebdadd";
    };
    unfocused = {
      background = "#4d2525";
      border = "#472222";
      childBorder = "#4d2525";
      indicator = "#661a1a";
      text = "#8c8284";
    };
    urgent = {
      background = "#993d3d";
      border = "#734545";
      childBorder = "#993d3d";
      indicator = "#993d3d";
      text = "#ebdadd";
    };
  };
  floating.titlebar = true;
  fonts = {
    names = [ "Noto Sans" "Noto Emoji" "FontAwesome5Free" ];
    size = 16.0;
  };
  gaps = {
    smartBorders = "on";
    smartGaps = true;
    inner = 10;
  };
  menu = "${pkgs.bemenu}/bin/bemenu-run --no-overlap --prompt '>' --tb '#24101a' --tf '#ebbe5f' --fb '#24101a' --nb '#24101a70' --ab '#24101a70' --nf '#ebdadd' --af '#ebdadd' --hb '#394893' --hf '#e66e6e' --list 30 --prefix '*' --scrollbar autohide --fn 'Noto Sans Mono' --line-height 23 --sb '#394893' --sf '#ebdadd' --scb '#6b4d52' --scf '#e66e6e'";
  terminal = if config.useAlacritty then "${pkgs.alacritty}/bin/alacritty" else "${pkgs.urxvt}/bin/urxvt";
  window = {
    hideEdgeBorders = "smart";
  };
  workspaceAutoBackAndForth = true;
  floating.criteria = [
    { title = "Steam - Update News"; }
  ];
};
genKeybindings = (default_options: kb:
  kb // {
    "${modifier}+Shift+g" = "floating toggle";
    "${modifier}+g" = "focus mode_toggle";
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
  imports = [ ./options.nix ./gui.nix ];
  programs.mako = {
    enable = lib.mkDefault config.wayland.windowManager.sway.enable;
    # ms
    defaultTimeout = 7500;
    font = "Noto Sans Mono 12";
  };
  # TODO merge with colors in gui.nix
  programs.alacritty = {
    enable = lib.mkDefault config.useAlacritty;
    settings = {
      window.opacity = 0.75;
      font.normal.family = "Noto Sans Mono";
      font.size = 16;
      colors.primary.background = "#24101a";
      colors.primary.foreground = "#ebdadd";
      colors.normal = {
        black = "#523b3f";
        red = "#e66e6e";
        green = "#8cbf73";
        yellow = "#ebbe5f";
        blue = "#5968b3";
        magenta = "#a64999";
        cyan = "#77c7c2";
        white = "#f0e4e6";
      };
      colors.bright = {
        black = "#6b4d52";
        red = "#e66e6e";
        green = "#8cbf73";
        yellow = "#ebbe5f";
        blue = "#5968b3";
        magenta = "#a64999";
        cyan = "#77c7c2";
        white = "#f7f0f1";
      };
    };
  };
  # i use this instead of alacritty on old laptops
  programs.urxvt = {
    enable = lib.mkDefault (!config.useAlacritty);
    keybindings = {
      "Control-Alt-C" = "builtin-string:";
      "Control-Alt-V" = "builtin-string:";
    };
    extraConfig = {
      depth = 32;
      inheritPixmap = true;
    };
    scroll.bar.enable = false;
    fonts = [ "xft:Noto Sans Mono:pixelsize=16" "xft:Symbols Nerd Font Mono:pixelsize=16" ];
  };
  xsession.windowManager.i3 = {
    config = {
      keybindings = genKeybindings options.xsession.windowManager.i3 {};
    } // commonConfig;
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
    export BEMENU_OPTS="--no-overlap --prompt '>' --tb '#24101a' --tf '#ebbe5f' --fb '#24101a' --nb '#24101a70' --ab '#24101a70' --nf '#ebdadd' --af '#ebdadd' --hb '#394893' --hf '#e66e6e' --list 30 --prefix '*' --scrollbar autohide --fn 'Noto Sans Mono' --line-height 23 --sb '#394893' --sf '#ebdadd' --scb '#6b4d52' --scf '#e66e6e'"
    export _JAVA_AWT_WM_NONREPARENTING=1
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
    export SDL_IM_MODULE=fcitx
    export XIM_SERVERS=fcitx
    export INPUT_METHOD=fcitx
    setxkbmap -layout jp,ru -option caps:swapescape,compose:menu,grp:win_space_toggle
  '';
  home.packages = with pkgs; if config.wayland.windowManager.sway.enable then [
    wl-clipboard
  ] else [];
  wayland.windowManager.sway = {
    wrapperFeatures.gtk = true;
    config = {
      assigns = {
        "3" = [{ app_id = "org.keepassxc.KeePassXC"; }];
      };
      keybindings = genKeybindings options.wayland.windowManager.sway (with pkgs.sway-contrib; {
        "${modifier}+Print" = "exec ${grimshot}/bin/grimshot copy area";
        "${modifier}+Mod1+Print" = "exec ${grimshot}/bin/grimshot copy window";
      });
      startup = [
        {
          command = "~/scripts/initwm.sh";
        }
        {
          always = true;
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
          xkb_options = "caps:swapescape,compose:menu,grp:win_space_toggle";
        };
      };
    } // commonConfig;
    extraSessionCommands = ''
      export BEMENU_OPTS="--no-overlap --prompt '>' --tb '#24101a' --tf '#ebbe5f' --fb '#24101a' --nb '#24101a70' --ab '#24101a70' --nf '#ebdadd' --af '#ebdadd' --hb '#394893' --hf '#e66e6e' --list 30 --prefix '*' --scrollbar autohide --fn 'Noto Sans Mono' --line-height 23 --sb '#394893' --sf '#ebdadd' --scb '#6b4d52' --scf '#e66e6e'"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export GTK_IM_MODULE=fcitx
      export QT_IM_MODULE=fcitx
      export XMODIFIERS=@im=fcitx
      export SDL_IM_MODULE=fcitx
      export XIM_SERVERS=fcitx
      export INPUT_METHOD=fcitx

      export BEMENU_BACKEND=wayland
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export QT_QPA_PLATFORMTHEME=gnome
      export MOZ_ENABLE_WAYLAND=1
    '';
  };
}
