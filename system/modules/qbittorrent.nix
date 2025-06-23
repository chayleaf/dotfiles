{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.qbittorrent-nox;
in
{
  options.services.qbittorrent-nox = {
    enable = lib.mkEnableOption "qbittorrent-nox";

    package = lib.mkPackageOption pkgs "qbittorrent-nox" { };

    ui.addToFirewall = lib.mkOption {
      description = "Add the web UI port to firewall";
      type = lib.types.bool;
      default = false;
    };
    ui.port = lib.mkOption {
      description = "Web UI port";
      type = lib.types.port;
      default = 8080;
    };

    torrent.addToFirewall = lib.mkOption {
      description = "Add the torrenting port to firewall";
      type = lib.types.bool;
      default = true;
    };
    torrent.port = lib.mkOption {
      description = "Torrenting port";
      type = with lib.types; nullOr port;
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts =
      lib.optional (cfg.torrent.addToFirewall && cfg.torrent.port != null) cfg.torrent.port
      ++ lib.optional cfg.ui.addToFirewall cfg.ui.port;
    networking.firewall.allowedUDPPorts = lib.optional (
      cfg.torrent.addToFirewall && cfg.torrent.port != null
    ) cfg.torrent.port;

    users.users.qbittorrent-nox = {
      isSystemUser = true;
      group = "qbittorrent-nox";
      home = "/var/lib/qbittorrent-nox";
    };
    users.groups.qbittorrent-nox = { };

    systemd.services.qbittorrent-nox = {
      description = "qBittorrent-nox service";
      wants = [ "network-online.target" ];
      after = [
        "local-fs.target"
        "network-online.target"
        "nss-lookup.target"
      ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.Documentation = "man:qbittorrent-nox(1)";
      # required for reverse proxying
      preStart = ''
        if [[ ! -f /var/lib/qbittorrent-nox/qBittorrent/config/qBittorrent.conf ]]; then
          mkdir -p /var/lib/qbittorrent-nox/qBittorrent/config
          echo "Preferences\WebUI\HostHeaderValidation=false" >> /var/lib/qbittorrent-nox/qBittorrent/config/qBittorrent.conf
        fi
      '';
      serviceConfig = {
        User = "qbittorrent-nox";
        Group = "qbittorrent-nox";
        StateDirectory = "qbittorrent-nox";
        WorkingDirectory = "/var/lib/qbittorrent-nox";
        ExecStart = ''
          ${cfg.package}/bin/qbittorrent-nox ${
            lib.optionalString (cfg.torrent.port != null) "--torrenting-port=${toString cfg.torrent.port}"
          } \
            --webui-port=${toString cfg.ui.port} --profile=/var/lib/qbittorrent-nox
        '';
      };
    };
  };
}
