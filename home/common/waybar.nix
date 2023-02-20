{ config, pkgs, ... }:
{
  services.playerctld.enable = config.wayland.windowManager.sway.enable;
  programs.waybar = {
    enable = config.wayland.windowManager.sway.enable;
    package = (pkgs.waybar.override {
      withMediaPlayer = true;
    }).overrideAttrs (old: {
      src = pkgs.fetchFromGitHub {
        owner = "chayleaf";
        repo = "Waybar";
        rev = "8c3a5d8044b9de7de445c76b22443939a6870dc4";
        sha256 = "sha256-4dRsR6D2KYa3eLojTNAS6UZNnle78yeNbSH2XwjcwlU=";
      };
    });
    settings = [{
      layer = "bottom";
      # position = "bottom";
      ipc = true;
      height = 40;
      modules-left = [ "sway/workspaces" "sway/mode" "mpris" ];
      mpris = {
        tooltip = true;
        format = "{player_icon} {dynamic}";
        format-paused = "{status_icon} {dynamic}";
        interval = 1;
        # tooltip-format = "{dynamic}";
        album-len = 32;
        artist-len = 32;
        title-len = 32;
        dynamic-len = 32;
        player-icons = {
          default = "▶";
          mpd = "🎵";
	};
        status-icons.paused = "⏸";
      };
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
      modules-right = [ "memory" "cpu" "tray" "wireplumber" "clock" "sway/language" ];
      cpu = {
        # format = "{usage}% ";
        format = "{icon0}{icon1}{icon2}{icon3}{icon4}{icon5}{icon6}{icon7}{icon8}{icon9}{icon10}{icon11}{icon12}{icon13}{icon14}{icon15}";
        format-icons = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
        tooltip = false;
      };
      memory = {
        format = "{used}G";
        tooltip = false;
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
      clock = {
        interval = 5;
        format = "{:%Y-%m-%d %H:%M:%S}";
        tooltip = false;
      };
      "sway/language" = {
        tooltip = false;
        # make sure it isn't pushed away when other modules get too big
        min-length = 2;
      };
    }];
    style = ./waybar.css;
  };
}
