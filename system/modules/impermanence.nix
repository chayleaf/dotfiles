{ config, lib, pkgs, ... }:

let
  cfg = config.impermanence;
in {
  options.impermanence = with lib; mkOption {
    type = types.submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable impermanence";
        };
        path = mkOption {
          type = types.path;
          description = "Default path for persistence";
        };
        directories = mkOption {
          type = with types; listOf path;
          default = [ ];
          description = "Extra directories to persist";
        };
        files = mkOption {
          type = with types; listOf path;
          default = [ ];
          description = "Extra files to persist";
        };
        persistTmp = mkOption {
          type = types.bool;
          default = true;
          description = "Persist /tmp (and clean on boot)";
        };
      };
    };
    description = "Impermanence settings";
    default = { };
  };
  config = lib.mkIf cfg.enable {
    # as weird as it sounds, I won't use tmpfs for /tmp in case I'll have to put files over 2GB there
    boot.cleanTmpDir = lib.mkIf cfg.persistTmp true;
    environment.persistence.${toString cfg.path} = {
      hideMounts = true;
      directories = map toString ([
        # nixos files
        /etc/nixos
        /var/lib/nixos

        /var/log

        # persist this since everything here is cleaned up by systemd-tmpfiles over time anyway
        # ...or so I'd like to believe
        /var/lib/systemd
        /var/tmp
      ] ++ (lib.optionals cfg.persistTmp [
        /tmp
      ]) ++ (lib.optionals config.services.mullvad-vpn.enable [
        /etc/mullvad-vpn
        /var/cache/mullvad-vpn
      ]) ++ (lib.optionals config.virtualisation.libvirtd.enable ([
        /var/cache/libvirt
        /var/lib/libvirt
      ] ++ (lib.optionals config.virtualisation.libvirtd.qemu.swtpm.enable [
        /var/lib/swtpm-localca
      ]))) ++ (lib.optionals config.networking.wireless.iwd.enable [
        /var/lib/iwd
      ]) ++ (lib.optionals (builtins.any (x: x.useDHCP) (builtins.attrValues config.networking.interfaces) || config.networking.useDHCP) [
        /var/db/dhcpcd
      ]) ++ (lib.optionals config.security.sudo.enable [
        /var/db/sudo/lectured
      ]) ++ cfg.directories);
      files = map toString ([
        # hardware-related
        /etc/adjtime
        /etc/machine-id
      ] ++ cfg.files);
    };
  };
}
