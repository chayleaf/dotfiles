{ lib
, pkgs
, config
, ... }:

let
  cfg = config.server;

  efiPart = "/dev/disk/by-uuid/3E2A-A5CB";
  rootUuid = "6aace237-9b48-4294-8e96-196759a5305b";
  rootPart = "/dev/disk/by-uuid/${rootUuid}";

  hosted-domains =
    map
      (prefix: if prefix == null then cfg.domainName else "${prefix}.${cfg.domainName}")
  [
    null
    "dns"
    "mumble"
    "mail"
    "music"
    "www"
    "matrix"
    "search"
    "git"
    "cloud"
    "ns1"
    "ns2"
  ];

in {
  imports = [
    ./options.nix
    ./matrix.nix
    ./fdroid.nix
    ./mumble.nix
  ];

  system.stateVersion = "22.11";

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usb_storage" "sd_mod" "sr_mod" "rtsx_pci_sdmmc" ];
    };
    kernelModules = [ "kvm-intel" ];
    kernelParams = [
      "consoleblank=60"
    ];
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        version = 2;
        efiSupport = true;
        efiInstallAsRemovable = true;
        gfxmodeEfi = "1920x1080";
        gfxmodeBios = "1920x1080";
      };
      efi.efiSysMountPoint = "/boot/efi";
    };
  };
  hardware.enableRedistributableFirmware = true;
  fileSystems = {
    "/" =    { device = "none"; fsType = "tmpfs"; neededForBoot = true;
               options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
             { device = rootPart; fsType = "btrfs"; neededForBoot = true;
               options = [ "compress=zstd:15" ]; };
    "/boot" =
             { device = rootPart; fsType = "btrfs"; neededForBoot = true;
               options = [ "compress=zstd:15" "subvol=boot" ]; };
    "/boot/efi" =
             { device = efiPart; fsType = "vfat"; };
  };
  zramSwap.enable = true;
  swapDevices = [ ];
  impermanence = {
    enable = true;
    path = /persist;
    directories = [
      { directory = /var/www/${cfg.domainName}; }
      { directory = /var/lib/maubot; }
      { directory = /var/lib/fdroid; }
      { directory = config.mailserver.dkimKeyDirectory; }
      { directory = config.mailserver.mailDirectory; }
      { directory = /home/user; }
      { directory = /root; }
      { directory = /nix; }
    ];
  };
  services.beesd = {
    filesystems.root = {
      spec = "UUID=${rootUuid}";
      hashTableSizeMB = 128;
      extraOptions = [ "--loadavg-target" "8.0" ];
    };
  };
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  i18n.supportedLocales = lib.mkDefault [
    "C.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
    "en_DK.UTF-8/UTF-8"
  ];
  # ISO-8601
  i18n.extraLocaleSettings.LC_TIME = "en_DK.UTF-8";
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v24n.psf.gz";
  networking.useDHCP = true;
  networking.resolvconf.extraConfig = ''
    name_servers="127.0.0.1 ::1"
  '';
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      # ssh
      22
      # dns
      53 853
      # http/s
      80 443
    ];
    allowedUDPPorts = [
      # dns
      53 853
      # wireguard
      # 5553
    ];
  };

  # UNBOUND
  services.unbound = {
    enable = true;
    package = pkgs.unbound-with-systemd.override {
      withPythonModule = true;
      python = pkgs.python3.withPackages (pkgs: with pkgs; [ pydbus dnspython ]);
    };
    localControlSocketPath = "/run/unbound/unbound.ctl";
    resolveLocalQueries = false;
    settings = {
      server = {
        interface = [ "0.0.0.0" "::" ];
        access-control =  [ "${cfg.lanCidrV4} allow" "${cfg.lanCidrV6} allow" ];
        aggressive-nsec = true;
        do-ip6 = true;
        module-config = ''"validator iterator"'';
        local-zone = [
          ''"local." static''
        ] ++ (lib.optionals (cfg.localIpV4 != null || cfg.localIpV6 != null) [
          ''"${cfg.domainName}." typetransparent''
        ]);
        local-data = builtins.concatLists (map (domain:
          lib.optionals (cfg.localIpV4 != null) [
            ''"${domain}. A ${cfg.localIpV4}"''
          ] ++ (lib.optionals (cfg.localIpV6 != null) [
            ''"${domain}. A ${cfg.localIpV6}"''
          ])) hosted-domains);
      };
      python.python-script = toString (pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/NLnetLabs/unbound/a912786ca9e72dc1ccde98d5af7d23595640043b/pythonmod/examples/avahi-resolver.py";
        sha256 = "0r1iqjf08wrkpzvj6pql1jqa884hbbfy9ix5gxdrkrva09msiqgi";
      });
      remote-control.control-enable = true;
    };
  };
  systemd.services.unbound.environment.MDNS_ACCEPT_NAMES = "^.*\\.local\\.$";
  # just in case
  networking.hosts."127.0.0.1" = [ "localhost" ] ++ hosted-domains;

  # CUPS
  services.printing = {
    enable = true;
    allowFrom = [ cfg.lanCidrV4 cfg.lanCidrV6 ];
    browsing = true;
    clientConf = ''
      ServerName ${cfg.domainName}
    '';
    defaultShared = true;
    drivers = [ pkgs.hplip ];
    startWhenNeeded = false;
  };

  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" config.services.unbound.group ];
  };

  environment.systemPackages = with pkgs; [
    comma
    git
    vim
    wget
    # rxvt-unicode-unwrapped.terminfo
    kitty.terminfo
    tmux
  ];

  services.postgresql.enable = true;
  services.postgresql.package = pkgs.postgresql_13;

  nix = {
    settings = {
      allowed-users = [ "user" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  systemd.services.nix-daemon.serviceConfig.LimitSTACKSoft = "infinity";

  # SSH
  services.openssh = {
    enable = true;
    # settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
    listenAddresses = [{
      addr = "0.0.0.0";
    } {
      addr = "::";
    }];
  };
  services.fail2ban.enable = true;

  # SEARXNG
  services.searx.enable = true;
  services.searx.package = pkgs.searxng.overrideAttrs (_: {
    src = pkgs.fetchFromGitHub {
      owner = "searxng";
      repo = "searxng";
      rev = "cb1c3741d7de1354b524589114617f183009f6a8";
      sha256 = "sha256-7erY5Bd1ZoTpAIDbhIupu64Xd1PQspaW6vBqu7knzNI=";
    };
  });
  services.searx.runInUwsgi = true;
  services.searx.uwsgiConfig = let inherit (config.services.searx) settings; in {
    socket = "${lib.quotePotentialIpV6 settings.server.bind_address}:${toString settings.server.port}";
  };
  users.groups.searx.members = [ "nginx" ];
  services.searx.environmentFile = "/etc/nixos/private/searx.env";
  services.searx.settings = {
    use_default_settings = true;
    search = {
        safe_search = 0; # Filter results. 0: None, 1: Moderate, 2: Strict
        autocomplete = "duckduckgo"; # Existing autocomplete backends: "dbpedia", "duckduckgo", "google", "startpage", "swisscows", "qwant", "wikipedia" - leave blank to turn it off by default
        default_lang = ""; # Default search language - leave blank to detect from browser information or use codes from 'languages.py'
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
    /* = {
      name = "soundcloud";
      disabled = true;
    };*/
  };
  services.nginx.virtualHosts."search.${cfg.domainName}" = let inherit (config.services.searx) settings; in {
    enableACME = true;
    forceSSL = true;
    # locations."/".proxyPass = "http://${lib.quotePotentialIpV6 settings.server.bind_address}:${toString settings.server.port}";
    locations."/".extraConfig = ''
      uwsgi_pass "${lib.quotePotentialIpV6 settings.server.bind_address}:${toString settings.server.port}";
      include ${config.services.nginx.package}/conf/uwsgi_params;
    '';
  };

  # NGINX
  services.nginx.enable = true;
  services.nginx.streamConfig =
    let
      cert = config.security.acme.certs."${cfg.domainName}".directory + "/fullchain.pem";
      certKey = config.security.acme.certs."${cfg.domainName}".directory + "/key.pem";
      trustedCert = config.security.acme.certs."${cfg.domainName}".directory + "/chain.pem";
    in ''
      upstream dns {
        zone dns 64k;
        server 127.0.0.1:53;
      }
      server {
        listen 853 ssl;
        ssl_certificate ${cert};
        ssl_certificate_key ${certKey};
        ssl_trusted_certificate ${trustedCert};
        proxy_pass dns;
      }
    '';
  services.nginx.commonHttpConfig = "log_format postdata '{\"ip\":\"$remote_addr\",\"time\":\"$time_iso8601\",\"referer\":\"$http_referer\",\"body\":\"$request_body\",\"ua\":\"$http_user_agent\"}';";
  services.nginx.recommendedTlsSettings = true;
  services.nginx.recommendedOptimisation = true;
  services.nginx.recommendedGzipSettings = true;
  services.nginx.recommendedProxySettings = true;

  # BLOG
  services.nginx.virtualHosts."${cfg.domainName}" = {
    enableACME = true;
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
    
  services.nginx.virtualHosts."www.${cfg.domainName}" = {
    enableACME = true;
    globalRedirect = cfg.domainName;
  };

  # MAILSERVER
  # roundcube
  services.nginx.virtualHosts."mail.${cfg.domainName}" = {
    enableACME = true;
  };
  services.roundcube = {
    enable = true;
    package = pkgs.roundcube.withPlugins (plugins: [ plugins.persistent_login ]);
    dicts = with pkgs.aspellDicts; [ en ru ];
    hostName = "mail.${cfg.domainName}";
    maxAttachmentSize = 100;
    plugins = [ "persistent_login" ];
  };
  mailserver = {
    enable = true;
    fqdn = "mail.${cfg.domainName}";
    domains = [ cfg.domainName ];
    certificateScheme = 1;
    certificateFile = config.security.acme.certs."mail.${cfg.domainName}".directory + "/fullchain.pem";
    keyFile = config.security.acme.certs."mail.${cfg.domainName}".directory + "/key.pem";
    localDnsResolver = false;
    recipientDelimiter = "-";
    lmtpSaveToDetailMailbox = "no";
    hierarchySeparator = "/";
  };

  # Only allow local connections to noreply account
  mailserver.loginAccounts."noreply@${cfg.domainName}" = {
    # password is set in private.nix
    hashedPassword = cfg.hashedNoreplyPassword;
    sendOnly = true;
  };
  services.dovecot2.extraConfig =
    let passwd = builtins.toFile "dovecot2-local-passwd" ''
        noreply@${cfg.domainName}:{plain}${cfg.unhashedNoreplyPassword}::::::allow_nets=local,127.0.0.0/8,::1
      '';
    in ''
      passdb {
        driver = passwd-file
        args = ${passwd}
      }
    '';

  # GITEA
  services.nginx.virtualHosts."git.${cfg.domainName}" = let inherit (config.services.gitea) settings; in {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://${lib.quotePotentialIpV6 settings.server.HTTP_ADDR}:${toString settings.server.HTTP_PORT}";
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
    enableACME = true;
    forceSSL = true;
  };
  services.nextcloud = {
    enable = true;
    enableBrokenCiphersForSSE = false;
    package = pkgs.nextcloud26;
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

  services.pleroma = {
    enable = true;
    secretConfigFile = "/var/lib/pleroma/secrets.exs";
    configs = [ ''
      import Config
    '' ];
  };
  systemd.services.pleroma.path = [ pkgs.exiftool pkgs.gawk ];
  services.nginx.virtualHosts."pleroma.${cfg.domainName}" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://127.0.0.1:9970";
  };

  /*locations."/dns-query".extraConfig = ''
    grpc_pass grpc://127.0.0.1:53453;
  '';*/

  # TODO: firefox sync?
}
