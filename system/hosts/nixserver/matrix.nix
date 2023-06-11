{ config
, lib
, ... }:

let
  cfg = config.server;
  matrixServerJson = {
    "m.server" = "matrix.${cfg.domainName}:443";
  };
  matrixClientJson = {
    "m.homeserver" = { base_url = "https://matrix.${cfg.domainName}"; };
    "m.identity_server" = { base_url = "https://vector.im"; };
  };
  matrixServerConfigResponse = ''
    add_header Content-Type application/json;
    return 200 '${builtins.toJSON matrixServerJson}';
  '';
  matrixClientConfigResponse = ''
    add_header Content-Type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '${builtins.toJSON matrixClientJson}';
  '';
  matrixAddr = "::1";
  matrixPort = 8008;
in {
  imports = [ ./maubot.nix ];

  networking.firewall.allowedTCPPorts = [ 8008 8448 ];
  systemd.services.matrix-synapse.serviceConfig.TimeoutStartSec = 180;

  services.nginx.virtualHosts."${cfg.domainName}" = {
    locations."= /.well-known/matrix/server".extraConfig = matrixServerConfigResponse;
    locations."= /.well-known/matrix/client".extraConfig = matrixClientConfigResponse;
  };

  services.nginx.virtualHosts."matrix.${cfg.domainName}" = {
    enableACME = true;
    forceSSL = true;
    locations = {
      "= /.well-known/matrix/server".extraConfig = matrixServerConfigResponse;
      "= /.well-known/matrix/client".extraConfig = matrixClientConfigResponse;
      "/".proxyPass = "http://${lib.quoteListenAddr matrixAddr}:${toString matrixPort}";
    };
  };

  # systemd.services.heisenbridge.wants = [ "matrix-synapse.service" ];
  # systemd.services.heisenbridge.after = [ "matrix-synapse.service" ];
  services.heisenbridge = {
    enable = true;
    homeserver = "http://${lib.quoteListenAddr matrixAddr}:${toString matrixPort}/";
  };
  # so synapse can read the registration
  users.groups.heisenbridge.members = [ "matrix-synapse" ];

  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [ "/var/lib/matrix-synapse/config.yaml" ];
    settings = {
      app_service_config_files = [
        "/var/lib/heisenbridge/registration.yml"
      ];
      allow_guest_access = true;
      url_preview_enabled = true;
      tls_certificate_path = config.security.acme.certs."matrix.${cfg.domainName}".directory + "/fullchain.pem";
      tls_private_key_path = config.security.acme.certs."matrix.${cfg.domainName}".directory + "/key.pem";
      public_baseurl = "https://matrix.${cfg.domainName}/";
      server_name = "matrix.${cfg.domainName}";
      max_upload_size = "100M";
      email = {
        smtp_host = "mail.pavluk.org";
        smtp_port = 587;
        smtp_user = "noreply";
        smtp_password = cfg.unhashedNoreplyPassword;
        notif_from = "${cfg.domainName} matrix homeserver <noreply@${cfg.domainName}>";
        app_name = cfg.domainName;
        notif_for_new_users = false;
        enable_notifs = true;
      };
      listeners = [{
        port = matrixPort;
        bind_addresses = [ matrixAddr ];
        type = "http";
        tls = false;
        x_forwarded = true;
        resources = [{
          names = [ "client" "federation" ];
          compress = false;
        }];
      }];
    };
  };
}
