{ lib
, pkgs
, config
, ... }:

let
  cfg = config.server;

  hosted-domains =
    builtins.concatLists
      (builtins.attrValues
        (builtins.mapAttrs
          (k: v: [ k ] ++ v.serverAliases)
          config.services.nginx.virtualHosts));
in {
  imports = [
    ./options.nix
    ./matrix.nix
    ./fdroid.nix
    ./mumble.nix
    ./mailserver.nix
    ./home.nix
  ];

  system.stateVersion = "22.11";
  impermanence.directories = [
    { directory = /var/www; }
    { directory = /secrets; mode = "0755"; }
  ];
  networking.useDHCP = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = lib.mkMerge [
      [
        # ssh
        22
        # http/s
        80 443
      ]
      (lib.mkIf config.services.unbound.enable [
        # dns
        53 853
      ])
    ];
    allowedUDPPorts = lib.mkIf config.services.unbound.enable [
      # dns
      53 853
      # quic
      443
    ];
  };

  # UNBOUND
  users.users.${config.common.mainUsername}.extraGroups = lib.mkIf config.services.unbound.enable [ config.services.unbound.group ];

  networking.resolvconf.extraConfig = lib.mkIf config.services.unbound.enable ''
    name_servers="127.0.0.1 ::1"
  '';
  services.unbound = {
    enable = false;
    package = pkgs.unbound-with-systemd.override {
      stdenv = pkgs.ccacheStdenv;
      withPythonModule = true;
      python = pkgs.python3;
    };
    localControlSocketPath = "/run/unbound/unbound.ctl";
    resolveLocalQueries = false;
    settings = {
      server = {
        interface = [ "0.0.0.0" "::" ];
        access-control =  [ "0.0.0.0/0 allow" "::/0 allow" ];
        aggressive-nsec = true;
        do-ip6 = true;
      };
      remote-control.control-enable = true;
    };
  };
  # just in case
  networking.hosts."127.0.0.1" = hosted-domains;
  networking.hosts."::1" = hosted-domains;

  services.postgresql.enable = true;
  services.postgresql.package = pkgs.postgresql_13;

  # SSH
  services.openssh.enable = true;
  services.fail2ban = {
    enable = true;
    ignoreIP = lib.optionals (cfg.lanCidrV4 != "0.0.0.0/0") [ cfg.lanCidrV4 ]
                ++ (lib.optionals (cfg.lanCidrV6 != "::/0") [ cfg.lanCidrV6 ]);
    maxretry = 10;
    jails.dovecot = ''
      enabled = true
      filter = dovecot
    '';
  };

  # SEARXNG
  services.searx.enable = true;
  services.searx.package = pkgs.searxng;
  services.searx.runInUwsgi = true;
  services.searx.uwsgiConfig = let inherit (config.services.searx) settings; in {
    socket = "${lib.quoteListenAddr settings.server.bind_address}:${toString settings.server.port}";
  };
  services.searx.environmentFile = /var/lib/searx/searx.env;
  services.searx.settings = {
    use_default_settings = true;
    search = {
        safe_search = 0;
        autocomplete = "duckduckgo"; # dbpedia, duckduckgo, google, startpage, swisscows, qwant, wikipedia - leave blank to turn off
        default_lang = ""; # leave blank to detect from browser info or use codes from languages.py
    };

    server = {
      port = 8888;
      bind_address = "::1";
      secret_key = "@SEARX_SECRET_KEY@";
      base_url = "https://search.${cfg.domainName}/";
      image_proxy = true;
      default_http_headers = {
        X-Content-Type-Options = "nosniff";
        X-XSS-Protection = "1; mode=block";
        X-Download-Options = "noopen";
        X-Robots-Tag = "noindex, nofollow";
        Referrer-Policy = "no-referrer";
      };
    };
    outgoing = {
      request_timeout = 5.0;       # default timeout in seconds, can be override by engine
      max_request_timeout = 15.0;  # the maximum timeout in seconds
      pool_connections = 100;      # Maximum number of allowable connections, or null
      pool_maxsize = 10;           # Number of allowable keep-alive connections, or null
      enable_http2 = true;         # See https://www.python-httpx.org/http2/
    };
  };

  services.nginx.virtualHosts."search.${cfg.domainName}" = let inherit (config.services.searx) settings; in {
    quic = true;
    enableACME = true;
    forceSSL = true;
    # locations."/".proxyPass = "http://${lib.quoteListenAddr settings.server.bind_address}:${toString settings.server.port}";
    locations."/".extraConfig = ''
      uwsgi_pass "${lib.quoteListenAddr settings.server.bind_address}:${toString settings.server.port}";
      include ${config.services.nginx.package}/conf/uwsgi_params;
    '';
  };

  # NGINX
  services.nginx.enable = true;
  services.nginx.enableReload = true;
  services.nginx.package = pkgs.nginxQuic;
  /* DNS over TLS
  services.nginx.streamConfig =
    let
      inherit (config.security.acme.certs."${cfg.domainName}") directory;
    in ''
      upstream dns {
        zone dns 64k;
        server 127.0.0.1:53;
      }
      server {
        listen 853 ssl;
        ssl_certificate ${directory}/fullchain.pem;
        ssl_certificate_key ${directory}/key.pem;
        ssl_trusted_certificate ${directory}/chain.pem;
        proxy_pass dns;
      }
    '';*/
    services.nginx.commonHttpConfig =
    let
      realIpsFromList = lib.strings.concatMapStringsSep "\n" (x: "set_real_ip_from  ${x};");
      fileToList = x: lib.strings.splitString "\n" (builtins.readFile x);
      cfipv4 = fileToList (pkgs.fetchurl {
        url = "https://www.cloudflare.com/ips-v4";
        sha256 = "0ywy9sg7spafi3gm9q5wb59lbiq0swvf0q3iazl0maq1pj1nsb7h";
      });
      cfipv6 = fileToList (pkgs.fetchurl {
        url = "https://www.cloudflare.com/ips-v6";
        sha256 = "1ad09hijignj6zlqvdjxv7rjj8567z357zfavv201b9vx3ikk7cy";
      });
    in
    ''
      log_format postdata '{\"ip\":\"$remote_addr\",\"time\":\"$time_iso8601\",\"referer\":\"$http_referer\",\"body\":\"$request_body\",\"ua\":\"$http_user_agent\"}';

      ${realIpsFromList cfipv4}
      ${realIpsFromList cfipv6}
      real_ip_header CF-Connecting-IP;
  '';
  # brotli and zstd requires recompilation so I don't enable it
  # services.nginx.recommendedBrotliSettings = true;
  # services.nginx.recommendedZstdSettings = true;
  services.nginx.recommendedGzipSettings = true;
  services.nginx.recommendedOptimisation = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings = true;

  # BLOG
  services.nginx.virtualHosts.${cfg.domainName} = {
    quic = true;
    enableACME = true;
    serverAliases = [ "www.${cfg.domainName}" ];
    forceSSL = true;
    extraConfig = "autoindex on;";
    locations."/".root = "/var/www/${cfg.domainName}/";
    locations."/src".root = "/var/www/${cfg.domainName}/";
    locations."/src".extraConfig = "index force_dirlisting;";
    locations."/submit_comment".extraConfig = ''
      access_log /var/log/nginx/comments.log postdata;
      proxy_pass https://${cfg.domainName}/submit.htm;
      break;
    '';
    locations."/submit.htm" = {
      extraConfig = ''
        return 200 '<!doctype html><html><head><base href="/"/><link rel="preload" href="style.css" as="style"><title>Success!</title><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><link rel="icon" type="image/jpeg" href="pfp.jpg"><link rel="alternate" type="application/rss+xml" title="RSS" href="https://${cfg.domainName}/blog/index.xml"><link href="style.css" rel="stylesheet" /><script src="main.js"></script><meta http-equiv="refresh" content="10; url=$http_referer" /></head><body onload="documentLoaded()"><hr/><div class="main-body"><p>Success! It may take a while for your comment to get moderated.</p><p>Please wait for 10 seconds until you get redirected back...</p><p>Or just go there <a href="$http_referer">manually</a>.</p></div><hr/></body></html>';
      '';
    };
  };

  # GITEA
  services.nginx.virtualHosts."git.${cfg.domainName}" = let inherit (config.services.gitea) settings; in {
    quic = true;
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://${lib.quoteListenAddr settings.server.HTTP_ADDR}:${toString settings.server.HTTP_PORT}";
  };
  services.gitea = {
    enable = true;
    database = {
      createDatabase = false;
      passwordFile = "/var/lib/gitea/db_password";
      type = "postgres";
    };
    settings = {
      mailer = {
        ENABLED = true;
        FROM = "Gitea <noreply@${cfg.domainName}>";
        MAILER_TYPE = "smtp";
        HOST = "mail.${cfg.domainName}:587";
        USER = "noreply@${cfg.domainName}";
        PASSWD = cfg.unhashedNoreplyPassword;
        SKIP_VERIFY = true;
      };
      session = {
        COOKIE_SECURE = true;
      };
      server = {
        ROOT_URL = "https://git.${cfg.domainName}";
        HTTP_ADDR = "::1";
        HTTP_PORT = 3310;
        DOMAIN = "git.${cfg.domainName}";
        # START_SSH_SERVER = true;
        # SSH_PORT = 2222;
      };
      service = {
        DISABLE_REGISTRATION = true;
        REGISTER_EMAIL_CONFIRM = true;
      };
    };
  };

  # NEXTCLOUD
  services.nginx.virtualHosts."cloud.${cfg.domainName}" = {
    quic = true;
    enableACME = true;
    forceSSL = true;
  };
  services.nextcloud = {
    enable = true;
    enableBrokenCiphersForSSE = false;
    package = pkgs.nextcloud27;
    autoUpdateApps.enable = true;
    # TODO: use socket auth and remove the next line
    database.createLocally = false;
    config = {
      adminpassFile = "/var/lib/nextcloud/admin_password";
      dbpassFile = "/var/lib/nextcloud/db_password";
      dbtype = "pgsql";
      dbhost = "/run/postgresql";
      overwriteProtocol = "https";
    };
    hostName = "cloud.${cfg.domainName}";
    https = true;
  };

  services.akkoma = {
    enable = true;
    config.":pleroma"."Pleroma.Web.Endpoint" = {
      url = {
        scheme = "https";
        host = "pleroma.${cfg.domainName}";
        port = 443;
      };
      secret_key_base._secret = "/secrets/akkoma/secret_key_base";
      signing_salt._secret = "/secrets/akkoma/signing_salt";
      live_view.signing_salt._secret = "/secrets/akkoma/live_view_signing_salt";
    };
    extraStatic."static/terms-of-service.html" = pkgs.writeText "terms-of-service.html" ''
      no bigotry kthx
    '';
    initDb = {
      enable = false;
      username = "pleroma";
      password._secret = "/secrets/akkoma/postgres_password";
    };
    config.":pleroma".":instance" = {
      name = cfg.domainName;
      description = "Insert instance description here";
      email = "webmaster-akkoma@${cfg.domainName}";
      notify_email = "noreply@${cfg.domainName}";
      limit = 5000;
      registrations_open = true;
    };
    config.":pleroma"."Pleroma.Repo" = {
      adapter = (pkgs.formats.elixirConf { }).lib.mkRaw "Ecto.Adapters.Postgres";
      username = "pleroma";
      password._secret = "/secrets/akkoma/postgres_password";
      database = "pleroma";
      hostname = "localhost";
    };
    config.":web_push_encryption".":vapid_details" = {
      subject = "mailto:webmaster-akkoma@${cfg.domainName}";
      public_key._secret = "/secrets/akkoma/push_public_key";
      private_key._secret = "/secrets/akkoma/push_private_key";
    };
    config.":joken".":default_signer"._secret = "/secrets/akkoma/joken_signer";
    nginx = {
      serverAliases = [ "akkoma.${cfg.domainName}" ];
      quic = true;
      enableACME = true;
      forceSSL = true;
    };
  };
  systemd.services.akkoma.path = [ pkgs.exiftool pkgs.gawk ];
  systemd.services.akkoma.serviceConfig = {
    Restart = "on-failure";
  };
  systemd.services.akkoma.unitConfig = {
    StartLimitIntervalSec = 60;
    StartLimitBurst = 3;
  };

  /*locations."/dns-query".extraConfig = ''
    grpc_pass grpc://127.0.0.1:53453;
  '';*/

  # TODO: firefox sync?
}
