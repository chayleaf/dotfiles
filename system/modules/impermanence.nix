{ config, lib, ... }:

# common impermanence config for all of my hosts

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
          default = throw "You must set path to persistent storage";
          description = "Default path for persistence";
        };
        directories = mkOption {
          type = with types; listOf (either path attrs);
          default = [ ];
          description = "Extra directories to persist";
        };
        files = mkOption {
          type = with types; listOf (either path attrs);
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
    users.mutableUsers = false;
    # why is this not part of base NixOS?
    systemd.tmpfiles.rules = [ "d /var/lib/systemd/pstore 0755 root root 14d" ];
    # as weird as it sounds, I won't use tmpfs for /tmp in case I'll have to put files over 2GB there
    boot.tmp.cleanOnBoot = lib.mkIf cfg.persistTmp true;
    environment.persistence.${toString cfg.path} = {
      hideMounts = true;
      directories = map (x:
        if builtins.isPath x then toString x
        else if builtins.isPath (x.directory or null) then x // { directory = toString x.directory; }
        else x
      ) ([
        # the following two can't be created by impermanence (i.e. they have to exist on disk in stage 1)
        { directory = /var/lib/nixos; user = "root"; group = "root"; mode = "0755"; }
        { directory = /var/log; user = "root"; group = "root"; mode = "0755"; }
        # persist this since everything here is cleaned up by systemd-tmpfiles over time anyway
        # ...or so I'd like to believe
        { directory = /var/lib/systemd; user = "root"; group = "root"; mode = "0755"; }
        { directory = /var/tmp; user = "root"; group = "root"; mode = "1777"; }
        { directory = /var/spool; user = "root"; group = "root"; mode = "0777"; }
      ] ++ lib.optionals cfg.persistTmp [
        { directory = /tmp; user = "root"; group = "root"; mode = "1777"; }
      ] ++ lib.optionals config.services.mullvad-vpn.enable [
        { directory = /etc/mullvad-vpn; user = "root"; group = "root"; mode = "0700"; }
        { directory = /var/cache/mullvad-vpn; user = "root"; group = "root"; mode = "0755"; }
      ] ++ lib.optionals config.virtualisation.libvirtd.enable ([
        # { directory = /var/cache/libvirt; user = "root"; group = "root"; mode = "0755"; }
        { directory = /var/lib/libvirt; user = "root"; group = "root"; mode = "0755"; }
      ] ++ lib.optionals config.virtualisation.libvirtd.qemu.swtpm.enable [
        { directory = /var/lib/swtpm-localca; user = "root"; group = "root"; mode = "0750"; }
      ]) ++ lib.optionals config.networking.wireless.iwd.enable [
        { directory = /var/lib/iwd; user = "root"; group = "root"; mode = "0700"; }
      ] ++ lib.optionals (builtins.any (x: x.useDHCP != false) (builtins.attrValues config.networking.interfaces) || config.networking.useDHCP) [
        { directory = /var/db/dhcpcd; user = "root"; group = "root"; mode = "0755"; }
      ] ++ lib.optionals config.services.gitea.enable [
        { directory = /var/lib/gitea; user = "gitea"; group = "gitea"; mode = "0755"; }
      ] ++ lib.optionals config.services.matrix-synapse.enable [
        { directory = /var/lib/matrix-synapse; user = "matrix-synapse"; group = "matrix-synapse"; mode = "0700"; }
      ] ++ lib.optionals config.services.heisenbridge.enable [
        { directory = /var/lib/heisenbridge; user = "heisenbridge"; group = "heisenbridge"; mode = "0755"; }
      ] ++ lib.optionals config.services.murmur.enable [
        { directory = /var/lib/murmur; user = "murmur"; group = "murmur"; mode = "0700"; }
      ] ++ lib.optionals config.services.nextcloud.enable [
        { directory = /var/lib/nextcloud; user = "nextcloud"; group = "nextcloud"; mode = "0750"; }
      ] ++ lib.optionals config.services.botamusique.enable [
        { directory = /var/lib/private/botamusique; user = "root"; group = "root"; mode = "0750"; }
      ] ++ lib.optionals config.security.acme.acceptTerms [
        { directory = /var/lib/acme; user = "acme"; group = "acme"; mode = "0755"; }
      ] ++ lib.optionals config.services.printing.enable [
        { directory = /var/lib/cups; user = "root"; group = "root"; mode = "0755"; }
        { directory = /var/cache/cups; user = "root"; group = "lp"; mode = "0770"; }
      ] ++ lib.optionals config.services.fail2ban.enable [
        { directory = /var/lib/fail2ban; user = "root"; group = "root"; mode = "0700"; }
      ] ++ lib.optionals config.services.opendkim.enable [
        { directory = /var/lib/opendkim; user = "opendkim"; group = "opendkim"; mode = "0700"; }
      ] ++ lib.optionals config.services.pleroma.enable [
        { directory = /var/lib/pleroma; user = "pleroma"; group = "pleroma"; mode = "0700"; }
      ] ++ lib.optionals config.services.akkoma.enable [
        { directory = /var/lib/akkoma; user = "akkoma"; group = "akkoma"; mode = "0700"; }
      ] ++ lib.optionals config.services.hydra.enable [
        { directory = /var/lib/hydra; user = "hydra"; group = "hydra"; mode = "0755"; }
      ] ++ lib.optionals config.services.grafana.enable [
        { directory = /var/lib/grafana; user = "grafana"; group = "grafana"; mode = "0755"; }
      ] ++ lib.optionals config.services.prometheus.enable [
        { directory = /var/lib/${config.services.prometheus.stateDir}; user = "prometheus"; group = "prometheus"; mode = "0755"; }
      ] ++ lib.optionals config.services.postfix.enable [
        { directory = /var/lib/postfix; user = "root"; group = "root"; mode = "0755"; }
      ] ++ lib.optionals config.services.postgresql.enable [
        { directory = /var/lib/postgresql; user = "postgres"; group = "postgres"; mode = "0755"; }
      ] ++ lib.optionals config.services.unbound.enable [
        { directory = /var/lib/unbound; user = "unbound"; group = "unbound"; mode = "0755"; }
      ] ++ lib.optionals config.services.searx.enable [
        { directory = /var/lib/searx; user = "searx"; group = "searx"; mode = "0700"; }
      ] ++ lib.optionals config.services.roundcube.enable [
        { directory = /var/lib/roundcube; user = "roundcube"; group = "roundcube"; mode = "0700"; }
      ] ++ lib.optionals config.services.rspamd.enable [
        { directory = /var/lib/rspamd; user = "rspamd"; group = "rspamd"; mode = "0700"; }
      ] ++ lib.optionals (config.services.redis.servers.rspamd.enable or false) [
        { directory = /var/lib/redis-rspamd; user = "redis-rspamd"; group = "redis-rspamd"; mode = "0700"; }
      ] ++ lib.optionals config.services.dovecot2.enable [
        { directory = /var/lib/dhparams; user = "root"; group = "root"; mode = "0755"; }
        { directory = /var/lib/dovecot; user = "root"; group = "root"; mode = "0755"; }
      ] ++ lib.optionals config.security.sudo.enable [
        { directory = /var/db/sudo/lectured; user = "root"; group = "root"; mode = "0700"; }
      ] ++ lib.optionals config.services.openldap.enable [
        { directory = /var/lib/openldap; inherit (config.services.openldap) user group; mode = "0755"; }
      ] ++ lib.optionals (config.services.scanservjs.enable or false) [
        { directory = /var/lib/scanservjs; user = "scanservjs"; group = "scanservjs"; mode = "0750"; }
      ] ++ lib.optionals config.programs.ccache.enable [
        { directory = config.programs.ccache.cacheDir; user = "root"; group = "nixbld"; mode = "0770"; }
        { directory = /var/cache/sccache; user = "root"; group = "nixbld"; mode = "0770"; }
      ] ++ cfg.directories);
      files = map (x:
        if builtins.isPath x then toString x
        else if builtins.isPath (x.file or null) then x // { file = toString x.file; }
        else x
      ) ([
        # hardware-related
        /etc/adjtime
        # needed at least for /var/log
        /etc/machine-id
      ] ++ lib.optionals config.services.openssh.enable [
        # keep ssh fingerprints stable
        /etc/ssh/ssh_host_ed25519_key
        /etc/ssh/ssh_host_ed25519_key.pub
        /etc/ssh/ssh_host_rsa_key
        /etc/ssh/ssh_host_rsa_key.pub
      ] ++ cfg.files);
    };
  };
}
