{ lib
, pkgs
, config
, ... }:

let
  cfg = config.server;

  hostedDomains =
    builtins.concatLists
      (builtins.attrValues
        (builtins.mapAttrs
          (k: v: [ k ] ++ v.serverAliases)
          config.services.nginx.virtualHosts));
in {
  imports = [
    ./options.nix
    ./akkoma.nix
    ./certspotter.nix
    ./fdroid.nix
    ./files.nix
    ./home.nix
    ./keycloak.nix
    ./mailserver.nix
    ./matrix.nix
    ./mumble.nix
    ./searxng.nix
  ];

  system.stateVersion = "22.11";
  impermanence.directories = [
    { directory = /var/www; }
    { directory = /secrets; mode = "0755"; }
  ];
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
  networking.hosts."127.0.0.1" = hostedDomains;
  networking.hosts."::1" = hostedDomains;

  services.postgresql.enable = true;
  services.postgresql.package = pkgs.postgresql_16;

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
  services.nginx.commonHttpConfig = ''
    log_format postdata '{\"ip\":\"$remote_addr\",\"time\":\"$time_iso8601\",\"referer\":\"$http_referer\",\"body\":\"$request_body\",\"ua\":\"$http_user_agent\"}';

    ${lib.concatMapStringsSep "\n" (x: "set_real_ip_from ${x};") (lib.splitString "\n" ''
      ${builtins.readFile (builtins.fetchurl {
        url = "https://www.cloudflare.com/ips-v4";
        sha256 = "0ywy9sg7spafi3gm9q5wb59lbiq0swvf0q3iazl0maq1pj1nsb7h";
      })}
      ${builtins.readFile (builtins.fetchurl {
        url = "https://www.cloudflare.com/ips-v6";
        sha256 = "1ad09hijignj6zlqvdjxv7rjj8567z357zfavv201b9vx3ikk7cy";
      })}'')}
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

  /*locations."/dns-query".extraConfig = ''
    grpc_pass grpc://127.0.0.1:53453;
  '';*/

  # TODO: firefox sync?
}
