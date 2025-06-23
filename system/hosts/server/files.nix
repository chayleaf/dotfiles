{ config
, lib
, pkgs
, ... }:

let
  cfg = config.server;
in {
  users.users.nginx.extraGroups = [ "anubis" ];
  services.nginx.upstreams.forgejo.servers."unix:/${config.services.anubis.instances.forgejo.settings.BIND}" = {};
  services.nginx.virtualHosts."git.${cfg.domainName}" = {
    quic = true;
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://forgejo/";
  };

  users.users.anubis-forgejo = { group = "anubis"; extraGroups = [ "forgejo" ]; isSystemUser = true; };
  services.anubis.instances.forgejo = {
    user = "anubis-forgejo";
    botPolicy.bots = [
      { import = "(data)/apps/gitea-rss-feeds.yaml"; }
      # { import = "(data)/clients/git.yaml"; }
    ];
    # TODO: ?????????? why is this necessary
    settings.POLICY_FNAME = (pkgs.formats.json {}).generate "policy.json" (let cfg = config.services.anubis.defaultOptions.botPolicy; in cfg // {
      bots = cfg.bots ++ config.services.anubis.instances.forgejo.botPolicy.bots;
    });
    settings.OG_PASSTHROUGH = false;
    # settings.BIND = "[::1]:3311";
    settings.TARGET =
      let inherit (config.services.forgejo) settings;
      in "unix://${lib.quoteListenAddr settings.server.HTTP_ADDR}";
  };

  services.forgejo = {
    enable = true;
    database = {
      createDatabase = false;
      type = "postgres";
      user = "gitea";
      name = "gitea";
      passwordFile = "/secrets/forgejo_db_password";
    };
    lfs.enable = true;
    settings = {
      federation.ENABLED = true;
      "git.timeout" = {
        DEFAULT = 6000;
        MIGRATE = 60000;
        MIRROR = 60000;
        GC = 120;
      };
      mailer = {
        ENABLED = true;
        FROM = "Forgejo <noreply@${cfg.domainName}>";
        PROTOCOL = "smtp";
        SMTP_ADDR = "mail.${cfg.domainName}";
        SMTP_PORT = 587;
        USER = "noreply@${cfg.domainName}";
        PASSWD = cfg.unhashedNoreplyPassword;
        FORCE_TRUST_SERVER_CERT = true;
      };
      session = {
        COOKIE_SECURE = true;
      };
      server = {
        ROOT_URL = "https://git.${cfg.domainName}";
        PROTOCOL = "http+unix";
        # HTTP_ADDR = "::1";
        # HTTP_PORT = 3310;
        DOMAIN = "git.${cfg.domainName}";
        # START_SSH_SERVER = true;
        # SSH_PORT = 2222;
      };
      service = {
        DISABLE_REGISTRATION = true;
        REGISTER_EMAIL_CONFIRM = true;
      };
      cache = {
        ADAPTER = "redis";
        HOST = "redis+socket://${config.services.redis.servers.forgejo.unixSocket}";
      };
    };
  };

  systemd.services.forgejo = {
    wants = [ "redis-forgejo.service" ];
    after = [ "redis-forgejo.service" ];
  };

  users.users.forgejo.extraGroups = [ config.services.redis.servers.forgejo.user ];

  services.redis.servers.forgejo = {
    enable = true;
  };

  services.nginx.virtualHosts."cloud.${cfg.domainName}" = {
    quic = true;
    enableACME = true;
    forceSSL = true;
  };
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud31;
    autoUpdateApps.enable = true;
    # TODO: use socket auth and remove the next line
    database.createLocally = false;
    config = {
      adminpassFile = "/var/lib/nextcloud/admin_password";
      dbpassFile = "/var/lib/nextcloud/db_password";
      dbtype = "pgsql";
      dbhost = "/run/postgresql";
    };
    phpOptions."opcache.interned_strings_buffer" = "16";
    settings.overwriteprotocol = "https";
    hostName = "cloud.${cfg.domainName}";
    https = true;
  };

  services.qbittorrent-nox.enable = true;
  services.qbittorrent-nox.ui.port = 19642;
  services.qbittorrent-nox.torrent.port = 45522;

  services.jellyfin.enable = true;

  services.nginx.virtualHosts."home.${cfg.domainName}".locations = {
    "/torrent/" = {
      extraConfig = ''
        proxy_pass         http://127.0.0.1:${toString config.services.qbittorrent-nox.ui.port}/;
        proxy_http_version 1.1;

        proxy_set_header   Host               127.0.0.1:30000;
        proxy_set_header   X-Forwarded-Host   $http_host;
        proxy_set_header   X-Forwarded-For    $remote_addr;
        proxy_cookie_path  /                  "/; Secure";
      '';
    };
    "/jelly/" = {
      proxyPass = "http://127.0.0.1:8096";
      proxyWebsockets = true;
    };
  };
}
