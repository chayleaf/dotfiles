{ config, pkgs, ... }:
{
  imports = [ ./options.nix ];
  manual.json.enable = true;
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    maxCacheTtl = 72000;
    maxCacheTtlSsh = 72000;
  };

  programs = {
    neomutt = {
      enable = true;
      sidebar.enable = true;
      vimKeys = true;
    };
    home-manager.enable = true;
    bash = {
      enable = true;
    };
    fish = {
      enable = true;
      interactiveShellInit = ''
        ${pkgs.gnupg}/bin/gpg-connect-agent --quiet updatestartuptty /bye > /dev/null
      '';
      shellInit = ''
        set PATH ~/bin/:$PATH
      '';
      shellAbbrs = {
      };
    };
    git = {
      enable = true;
      package = pkgs.gitAndTools.gitFull;
      delta.enable = true;
    };
    ssh = {
      enable = true;
      compression = true;
    };
    tmux = {
      enable = true;
      clock24 = true;
      customPaneNavigationAndResize = true;
      keyMode = "vi";
    };
    gpg = {
      enable = true;
      homedir = "${config.xdg.dataHome}/gnupg";
      mutableKeys = true;
      mutableTrust = true;
    };
    nix-index.enable = true;
  };

  home.packages = with pkgs; [
    rclone fuse jq appimage-run python3Full
  ];
}
