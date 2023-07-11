{ config
, lib
, pkgs
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
  # TODO: remove when https://github.com/NixOS/nixpkgs/pull/242912 is merged
  systemd.services.heisenbridge.preStart = let
    bridgeConfig = builtins.toFile "heisenbridge-registration.yml" (builtins.toJSON {
      inherit (config.services.heisenbridge) namespaces; id = "heisenbridge";
      url = config.services.heisenbridge.registrationUrl; rate_limited = false;
      sender_localpart = "heisenbridge";
    });
  in lib.mkForce ''
    umask 077
    set -e -u -o pipefail

    if ! [ -f "/var/lib/heisenbridge/registration.yml" ]; then
      # Generate registration file if not present (actually, we only care about the tokens in it)
      ${config.services.heisenbridge.package}/bin/heisenbridge --generate --config /var/lib/heisenbridge/registration.yml
    fi

    # Overwrite the registration file with our generated one (the config may have changed since then),
    # but keep the tokens. Two step procedure to be failure safe
    ${pkgs.yq}/bin/yq --slurp \
      '.[0] + (.[1] | {as_token, hs_token})' \
      ${bridgeConfig} \
      /var/lib/heisenbridge/registration.yml \
      > /var/lib/heisenbridge/registration.yml.new
    mv -f /var/lib/heisenbridge/registration.yml.new /var/lib/heisenbridge/registration.yml

    # Grant Synapse access to the registration
    if ${pkgs.getent}/bin/getent group matrix-synapse > /dev/null; then
      chgrp -v matrix-synapse /var/lib/heisenbridge/registration.yml
      chmod -v g+r /var/lib/heisenbridge/registration.yml
    fi
  '';

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
