{ pkgs
, lib
# , config
, ...
}:

{
  system.stateVersion = "23.11";

  # kde connect
  networking.firewall.allowedTCPPortRanges = [
    { from = 1714; to = 1764; }
  ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 1714; to = 1764; }
  ];

  common.minimal = false;
  programs.sway.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
  };
  services.sshd.enable = true;
  # users.users.${config.common.mainUsername}.extraGroups = [ "video" "feedbackd" "dialout" ];
}
