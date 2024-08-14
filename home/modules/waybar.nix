{ config
, pkgs
, lib
, ...
}:

{
  services.playerctld.enable = config.wayland.windowManager.sway.enable;
  programs.waybar = {
    enable = config.wayland.windowManager.sway.enable;
    package = pkgs.waybar.override {
      withMediaPlayer = true;
    };
    /*).overrideAttrs (old: {
      src = pkgs.fetchFromGitHub {
        owner = "chayleaf";
        repo = "Waybar";
        rev = "3091cf4a009e92665325c0dd61adf5ab367786a3";
        sha256 = "sha256-zH4hbQ8+9TYRVW/XYqmAVsi0vsSPn1LPqXxr0gi0j1E=";
      };
    });*/
    settings = let
      layer = if config.phone.enable then "overlay" else "top";
    in lib.toList {
      inherit layer;
      position = "top";
      ipc = true;
      height = 40;
      modules-left = [
        "sway/workspaces"
        "sway/mode"
        "idle_inhibitor"
      ]
      ++ lib.optional (!config.phone.enable) "mpris";
      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = "󰅶";
          deactivated = "󰾪";
        };
      };
      mpris = {
        tooltip = true;
        format = "{player_icon} {dynamic}";
        format-paused = "{status_icon} {dynamic}";
        interval = 1;
        ellipsis = "…";
        # tooltip-format = "{dynamic}";
        album-len = 44;
        artist-len = 44;
        title-len = 44;
        dynamic-len = 44;
        player-icons = {
          default = "";
          mpd = "";
	};
        status-icons.paused = "";
      };
      "sway/workspaces" = {
        disable-scroll = true;
        format = "{value}{icon}";
        format-icons = {
          default = "";
          urgent = " ";
        } // lib.optionalAttrs (!config.phone.enable) {
          "2" = " 󰵅";
          "3" = " ";
          "4" = " ";
          "5" = " ";
        };
        persistent-workspaces = {
          "1" = [ ]; "2" = [ ]; "3" = [ ];
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
        # tooltip = false;
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
      modules-right = [
        "memory"
      ]
      ++ lib.optional (!config.phone.enable) "cpu"
      ++ [
        "tray"
        (if config.phone.enable then "pulseaudio" else "wireplumber")
      ]
      ++ lib.optional (!config.phone.enable) "clock"
      ++ [ "sway/language" ]
      ++ lib.optional config.phone.enable "battery";
      battery = {
        format = "{capacity}%";
      };
      cpu = {
        # format = "{usage}% ";
        format = "{icon0}{icon1}{icon2}{icon3}{icon4}{icon5}{icon6}{icon7}{icon8}{icon9}{icon10}{icon11}{icon12}{icon13}{icon14}{icon15}";
        format-icons = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
      };
      memory = {
        format = "{used}G";
      };
      tray = {
        icon-size = 26;
        spacing = 5;
      };
      wireplumber = {
        format = "{volume}%";
        format-muted = "ﱝ";
        tooltip = false;
      };
      pulseaudio = {
        format = "{volume}%";
        format-muted = "ﱝ";
        tooltip = false;
      };
      clock = {
        interval = 5;
        format = "{:%Y-%m-%d %H:%M:%S}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "year";
          # TODO: make this work
          mode-mon-col = 3;
          on-scroll = 1;
          on-click-right = "mode";
          format = {
            months = "<span color='#ffead3'><b>{}</b></span>";
            days = "<span color='#ecc6d9'><b>{}</b></span>";
            weeks = "<span color='#99ffdd'><b>W{}</b></span>";
            weekdays = "<span color='#ffcc66'><b>{}</b></span>";
            today = "<span color='#ff6699'><b><u>{}</u></b></span>";
          };
        };
      };
      "sway/language" = {
        tooltip = false;
        # make sure it isn't pushed away when other modules get too big
        min-length = 2;
      };
    } ++ lib.optionals config.phone.enable [
      {
        inherit layer;
        position = "top";
        ipc = true;
        height = 40;
        clock = {
          interval = 5;
          format = "{:%Y-%m-%d %H:%M:%S}";
        };
        cpu = {
          # format = "{usage}% ";
          format = "{icon0}{icon1}{icon2}{icon3}{icon4}{icon5}{icon6}{icon7}{icon8}{icon9}{icon10}{icon11}{icon12}{icon13}{icon14}{icon15}";
          format-icons = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
        };
        modules-left = [ "cpu" ];
        modules-right = [ "clock" ];
      }
      {
        inherit layer;
        position = "bottom";
        ipc = true;
        height = 80;
        modules-left = [ "custom/a" "custom/b" "custom/c" ];
        modules-right = [ "custom/d""custom/e"  "custom/f" ];
        # 2 btns: keyboards
        # 1 btn: close
        # 
        "custom/a" = {
          interval = "once"; exec = "${pkgs.coreutils}/bin/echo a"; exec-if = "${pkgs.coreutils}/bin/true";
          format = " A  ";
          on-click = "${config.home.homeDirectory}/scripts/a.sh";
        };
        "custom/b" = {
          interval = "once"; exec = "${pkgs.coreutils}/bin/echo a"; exec-if = "${pkgs.coreutils}/bin/true";
          format = " 󰌌   ";
          on-click = pkgs.writeShellScript "toggle-keyboard.sh" ''
            ${pkgs.procps}/bin/pkill -SIGRTMIN -x wvkbd-mobintl
          '';
        };
        "custom/c" = {
          interval = "once"; exec = "${pkgs.coreutils}/bin/echo a"; exec-if = "${pkgs.coreutils}/bin/true";
          format = " C ";
          on-click = "${config.home.homeDirectory}/scripts/c.sh";
        };
        "custom/d" = {
          interval = "once"; exec = "${pkgs.coreutils}/bin/echo a"; exec-if = "${pkgs.coreutils}/bin/true";
          format = " D  ";
          on-click = "${config.home.homeDirectory}/scripts/d.sh";
        };
        "custom/e" = {
          interval = "once"; exec = "${pkgs.coreutils}/bin/echo a"; exec-if = "${pkgs.coreutils}/bin/true";
          format = " 󰌌   ";
          on-click = pkgs.writeShellScript "toggle-keyboard.sh" ''
            if /run/current-system/sw/bin/busctl get-property --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible | ${pkgs.gnugrep}/bin/grep true; then
              /run/current-system/sw/bin/busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
            else
              /run/current-system/sw/bin/busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
            fi
          '';
        };
        "custom/f" = {
          interval = "once"; exec = "${pkgs.coreutils}/bin/echo a"; exec-if = "${pkgs.coreutils}/bin/true";
          format = " X ";
          on-click = "${config.wayland.windowManager.sway.package}/bin/swaymsg kill";
        };
      }
    ];
    style = ./waybar.css;
  };
  home.packages = with pkgs; [
    playerctl
  ];
}
