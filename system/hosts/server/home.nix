{ config
, lib
, pkgs
, ... }:

let
  cfg = config.server;
  synapseMetricsPort = 8009;
  synapseMetricsAddr = "127.0.0.1";
  collectListeners = names:
    map
      (x: "127.0.0.1:${toString x.port}")
      (builtins.attrValues
        (lib.filterAttrs (k: v: builtins.elem k names && v.enable) config.services.prometheus.exporters));
in {
  # a bunch of services for personal use not intended for the public
  # TODO: keycloakify this
  services.grafana = {
    enable = true;
    settings = {
      "auth.basic".enabled = false;
      # nginx login is used so this is fine, hopefully
      "auth.anonymous" = {
        enabled = true;
        # org_role = "Admin";
      };
      server.root_url = "https://home.${cfg.domainName}/grafana/";
      server.domain = "home.${cfg.domainName}";
      server.http_addr = "127.0.0.1";
      server.protocol = "socket";
      security.admin_user = "chayleaf";
      security.admin_password = "$__file{/secrets/grafana_password_file}";
      security.secret_key = "$__file{/secrets/grafana_key_file}";
    };
  };
  services.nginx.upstreams.grafana.servers."unix:/${config.services.grafana.settings.server.socket}" = {};

  # TODO: 
  # services.keycloak.plugins = [ pkgs.keycloak.plugins.keycloak-metrics-spi ];
  services.keycloak.settings.metrics-enabled = true;

  services.nginx.virtualHosts."home.${cfg.domainName}" = {
    quic = true;
    enableACME = true;
    forceSSL = true;
    basicAuthFile = "/secrets/home_password";
    extraConfig = ''
      satisfy any;
      ${lib.optionalString (cfg.lanCidrV4 != "0.0.0.0/0") "allow ${cfg.lanCidrV4};"}
      ${lib.optionalString (cfg.lanCidrV6 != "::/0") "allow ${cfg.lanCidrV6};"}
      deny all;
    '';
    # locations."/.well-known/acme-challenge".extraConfig = "auth_basic off;";
    locations."/".root = "/var/www/home.${cfg.domainName}/";
    locations."/scan/".proxyPass = "http://${lib.quoteListenAddr config.services.scanservjs.settings.host}:${toString config.services.scanservjs.settings.port}/";
    locations."/grafana/" = {
      proxyPass = "http://grafana/";
      proxyWebsockets = true;
    };
    locations."/grafana/public/".alias = "${config.services.grafana.settings.server.static_root_path}/";
    locations."/printer/" = {
      proxyPass = "http://127.0.0.1:631/";
      proxyWebsockets = true;
    };
  };
  services.nginx.virtualHosts."hydra.${cfg.domainName}" = {
    quic = true;
    enableACME = true;
    forceSSL = true;
    basicAuthFile = "/secrets/home_password";
    extraConfig = ''
      satisfy any;
      ${lib.optionalString (cfg.lanCidrV4 != "0.0.0.0/0") "allow ${cfg.lanCidrV4};"}
      ${lib.optionalString (cfg.lanCidrV6 != "::/0") "allow ${cfg.lanCidrV6};"}
      deny all;
      proxy_read_timeout 300;
      proxy_connect_timeout 300;
      proxy_send_timeout 300;
      client_body_timeout 300;
      send_timeout 300;
    '';
    locations."/".proxyPass = "http://${lib.quoteListenAddr config.services.hydra.listenHost}:${toString config.services.hydra.port}/";
    locations."/static/".root = lib.mkIf config.services.hydra.enable "${config.services.hydra.package}/libexec/hydra/root/";
  };
  users.users.nginx.extraGroups = [ "grafana" ];

  services.harmonia = {
    enable = true;
    signKeyPath = "/secrets/cache-priv-key.pem";
    settings.bind = "[::1]:5000";
  };
  nix.settings.allowed-users = [ "nix-serve" "harmonia" "hydra" "hydra-www" ];
  # make sure only hydra has access to this file
  # so normal nix evals don't have access to builtins
  nix.settings.extra-builtins-file = "/etc/nixos/extra-builtins.nix";
  impermanence.directories = [
    { directory = /etc/nixos; user = "hydra"; group = "hydra"; mode = "0700"; }
  ];
  nix.settings.allowed-uris = [
    # required for home-manager
    "https://git.sr.ht/~rycee/nmd/"
    # required for server (I suppose since nvfetcher uses fetchTarball here...)
    "https://github.com/searxng/searxng/"
    # required for home config (nvfetcher again)
    "https://api.github.com/repos/FAForever/"
  ];
  services.nginx.virtualHosts."binarycache.${cfg.domainName}" = {
    quic = true;
    enableACME = true;
    forceSSL = true;
    basicAuthFile = "/secrets/home_password";
    locations."/".proxyPass = "http://${config.services.harmonia.settings.bind or "[::1]:5000"}";
    locations."/".extraConfig = ''
      proxy_set_header Host $host;
      proxy_http_version 1.1;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection $connection_upgrade;
      location ~ "^/nar/([a-z0-9]{32})-.*\.narinfo$" {
        proxy_pass http://127.0.0.1:5000/$1.narinfo$is_args$args;
      }
    '';
    # zstd on;
    # zstd_types application/x-nix-archive;
  };

  services.hydra = {
    enable = true;
    hydraURL = "home.${cfg.domainName}/hydra";
    listenHost = "127.0.0.1";
    minimumDiskFree = 30;
    notificationSender = "noreply@${cfg.domainName}";
    # smtpHost = "mail.${cfg.domainName}";
    useSubstitutes = true;
  };
  boot.binfmt.emulatedSystems = builtins.filter (x: x != pkgs.system) [ "aarch64-linux" "x86_64-linux" ];
  nix.buildMachines = [
    {
      # there were some bugs related to not specifying the machine
      # not sure they're still there, but it surely won't hurt
      hostName = "localhost";
      protocol = null;
      maxJobs = 8;
      supportedFeatures = [ "kvm" "local" "nixos-test" "benchmark" "big-parallel" ];
      systems = [ "builtin" "x86_64-linux" "aarch64-linux" ];
    }
  ];
  # limit CI CPU usage since I'm running everything else off this server too
  systemd.services.nix-daemon.serviceConfig.CPUQuota = "100%";
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  systemd.services.hydra-evaluator = lib.mkIf config.services.hydra.enable {
    serviceConfig.CPUQuota = "100%";
    serviceConfig.CPUSchedulingPolicy = "idle";
    serviceConfig.IOSchedulingClass = "idle";
  };
  programs.ccache.enable = true;

  services.nginx.statusPage = true;
  services.gitea.settings.metrics.ENABLED = true;
  services.akkoma.config.":prometheus"."Pleroma.Web.Endpoint.MetricsExporter" = {
    enabled = true;
    auth = [ ((pkgs.formats.elixirConf { }).lib.mkRaw ":basic") "prometheus" {
      _secret = "/secrets/akkoma/prometheus_password";
    } ];
    ip_whitelist = ["127.0.0.1"];
    path = "/api/pleroma/app_metrics";
    format = (pkgs.formats.elixirConf { }).lib.mkRaw ":text";
  };
  services.prometheus = {
    enable = true;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "logind" "systemd" ];
        listenAddress = "127.0.0.1";
        port = 9101; # cups is 9100
      };
      dovecot = {
        enable = true;
        scopes = [ "user" "global" ];
        listenAddress = "127.0.0.1";
      };
      nextcloud = {
        enable = true;
        url = "https://cloud.${cfg.domainName}";
        username = "nextcloud-exporter";
        passwordFile = "/secrets/nextcloud_exporter_password";
        listenAddress = "127.0.0.1";
      };
      nginx = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      nginxlog = {
        enable = true;
        group = "nginx";
        settings.namespaces = [
          {
            name = "comments";
            format = "{\"ip\":\"$remote_addr\",\"time\":\"$time_iso8601\",\"referer\":\"$http_referer\",\"body\":\"$request_body\",\"ua\":\"$http_user_agent\"}";
            source.files = [ "/var/log/nginx/comments.log" ];
          }
        ];
        listenAddress = "127.0.0.1";
      };
      postfix = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      postgres = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      process = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      redis = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      rspamd = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      smartctl = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
    };
    checkConfig = "syntax-only";
    scrapeConfigs = [
      {
        job_name = "local_frequent";
        scrape_interval = "1m";
        static_configs = [ {
          targets = collectListeners [
            "node"
            "nginx"
            "process"
          ];
          labels.machine = "server";
        } ];
      }
      {
        job_name = "local_medium_freq";
        scrape_interval = "15m";
        static_configs = [ {
          targets = [ "127.0.0.1:9548" "127.0.0.1:9198" ];
          labels.machine = "server";
        } ];
      }
      {
        job_name = "local_infrequent";
        scrape_interval = "1h";
        static_configs = [ {
          targets = collectListeners [
            "dovecot"
            "nextcloud"
            "nginxlog"
            "postfix"
            "postgres"
            "redis"
            "rspamd"
            "smartctl"
          ];
          labels.machine = "server";
        } ];
      }
      {
        job_name = "gitea";
        bearer_token_file = "/secrets/prometheus_bearer";
        scrape_interval = "1h";
        static_configs = [ {
          targets = [ "git.${cfg.domainName}" ];
          labels.machine = "server";
        } ];
      }
      {
        job_name = "router_frequent";
        scrape_interval = "1m";
        static_configs = [ {
          targets = [
            "retracker.local:9101"
            "retracker.local:9256"
            "retracker.local:9167"
          ];
          labels.machine = "router";
        } ];
      }
      {
        job_name = "router_infrequent";
        scrape_interval = "10m";
        static_configs = [ {
          targets = [
            "retracker.local:9430"
            "retracker.local:9547"
          ];
          labels.machine = "router";
        } ];
      }
      {
        job_name = "synapse";
        metrics_path = "/_synapse/metrics";
        scrape_interval = "15s";
        static_configs = [ {
          targets = [ "${lib.quoteListenAddr synapseMetricsAddr}:${toString synapseMetricsPort}" ];
          labels.machine = "server";
        } ];
      }
      {
        job_name = "akkoma";
        metrics_path = "/api/pleroma/app_metrics";
        scrape_interval = "10m";
        basic_auth.username = "prometheus";
        basic_auth.password_file = "/secrets/akkoma/prometheus_password";
        static_configs = [ {
          targets = [ "pleroma.${cfg.domainName}" ];
          labels.machine = "server";
        } ];
      }
    ];
  };
  services.matrix-synapse.settings = {
    enable_metrics = true;
    federation_metrics_domains = [ "matrix.org" ];
    /*
    normally you're supposed to use
    - port: 9000
      type: metrics
      bind_addresses: ['::1', '127.0.0.1']

    but the NixOS module doesn't allow creating such a listener
    */
    listeners = [ {
      port = synapseMetricsPort;
      bind_addresses = [ synapseMetricsAddr ];
      type = "metrics";
      tls = false;
      resources = [ ];
    } ];
  };

  /*
  # this uses elasticsearch, rip
  services.parsedmarc = {
    enable = true;
    provision = {
      localMail = {
        enable = true;
        hostname = cfg.domainName;
      };
      grafana = {
        datasource = true;
        dashboard = true;
      };
    };
  };*/

  networking.firewall.allowedTCPPorts = [ 631 ];
  services.printing = {
    enable = true;
    allowFrom = [ cfg.lanCidrV4 cfg.lanCidrV6 ];
    browsing = true;
    clientConf = ''
      ServerName home.${cfg.domainName}
    '';
    listenAddresses = [ "*:631" ];
    defaultShared = true;
    drivers = [ pkgs.hplip ];
    startWhenNeeded = false;
  };
  services.avahi = {
    enable = true;
    hostName = "home";
    publish.enable = true;
    publish.addresses = true;
    publish.userServices = true;
  };
  hardware.sane = {
    enable = true;
    extraBackends = with pkgs; [ hplipWithPlugin ];
  };
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "hplip";
  services.scanservjs.enable = true;
  services.scanservjs.settings.host = "127.0.0.1";
  services.scanservjs.settings.port = 3952;
}
