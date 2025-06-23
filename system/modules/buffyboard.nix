{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.phone;
in
{
  options.phone.buffyboard = {
    enable = lib.mkEnableOption "buffyboard";
  };
  config = lib.mkIf cfg.buffyboard.enable {
    boot.initrd.kernelModules = [
      "uinput"
      "evdev"
    ];
    boot.initrd.extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.buffyboard}/bin/buffyboard
      cp -a ${pkgs.libinput.out}/share $out/
    '';
    boot.initrd.extraUdevRulesCommands = ''
      cp -v ${config.systemd.package}/lib/udev/rules.d/60-input-id.rules $out/
      cp -v ${config.systemd.package}/lib/udev/rules.d/60-persistent-input.rules $out/
      cp -v ${config.systemd.package}/lib/udev/rules.d/70-touchpad.rules $out/
    '';
    boot.initrd.preLVMCommands = ''
      mkdir -p /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-${pkgs.libinput.name}/
      ln -s "$(dirname "$(dirname "$(which buffyboard)")")"/share /nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-${pkgs.libinput.name}/
      buffyboard 2>/dev/null &
    '';
    boot.initrd.postMountCommands = ''
      pkill -x buffyboard
    '';
    systemd.services.buffyboard = {
      description = "buffyboard";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.buffyboard}/bin/buffyboard";
        Restart = "always";
        RestartSec = "1";
      };
    };
    security.sudo.extraRules = [
      {
        groups = [ "users" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl stop buffyboard";
            options = [
              "SETENV"
              "NOPASSWD"
            ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl start buffyboard";
            options = [
              "SETENV"
              "NOPASSWD"
            ];
          }
        ];
      }
    ];
  };
}
