{
  config,
  lib,
  ...
}:

let
  cfg = config.server;
in
{
  services.murmur = {
    enable = true;
    imgMsgLength = 0;
    textMsgLength = 0;
    registerName = "mumble.${cfg.domainName}";
    registerHostname = "mumble.${cfg.domainName}";
    sslCa = config.security.acme.certs."mumble.${cfg.domainName}".directory + "/chain.pem";
    sslCert = config.security.acme.certs."mumble.${cfg.domainName}".directory + "/fullchain.pem";
    sslKey = config.security.acme.certs."mumble.${cfg.domainName}".directory + "/key.pem";
    # clientCertRequired = true;
    extraConfig = ''
      bandwidth=320000
      opusthreshold=0
    '';
  };
  # Allow murmur to read the certificate
  security.acme.certs."mumble.${cfg.domainName}" = {
    group = "nginxandmurmur";
    reloadServices = [ "murmur" ];
  };
  users.groups.nginxandmurmur.members = [
    "murmur"
    "nginx"
  ];

  # Mumble music bot
  services.nginx.virtualHosts."mumble.${cfg.domainName}" =
    let
      inherit (config.services.botamusique) settings;
    in
    {
      quic = true;
      enableACME = true;
      forceSSL = true;
      globalRedirect = cfg.domainName;
      locations."/music".extraConfig = "return 301 https://mumble.${cfg.domainName}/music/;";
      locations."/music/".proxyPass =
        "http://${lib.quoteListenAddr settings.webinterface.listening_addr}:${toString settings.webinterface.listening_port}/";
    };

  services.botamusique = {
    enable = true;
    settings = {
      youtube_dl = {
        cookiefile = "/var/lib/private/botamusique/cookie_ydl";
      };
      webinterface = {
        enabled = true;
        listening_addr = "::1";
        listening_port = 8181;
        is_web_proxified = true;
        access_address = "https://mumble.${cfg.domainName}/music";
        auth_method = "token";
        upload_enabled = true;
        max_upload_file_size = "100MB";
        delete_allowed = true;
      };
      bot = {
        bandwidth = 200000;
        volume = 1.0;
        ducking = true;
        ducking_volume = 0.75;
      };
      server.certificate = "/var/lib/private/botamusique/botamusique.pem";
    };
  };
  systemd.services.botamusique.wants = [ "murmur.service" ];
  systemd.services.botamusique.after = [ "murmur.service" ];

  networking.firewall = {
    allowedTCPPorts = [
      64738
      # Used for mumble-web signaling (not sure if it needs TCP or UDP)
      # 20000 20001 20002 20003 20004 20005 20006 20007 20008 20009 20010
    ];
    allowedUDPPorts = [
      64738
      # 20000 20001 20002 20003 20004 20005 20006 20007 20008 20009 20010
    ];
  };
}
