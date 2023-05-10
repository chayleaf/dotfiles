{ config, lib, ... }:

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
          type = with types; listOf (either path attrs);
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
    # why is this not part of base NixOS?
    systemd.tmpfiles.rules = [ "d /var/lib/systemd/pstore 0755 root root 14d" ];
    # as weird as it sounds, I won't use tmpfs for /tmp in case I'll have to put files over 2GB there
    boot.tmp.cleanOnBoot = lib.mkIf cfg.persistTmp true;
    environment.persistence.${toString cfg.path} = {
      hideMounts = true;
      directories = map (x:
        if builtins.isPath x then toString x
        else if builtins.isAttrs x && x?directory && builtins.isPath x.directory then x // { directory = toString x.directory; }
        else x)
      ([
        # nixos files
        { directory = /etc/nixos; user = "root"; group = "root"; mode = "0755"; }
        { directory = /var/lib/nixos; user = "root"; group = "root"; mode = "0755"; }

        { directory = /var/log; user = "root"; group = "root"; mode = "0755"; }

        # persist this since everything here is cleaned up by systemd-tmpfiles over time anyway
        # ...or so I'd like to believe
        { directory = /var/lib/systemd; user = "root"; group = "root"; mode = "0755"; }
        { directory = /var/tmp; user = "root"; group = "root"; mode = "1777"; }
        { directory = /var/spool; user = "root"; group = "root"; mode = "0777"; }
      ] ++ (lib.optionals cfg.persistTmp [
        { directory = /tmp; user = "root"; group = "root"; mode = "1777"; }
      ]) ++ (lib.optionals config.services.mullvad-vpn.enable [
        { directory = /etc/mullvad-vpn; user = "root"; group = "root"; mode = "0700"; }
        { directory = /var/cache/mullvad-vpn; user = "root"; group = "root"; mode = "0755"; }
      ]) ++ (lib.optionals config.virtualisation.libvirtd.enable ([
        # { directory = /var/cache/libvirt; user = "root"; group = "root"; mode = "0755"; }
        { directory = /var/lib/libvirt; user = "root"; group = "root"; mode = "0755"; }
      ] ++ (lib.optionals config.virtualisation.libvirtd.qemu.swtpm.enable [
        { directory = /var/lib/swtpm-localca; user = "root"; group = "root"; mode = "0750"; }
      ]))) ++ (lib.optionals config.networking.wireless.iwd.enable [
        { directory = /var/lib/iwd; user = "root"; group = "root"; mode = "0700"; }
      ]) ++ (lib.optionals (builtins.any (x: x.useDHCP) (builtins.attrValues config.networking.interfaces) || config.networking.useDHCP) [
        { directory = /var/db/dhcpcd; user = "root"; group = "root"; mode = "0755"; }
      ]) ++ (lib.optionals config.services.gitea.enable [
        { directory = /var/lib/gitea; user = "gitea"; group = "gitea"; mode = "0755"; }
      ]) ++ (lib.optionals config.services.matrix-synapse.enable [
        { directory = /var/lib/matrix-synapse; user = "matrix-synapse"; group = "matrix-synapse"; mode = "0700"; }
      ]) ++ (lib.optionals config.services.heisenbridge.enable [
        { directory = /var/lib/heisenbridge; user = "heisenbridge"; group = "heisenbridge"; mode = "0755"; }
      ]) ++ (lib.optionals config.services.murmur.enable [
        { directory = /var/lib/murmur; user = "murmur"; group = "murmur"; mode = "0700"; }
      ]) ++ (lib.optionals config.services.nextcloud.enable [
        { directory = /var/lib/nextcloud; user = "nextcloud"; group = "nextcloud"; mode = "0750"; }
      ]) ++ (lib.optionals config.services.botamusique.enable [
        { directory = /var/lib/private/botamusique; user = "root"; group = "root"; mode = "0750"; }
      ]) ++ (lib.optionals config.security.acme.acceptTerms [
        { directory = /var/lib/acme; user = "acme"; group = "acme"; mode = "0755"; }
      ]) ++ (lib.optionals config.services.printing.enable [
        { directory = /var/lib/cups; user = "root"; group = "root"; mode = "0755"; }
      ]) ++ (lib.optionals config.services.fail2ban.enable [
        { directory = /var/lib/fail2ban; user = "fail2ban"; group = "fail2ban"; mode = "0750"; }
      ]) ++ (lib.optionals config.services.opendkim.enable [
        { directory = /var/lib/opendkim; user = "opendkim"; group = "opendkim"; mode = "0700"; }
      ]) ++ (lib.optionals config.services.pleroma.enable [
        { directory = /var/lib/pleroma; user = "pleroma"; group = "pleroma"; mode = "0700"; }
      ]) ++ (lib.optionals config.services.postfix.enable [
        { directory = /var/lib/postfix; user = "root"; group = "root"; mode = "0755"; }
      ]) ++ (lib.optionals config.services.postgresql.enable [
        { directory = /var/lib/postgresql; user = "postgres"; group = "postgres"; mode = "0755"; }
      ]) ++ (lib.optionals config.services.unbound.enable [
        { directory = /var/lib/unbound; user = "unbound"; group = "unbound"; mode = "0755"; }
      ]) ++ (lib.optionals config.services.roundcube.enable [
        { directory = /var/lib/roundcube; user = "roundcube"; group = "roundcube"; mode = "0700"; }
      ]) ++ (lib.optionals config.services.rspamd.enable [
        { directory = /var/lib/rspamd; user = "rspamd"; group = "rspamd"; mode = "0700"; }
      ]) ++ (lib.optionals (
        (builtins.hasAttr "rspamd" config.services.redis.servers)
        && (builtins.hasAttr "enable" config.services.redis.servers.rspamd)
        && config.services.redis.servers.rspamd.enable
      ) [
        { directory = /var/lib/redis-rspamd; user = "redis-rspamd"; group = "redis-rspamd"; mode = "0700"; }
      ]) ++ (lib.optionals config.services.dovecot2.enable [
        { directory = /var/lib/dhparams; user = "root"; group = "root"; mode = "0755"; }
        { directory = /var/lib/dovecot; user = "root"; group = "root"; mode = "0755"; }
      ]) ++ (lib.optionals config.security.sudo.enable [
        { directory = /var/db/sudo/lectured; user = "root"; group = "root"; mode = "0700"; }
      ]) ++ cfg.directories);
      files = map toString ([
        # hardware-related
        /etc/adjtime
        # needed at least for /var/log
        /etc/machine-id
      ] ++ cfg.files);
    };
  };
}
