{ config, lib, pkgs, ... }:

let
  cfg = config.networking.modemmanager;
  packages = [ pkgs.modemmanager ];
in
{
  options.networking.modemmanager = {
    enable = lib.mkEnableOption "ModemManager";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.networking.networkmanager.enable;
        message = "If you use NetworkManager, this module is redundant";
      }
    ];

    environment.etc = builtins.listToAttrs
      (map ({ id, path }: { name = "ModemManager/fcc-unlock.d/${id}"; value.source = path; })
        config.networking.networkmanager.fccUnlockScripts);

    users.groups.networkmanager.gid = config.ids.gids.networkmanager;

    systemd.services.ModemManager.aliases = [ "dbus-org.freedesktop.ModemManager1.service" ];

    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("networkmanager") && (action.id.indexOf("org.freedesktop.ModemManager") == 0)) {
          return polkit.Result.YES;
        }
      });
    '';

    environment.systemPackages = packages;
    systemd.packages = packages;
    services.udev.packages = packages;
  };
}
