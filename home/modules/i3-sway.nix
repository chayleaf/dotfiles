{ options, config, pkgs, lib, ... }:
let
modifier = if config.phone.enable then "Mod1" else "Mod4";
rofiSway = config.programs.rofi.finalPackage;
rofiI3 = pkgs.rofi.override { plugins = config.programs.rofi.plugins; };
audioNext = pkgs.writeShellScript "playerctl-next" ''
  ${pkgs.playerctl}/bin/playerctl next
  PLAYER=$(${pkgs.playerctl}/bin/playerctl -l | ${pkgs.coreutils}/bin/head -n 1)
  # mpdris2 bug: audio wont play after a seek/skip, you have to pause-unpause
  if [[ "$PLAYER" == "mpd" ]]; then
    ${pkgs.playerctl}/bin/playerctl pause
    ${pkgs.playerctl}/bin/playerctl position 0
    ${pkgs.playerctl}/bin/playerctl play
  fi
'';
audioPrev = pkgs.writeShellScript "playerctl-prev" ''
  # just seek if over 5 seconds into the track
  POS=$(${pkgs.playerctl}/bin/playerctl position)
  PLAYER=$(${pkgs.playerctl}/bin/playerctl -l | ${pkgs.coreutils}/bin/head -n 1)
  if [ -n "$POS" ]; then
    if (( $(echo "$POS > 5.01" | ${pkgs.bc}/bin/bc -l) )); then
      SEEK=1
    fi
  fi
  if [ -z "$SEEK" ]; then
    ${pkgs.playerctl}/bin/playerctl previous
  else
    ${pkgs.playerctl}/bin/playerctl position 0
  fi
  # mpdris2 bug: audio wont play after a seek/skip, you have to pause-unpause
  if [[ "$PLAYER" == "mpd" ]]; then
    ${pkgs.playerctl}/bin/playerctl pause
    ${pkgs.playerctl}/bin/playerctl position 0
    ${pkgs.playerctl}/bin/playerctl play
  fi
'';
swaylock =
  if config.phone.enable
  then "${pkgs.schlock}/bin/schlock -fp /secrets/schlock.pin"
  else "${pkgs.swaylock}/bin/swaylock -f";
swaylock-start = pkgs.writeShellScript "swaylock-start" ''
  ${pkgs.procps}/bin/pgrep -fx "${swaylock}" || ${swaylock}
'';
dpms-off = pkgs.writeShellScript "sway-dpms-off" ''
  ${config.wayland.windowManager.sway.package}/bin/swaymsg output "*" power off
  ${config.wayland.windowManager.sway.package}/bin/swaymsg input type:touch events disabled
'';
dpms-on = pkgs.writeShellScript "sway-dpms-on" ''
  ${config.wayland.windowManager.sway.package}/bin/swaymsg output "*" power on
  ${config.wayland.windowManager.sway.package}/bin/swaymsg input type:touch events enabled
'';
lock-script = pkgs.writeShellScript "lock-start" ''
  ${swaylock-start}
  ${lib.optionalString config.phone.enable
  # suspend if nothing is playing
  ''
    ${pkgs.playerctl}/bin/playerctl -a status | ${pkgs.gnugrep}/bin/grep Playing >/dev/null || /run/current-system/sw/bin/systemctl suspend
  ''}
