{ config
, lib
, pkgs
, ... }:

let
  cfg = config.services.certspotter;
in {
  options.services.certspotter = {
    enable = lib.mkEnableOption "Cert Spotter, a Certificate Transparency log monitor";
    sendmailPath = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the `sendmail` binary. By default, the local sendmail wrapper is used
        (see `config.services.mail.sendmailSetuidWrapper`).
      '';
      example = lib.literalExpression ''"''${pkgs.system-sendmail}/bin/sendmail"'';
    };
    watchlist = lib.mkOption {
      type = with lib.types; listOf str;
      description = "Domain names to watch. To monitor a domain with all subdomains, prefix its name with `.` (e.g. `.example.org`).";
      default = [ ];
      example = [ ".example.org" "another.example.com" ];
    };
    emailRecipients = lib.mkOption {
      type = with lib.types; listOf str;
      description = "A list of email addresses to send certificate updates to.";
      default = [ ];
    };
    hooks = lib.mkOption {
      type = with lib.types; listOf path;
      description = ''
        Scripts to run upon the detection of a new certificate. See `man 8 certspotter-script` or [the GitHub page](https://github.com/SSLMate/certspotter/blob/master/man/certspotter-script.md) for more info.
      '';
      default = [];
      example = lib.literalExpression ''
        [
          (pkgs.writeShellScript "certspotter-hook" '''
            echo "Event summary: $SUMMARY."
          ''')
        ]
      '';
    };
    extraFlags = lib.mkOption {
      type = with lib.types; listOf str;
      description = "Extra command-line arguments to pass to Cert Spotter";
      example = [ "-start_at_end" ];
      default = [ ];
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.watchlist != [ ];
        message = "You must specify at least one domain for Cert Spotter to watch";
      }
      {
        assertion = cfg.hooks != [] || cfg.emailRecipients != [];
        message = "You must specify at least one hook or email recipient for Cert Spotter";
      }
      {
        assertion = (cfg.emailRecipients != []) -> (cfg.sendmailPath != "/run/current-system/sw/bin/false");
        message = ''
          You must configure the sendmail setuid wrapper (services.mail.sendmailSetuidWrapper)
          or services.certspotter.sendmailPath
        '';
      }
    ];
    services.certspotter.sendmailPath = lib.mkMerge [
      (lib.mkIf (config.services.mail.sendmailSetuidWrapper != null) (lib.mkOptionDefault "/run/wrappers/bin/sendmail"))
      (lib.mkIf (config.services.mail.sendmailSetuidWrapper == null) (lib.mkOptionDefault "/run/current-system/sw/bin/false"))
    ];
    users.users.certspotter = {
      group = "certspotter";
      home = "/var/lib/certspotter";
      createHome = true;
      isSystemUser = true;
      # uid = config.ids.uids.certspotter;
    };
    users.groups.certspotter = {
      # gid = config.ids.gids.certspotter;
    };
    systemd.services.certspotter = {
      description = "Cert Spotter - Certificate Transparency Monitor";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment.CERTSPOTTER_CONFIG_DIR = pkgs.linkFarm "certspotter-config"
        (lib.toList {
          name = "watchlist";
          path = pkgs.writeText "cerspotter-watchlist" (builtins.concatStringsSep "\n" cfg.watchlist);
        }
        ++ lib.optional (cfg.emailRecipients != [ ]) {
          name = "email_recipients";
          path = pkgs.writeText "cerspotter-email_recipients" (builtins.concatStringsSep "\n" cfg.emailRecipients);
        }
        ++ lib.optional (cfg.hooks != [ ]) {
          name = "hooks.d";
          path = pkgs.linkFarm "certspotter-hooks" (lib.imap1 (i: path: {
            inherit path;
            name = "hook${toString i}";
          }) cfg.hooks);
        });
      environment.CERTSPOTTER_STATE_DIR = "/var/lib/certspotter";
      serviceConfig = {
        User = "certspotter";
        Group = "certspotter";
        WorkingDirectory = "/var/lib/certspotter";
        ExecStart = "${pkgs.certspotter}/bin/certspotter -sendmail ${cfg.sendmailPath} ${lib.escapeShellArgs cfg.extraFlags}";
      };
    };
  };
}
