{
  config,
  pkgs,
  lib,
  ...
}:

{
  system.stateVersion = "23.11";

  services.logind.powerKey = "ignore";
  services.logind.powerKeyLongPress = "poweroff";
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id.indexOf("org.freedesktop.login1.suspend" == 0)
        || action.id.indexOf("org.freedesktop.login1.reboot" == 0)
        || action.id.indexOf("org.freedesktop.login1.power-off" == 0)
        || action.id.indexOf("org.freedesktop.inhibit") == 0)
      && subject.user == "${config.common.mainUsername}")
      {
        return polkit.Result.YES;
      }
    });
  '';

  systemd.services.disable-fbcon-blink = {
    script = "echo 0 > /sys/class/graphics/fbcon/cursor_blink";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    wantedBy = [ "multi-user.target" ];
  };

  security.loginDefs.settings.LOGIN_TIMEOUT = 300;
  phone.buffyboard.enable = true;
  phone.rndis.enable = true;
  common.minimal = true;
  common.binaryCache.enable = true;
  services.dbus.enable = true;
  services.sshd.enable = true;
  # seems to use more battery than it saves because of the CPU usage
  # services.tlp.enable = true;
  users.defaultUserShell = pkgs.bash;
  services.speechd.enable = false;

  # kde connect
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 1714;
      to = 1764;
    }
  ];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 1714;
      to = 1764;
    }
  ];

  # services.xserver.displayManager.startx.enable = true;
  # services.xserver.windowManager.awesome.enable = true;
  programs.sway.enable = true;
  programs.sway.extraPackages = [ ];
  programs.sway.xwayland.enable = false;
  xdg.portal.enable = lib.mkForce false;
  xdg.portal.wlr.enable = lib.mkForce false;

  services.upower.enable = true;
  services.pipewire.enable = false;
  environment.pathsToLink = [ "/share/fonts" ];
  environment.systemPackages = with pkgs; [ patchelf powertop ];
}
