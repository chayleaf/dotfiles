{
  config,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.server;
in
{
  imports = [ inputs.nixos-mailserver.nixosModules.default ];

  impermanence.directories = [
    {
      directory = config.mailserver.dkim.keyDirectory;
      user = "opendkim";
      group = "opendkim";
      mode = "0755";
    }
    {
      directory = config.mailserver.storage.path;
      user = "virtualMail";
      group = "virtualMail";
      mode = "0700";
    }
  ];

  # roundcube
  # TODO: fix sending mail via roundcube
  services.nginx.virtualHosts."mail.${cfg.domainName}" = {
    quic = true;
    enableACME = true;
    forceSSL = true;
  };
  services.roundcube = {
    enable = true;
    package = pkgs.roundcube.withPlugins (plugins: [ plugins.persistent_login ]);
    dicts = with pkgs.aspellDicts; [
      en
      ru
    ];
    hostName = "mail.${cfg.domainName}";
    maxAttachmentSize = config.mailserver.messageSizeLimit / 1024 / 1024;
    plugins = [ "persistent_login" "managesieve" ];
    extraConfig = ''
      $config['imap_host'] = "ssl://${config.mailserver.fqdn}";
      $config['smtp_host'] = "ssl://${config.mailserver.fqdn}";
      $config['smtp_user'] = "%u";
      $config['smtp_pass'] = "%p";
      $config['managesieve_host'] = "tls://${config.mailserver.fqdn}";
      $config['managesieve_port'] = 4190;
      $config['managesieve_usetls'] = true;
    '';
  };
  mailserver = let
    fqdn = "mail.${cfg.domainName}";
  in {
    inherit fqdn;
    enable = true;
    domains = [ cfg.domainName ];
    x509.useACMEHost = fqdn;
    #certificateScheme = "acme";
    # actually this just means don't run kresd, unbound is used as the local dns resolver instead
    localDnsResolver = false;
    recipientDelimiter = "-";
    lmtpSaveToDetailMailbox = "no";
    hierarchySeparator = "/";
    stateVersion = 3;
    # Only allow local connections to noreply account
    accounts."noreply@${cfg.domainName}" = {
      # password is set in private.nix
      hashedPassword = cfg.hashedNoreplyPassword;
      sendOnly = true;
    };
  };

  services.dovecot2.extraConfig =
    let
      passwd = builtins.toFile "dovecot2-local-passwd" ''
        noreply@${cfg.domainName}:{plain}${cfg.unhashedNoreplyPassword}::::::allow_nets=local,127.0.0.0/8,::1
      '';
    in
    ''
      passdb {
        driver = passwd-file
        args = ${passwd}
      }
    '';
}
