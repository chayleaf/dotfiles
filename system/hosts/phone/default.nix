{ pkgs
, lib
, config
, ...
}:

{
  imports = [ ./options.nix ];

  system.stateVersion = "23.11";

  systemd.network.links."40-wlan0" = {
    matchConfig.OriginalName = "wlan0";
    linkConfig.MACAddressPolicy = "none";
    linkConfig.MACAddress = config.phone.mac;
  };

  sound.enable = true;
  services.logind.powerKey = "ignore";
  services.logind.powerKeyLongPress = "poweroff";
  hardware.sensor.iio.enable = true;
  services.pipewire.enable = false;
  hardware.pulseaudio.enable = lib.mkForce true;
  users.users.${config.common.mainUsername}.extraGroups = [
    "dialout"
    "feedbackd"
    "video"
  ] ++ lib.optional (config.networking.modemmanager.enable || config.networking.networkmanager.enable) "networkmanager";

  common.minimal = false;
  services.sshd.enable = true;
  services.tlp.enable = true;

  # kde connect
  networking.firewall.allowedTCPPortRanges = [
    { from = 1714; to = 1764; }
  ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 1714; to = 1764; }
  ];

  programs.calls.enable = true;
  environment.systemPackages = with pkgs; [
    # IM and SMS
    chatty
  ];

  programs.sway.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
  };
  # services.xserver.desktopManager.phosh = {
  #   enable = true;
  #   group = "users";
  #   user = config.common.mainUsername;
  # };
}
