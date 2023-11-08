{ config
, pkgs
, ... }:

let
  cfg = config.server;
in {
  # TODO: remove this in 2024
  services.nginx.virtualHosts."pleroma.${cfg.domainName}" = {
    quic = true;
    enableACME = true;
    addSSL = true;
    serverAliases = [ "akkoma.${cfg.domainName}" ];
    locations."/".return = "301 https://fedi.${cfg.domainName}$request_uri";
  };

  services.postgresql.extraPlugins = with config.services.postgresql.package.pkgs; [ tsja ];

  services.akkoma = let
    inherit ((pkgs.formats.elixirConf { }).lib) mkRaw;
  in {
    enable = true;
    dist.extraFlags = [
      "+sbwt" "none"
      "+sbwtdcpu" "none"
      "+sbwtdio" "none"
    ];
    config.":pleroma"."Pleroma.Web.Endpoint" = {
      url = {
        scheme = "https";
        host = "fedi.${cfg.domainName}";
        port = 443;
      };
      secret_key_base._secret = "/secrets/akkoma/secret_key_base";
      signing_salt._secret = "/secrets/akkoma/signing_salt";
      live_view.signing_salt._secret = "/secrets/akkoma/live_view_signing_salt";
    };
    initDb = {
      enable = false;
      username = "akkoma";
      password._secret = "/secrets/akkoma/postgres_password";
    };
    config.":pleroma".":instance" = {
      name = cfg.domainName;
      description = "Insert instance description here";
      email = "webmaster-akkoma@${cfg.domainName}";
      notify_email = "noreply@${cfg.domainName}";
      limit = 5000;
      registrations_open = true;
      account_approval_required = true;
    };
    config.":pleroma"."Pleroma.Repo" = {
      adapter = mkRaw "Ecto.Adapters.Postgres";
      username = "akkoma";
      password._secret = "/secrets/akkoma/postgres_password";
      database = "akkoma";
      hostname = "localhost";
      prepare = mkRaw ":named";
      parameters.plan_cache_mode = "force_custom_plan";
      timeout = 30000;
      connect_timeout = 10000;
    };
    config.":web_push_encryption".":vapid_details" = {
      subject = "mailto:webmaster-akkoma@${cfg.domainName}";
      public_key._secret = "/secrets/akkoma/push_public_key";
      private_key._secret = "/secrets/akkoma/push_private_key";
    };
    config.":joken".":default_signer"._secret = "/secrets/akkoma/joken_signer";
    # config.":logger".":ex_syslogger".level = ":debug";
    nginx = {
      quic = true;
      enableACME = true;
      forceSSL = true;
    };
  };
  systemd.services.akkoma = {
    path = [ pkgs.exiftool pkgs.gawk ];
    serviceConfig.Restart = "on-failure";
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };
  };
}
