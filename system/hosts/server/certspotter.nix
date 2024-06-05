{ config
, lib
, pkgs
, ... }:

let
  cfg = config.server;
  python = pkgs.python3.withPackages (p: with p; [ cryptography pyasn1 pyasn1-modules requests ]);
  tool = pkgs.writeScript "certspotter.py" ''
    #!${python}/bin/python3
    ${builtins.readFile ./certspotter.py}
  '';
in {
  security.acme.certs = lib.mkIf config.services.certspotter.enable (lib.flip builtins.mapAttrs (lib.filterAttrs (k: v: v.enableACME) config.services.nginx.virtualHosts) (k: v: {
    postRun = ''
      ${tool} tbs full.pem > "/var/lib/certspotter/tbs-hashes/${k}"
    '';
  }));
  services.certspotter = {
    enable = false;
    extraFlags = [ ];
    watchlist = [ ".${cfg.domainName}" ];
    hooks = lib.toList (pkgs.writeShellScript "certspotter-hook" ''
      if [[ "$EVENT" == discovered_cert ]]; then
        ${pkgs.gnugrep}/bin/grep -r "$TBS_SHA256" /var/lib/certspotter/tbs-hashes/ && exit
      fi
      (echo "Subject: $SUMMARY" && echo && cat "$TEXT_FILENAME") | /run/wrappers/bin/sendmail -i webmaster-certspotter@${cfg.domainName}
    '');
  };
  systemd.services.certspotter-lite = {
    script = ''
      exec ${tool} spot \
        -c /var/lib/acme/certspotter-lite.txt \
        -d ${cfg.domainName} \
        -t webmaster-certspotter@${cfg.domainName} \
        -s /run/wrappers/bin/sendmail \
        /var/lib/acme/*/full.pem
    '';
    serviceConfig = {
      User = "acme";
      Group = "acme";
      Type = "oneshot";
    };
  };
  systemd.timers.certspotter-lite = {
    wantedBy = [ "timers.target" ];
    partOf = [ "certspotter-lite.service" ];
    timerConfig.OnCalendar = [ "*-*-* 00:00:00" ]; # every day
    timerConfig.RandomizedDelaySec = 43200; # execute at random time in the first 12 hours
  };
}
