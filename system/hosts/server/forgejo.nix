{ config
, lib
, ... }:

let
  cfg = config.server;
in {
  services.nginx.virtualHosts."git.${cfg.domainName}" = let inherit (config.services.forgejo) settings; in {
    quic = true;
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://${lib.quoteListenAddr settings.server.HTTP_ADDR}:${toString settings.server.HTTP_PORT}";
  };
  services.forgejo = {
    enable = true;
    database = {
      createDatabase = false;
      user = "gitea";
      passwordFile = "/secrets/forgejo_db_password";
      type = "postgres";
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
        HTTP_ADDR = "::1";
        HTTP_PORT = 3310;
        DOMAIN = "git.${cfg.domainName}";
        # START_SSH_SERVER = true;
        # SSH_PORT = 2222;
      };
      service = {
        DISABLE_REGISTRATION = false;
        REGISTER_MANUAL_CONFIRM = true;
      };
    };
  };
}
