{ config
, pkgs
, ... }:

let
  cfg = config.server;
in {
  impermanence.directories = [
    { directory = config.mailserver.dkimKeyDirectory; user = "opendkim"; group = "opendkim"; mode = "0755"; }
    { directory = config.mailserver.mailDirectory; user = "virtualMail"; group = "virtualMail"; mode = "0700"; }
  ];

  # roundcube
  # TODO: fix sending mail via roundcube
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
    let
      passwd = builtins.toFile "dovecot2-local-passwd" ''
        noreply@${cfg.domainName}:{plain}${cfg.unhashedNoreplyPassword}::::::allow_nets=local,127.0.0.0/8,::1
      '';
    in ''
      passdb {
        driver = passwd-file
        args = ${passwd}
      }
    '';
}
