# WIP (I don't even have the phone yet)

{ pkgs
, config
, ... }:

{
  system.stateVersion = "23.11";

  # kde connect
  networking.firewall.allowedTCPPortRanges = [
    { from = 1714; to = 1764; }
  ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 1714; to = 1764; }
  ];

  networking.wireless.iwd.enable = true;
  common.minimal = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  security.polkit.enable = true;
  security.rtkit.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
  };
  services.sshd.enable = true;
  users.users.${config.common.mainUsername}.extraGroups = [ "video" "feedbackd" "dialout" ];

  mobile.generatedFilesystems.rootfs = {
    filesystem = "btrfs";
    btrfs.partitionID = "44444444-4444-4444-8888-888888888888";
  };
}