'';
barConfig = {
  mode = "overlay";
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
    background = "#${config.colors.background}";
    statusline = "#${config.colors.foreground}";
    separator = "#${config.colors.brBlack}";
    focusedWorkspace = {
      border = "#782a2a";
      background = "#782a2a";
      text = "#${config.colors.foreground}";
    };
    activeWorkspace = {
      border = "#913131";
      background = "#913131";
      text = "#${config.colors.foreground}";
    };
    inactiveWorkspace = {
      border = "#472222";
      background = "#4d2525";
      text = "#8c8284";
    };
    urgentWorkspace = {
      border = "#734545";
      background = "#993d3d";
      text = "#${config.colors.foreground}";
    };
    bindingMode = {
      border = "#734545";
      background = "#993d3d";
      text = "#${config.colors.foreground}";
    };
  };
};
commonConfig = {
  inherit modifier;
  startup = [
    { command = toString (pkgs.writeShellScript "init-wm" ''
      ${lib.optionalString config.phone.enable ''
        ${pkgs.squeekboard}/bin/squeekboard&
        ${pkgs.wvkbd}/bin/wvkbd-mobintl --hidden -l full,special,cyrillic,emoji&
        /run/current-system/sw/bin/busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
      ''}
      ${pkgs.home-daemon}/bin/home-daemon system76-scheduler&
      ${pkgs.gnome.zenity}/bin/zenity --password | ${pkgs.coreutils}/bin/tee /dev/stdout | (${pkgs.keepassxc}/bin/keepassxc --pw-stdin ~/Nextcloud/keepass.kdbx ~/var/local.kdbx&)
      # nextcloud and nheko need secret service access
      ${pkgs.nextcloud-client}/bin/nextcloud --background&
      ${pkgs.nheko}/bin/nheko&
      ${pkgs.tdesktop}/bin/telegram-desktop -startintray&
    ''); }
  ];
  colors = {
    focused = {
      childBorder = "#b0a3a5${config.colors.hexAlpha}";
      # background = "#${config.colors.background}${config.colors.hexAlpha}";
      background = "#4c4042e0";
      # border = "#${config.colors.background}${config.colors.hexAlpha}";
      border = "#4c4042e0";
      indicator = "#b35656";
      text = "#${config.colors.foreground}";
    };
    focusedInactive = {
      # background = "#${config.colors.background}${config.colors.hexAlpha}";
      background = "#4c4042e0";
      # border = "#${config.colors.background}${config.colors.hexAlpha}";
      border = "#4c4042e0";
      childBorder = "#${config.colors.background}${config.colors.hexAlpha}";
      indicator = "#b32d2d";
      text = "#${config.colors.foreground}";
    };
    unfocused = {
      background = "#${config.colors.background}${config.colors.hexAlpha}";
      # border = "#${config.colors.background}${config.colors.hexAlpha}";
      border = "#4c4042e0";
      childBorder = "#${config.colors.background}${config.colors.hexAlpha}";
      indicator = "#661a1a";
      text = "#${config.colors.foreground}";
    };
    urgent = {
      background = "#993d3d";
      border = "#734545";
      childBorder = "#734545";
      indicator = "#993d3d";
      text = "#${config.colors.foreground}";
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
  // (lib.filterAttrs
    (k: v:
      !(builtins.elem
        k
        [ "${modifier}+space" "${modifier}+Shift+space" ]))
    (builtins.head
      (builtins.head
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
  services.mako = {
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
        XF86AudioNext = "exec ${audioNext}";
        XF86AudioPrev = "exec ${audioPrev}";
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
    package = pkgs.sway-unwrapped.overrideAttrs (old: {
      patches = old.patches or [] ++ [
        ./sway.patch
        /*(pkgs.fetchpatch {
          url = "https://patch-diff.githubusercontent.com/raw/swaywm/sway/pull/6920.patch";
          sha256 = "sha256-XgkysduhHbmprE334yeL65txpK0HNXeCmgCZMxpwsgU=";
        })*/
      ];
    });
    extraConfig = ''
      title_align center
    '';
    config = commonConfig // {
      bars = [
        {
          command = "${config.programs.waybar.package}/bin/waybar";
          mode = "dock";
          position = "top";
          hiddenState = "hide";
        }
      ];
      terminal = config.terminalBin;
      window = commonConfig.window // { commands = lib.optionals config.phone.enable [
        { command = "floating off; fullscreen off";
          criteria = {
            floating = true;
          }; }
        { command = "fullscreen off";
          criteria = {
            tiling = true;
          }; }
      ] ++ [
        { command = "floating on; move workspace current";
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
        "4" = [
          { class = "Steam"; }
          { class = "steam"; }
        ];
      };
      keybindings = genKeybindings options.wayland.windowManager.sway (with pkgs.sway-contrib;
      /*let
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
        # mumble remembers the amount of times starttalking has been called,
        # and if stoptalking isn't called for some reason, calling it one time stops being enough
        "exec ${pkgs.mumble}/bin/mumble rpc stoptalking && ${pkgs.mumble}/bin/mumble rpc stoptalking")
      //*/ {
        "--inhibited --no-repeat --allow-other Scroll_Lock" = "exec ${pkgs.mumble}/bin/mumble rpc starttalking";
        "--inhibited --no-repeat --allow-other --release Scroll_Lock" = "exec ${pkgs.mumble}/bin/mumble rpc stoptalking";
        "${modifier}+c" = "exec ${rofiSway}/bin/rofi -show calc -no-show-match -no-sort -no-persist-history";
        "${modifier}+Print" = "exec ${grimshot}/bin/grimshot copy area";
        "${modifier}+${if modifier == "Mod1" then "Mod4" else "Mod1"}+Print" = "exec ${grimshot}/bin/grimshot copy window";
        "--locked XF86AudioRaiseVolume" = "exec ${pkgs.pamixer}/bin/pamixer --increase 5";
        "--locked XF86AudioLowerVolume" = "exec ${pkgs.pamixer}/bin/pamixer --decrease 5";
        "--locked XF86AudioMute" = "exec ${pkgs.pamixer}/bin/pamixer --toggle-mute";
        "--locked --inhibited XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
        "--locked --inhibited XF86AudioNext" = "exec ${audioNext}";
        "--locked --inhibited XF86AudioPrev" = "exec ${audioPrev}";
        "--locked --inhibited --release XF86PowerOff" = lib.mkIf config.phone.enable "exec ${pkgs.writeShellScript "power-key" ''
          if ${config.wayland.windowManager.sway.package}/bin/swaymsg -rt get_outputs | ${pkgs.jq}/bin/jq ".[].power" | ${pkgs.gnugrep}/bin/grep true; then
            ${dpms-off}
            ${lock-script}
          else
            ${dpms-on}
          fi
        ''}";
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
          adaptive_sync = "on";
        };
      };
      input = {
        "*" = {
          xkb_layout = "jp,ru";
          xkb_options = "compose:ralt,grp:win_space_toggle";
        };
      };
      menu = "${rofiSway}/bin/rofi -show drun";
      workspaceLayout = "tabbed";
    };
    # export WLR_RENDERER=vulkan
    extraSessionCommands = lib.optionalString config.wayland.windowManager.sway.vulkan ''
      export WLR_RENDERER=vulkan
    '' + ''
      export SDL_VIDEODRIVER=wayland,x11,kmsdrm,windows,directx
      # SDL3
      export SDL_VIDEO_DRIVER=wayland,x11,kmsdrm,windows
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export QT_QPA_PLATFORMTHEME=gnome
      export MOZ_ENABLE_WAYLAND=1
      export GDK_BACKEND=wayland,x11
      export GTK_USE_PORTAL=1
      export XDG_CURRENT_DESKTOP=sway
      export XDG_SESSION_DESKTOP=sway
    '';
  };
  services.swayidle = {
    enable = config.wayland.windowManager.sway.enable && !config.phone.enable;
    events = [
      { event = "before-sleep"; command = toString swaylock-start; }
      # after-resume, lock, unlock
    ];
    timeouts = [
      { timeout = if config.phone.enable then 30 else 300; 
        command = toString dpms-off;
        resumeCommand = toString dpms-on; }
      { timeout = if config.phone.enable then 60 else 600;
        command = toString lock-script; }
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

    inside-color = "#${config.colors.background}${config.colors.hexAlpha}";
    text-color = "#${config.colors.foreground}";
    ring-color = "#${config.colors.green}";
    key-hl-color = "#6398bf"; # blue
    bs-hl-color = "#${config.colors.red}";

    inside-caps-lock-color = inside-color;
    text-caps-lock-color = text-color;
    ring-caps-lock-color = "#${config.colors.yellow}";
    caps-lock-key-hl-color = key-hl-color;
    caps-lock-bs-hl-color = bs-hl-color;

    inside-clear-color = inside-color;
    text-clear-color = text-color;
    ring-clear-color = ring-color;

    inside-ver-color = inside-color;
    text-ver-color = text-color;
    ring-ver-color = "#${config.colors.magenta}";

    inside-wrong-color = inside-color;
    text-wrong-color = text-color;
    ring-wrong-color = "#e64e4e"; # deep-ish red
  };
  home.packages = lib.mkIf config.wayland.windowManager.sway.enable (with pkgs; [
    wl-clipboard
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
  ]);
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
        background-color =
          # this somehow uses different opacity
          mkLiteral "#${config.colors.background}c0";
        foreground = mkLiteral "#${config.colors.foreground}";
        border-color = foreground;
        separatorcolor = border-color;
        scrollbar-handle = border-color;

        normal-background = transparent;
        normal-foreground = foreground;
        alternate-normal-background = transparent;
        alternate-normal-foreground = normal-foreground;
        selected-normal-background = mkLiteral "#394893";
        selected-normal-foreground = mkLiteral "#${config.colors.red}";

        active-background = foreground;
        active-foreground = mkLiteral "#${config.colors.background}";
        alternate-active-background = active-background;
        alternate-active-foreground = active-foreground;
        selected-active-background = mkLiteral "#${config.colors.red}";
        selected-active-foreground = mkLiteral "#394893";

        urgent-background = mkLiteral "#${config.colors.red}";
        urgent-foreground = foreground;
        alternate-urgent-background = urgent-background;
        alternate-urgent-foreground = urgent-foreground;
        selected-urgent-background = mkLiteral "#394893";
        selected-urgent-foreground = mkLiteral "#${config.colors.yellow}";
      };
      "@import" = "gruvbox-common.rasi";
    };
    terminal = config.terminalBin;
    extraConfig = {
      modi = lib.optionals (!config.phone.enable) [
        "steam:${pkgs.rofi-steam-game-list}/bin/rofi-steam-game-list"
      ] ++ [
        "drun"
        "run"
        "ssh"
      ];
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
