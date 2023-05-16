{ config
, pkgs
, ... }:

let
  cfg = config.server;
in {
  impermanence.directories = [
    { directory = /var/lib/fdroid; user = "fdroid"; group = "fdroid"; mode = "0755"; }
  ];
  services.nginx.virtualHosts."${cfg.domainName}" = {
    locations."/fdroid/".alias = "/var/lib/fdroid/repo/";
  };
  users.users.fdroid = {
    home = "/var/lib/fdroid";
    group = "fdroid";
    isSystemUser = true;
  };
  users.groups.fdroid = { };
  systemd.timers.update-fdroid = {
    wantedBy = [ "timers.target" ];
    partOf = [ "update-fdroid.service" ];
    # slightly unusual time to reduce server load
    timerConfig.OnCalendar = [ "*-*-* 00:40:00" ]; # every day
  };
  systemd.services.update-fdroid = {
    serviceConfig = let
      inherit (pkgs) fdroidserver;
      fdroidScript = pkgs.writeText "update-froid.py" ''
        import requests, subprocess, os, sys

        x = requests.get('https://api.github.com/repos/ppy/osu/releases').json()

        for q in x:
            for w in q.get('assets', []):
                if w.get('name', "").endswith('.apk'):
                    os.chdir('/var/lib/fdroid')
                    subprocess.run(['${pkgs.wget}/bin/wget', w['browser_download_url'], '-O', '/var/tmp/lazer.apk'], check=True)
                    os.rename('/var/tmp/lazer.apk', '/var/lib/fdroid/repo/sh.ppy.osulazer.apk')
                    subprocess.run(['${fdroidserver}/bin/fdroid', 'update', '--allow-disabled-algorithms'])
                    sys.exit()
      '';
      fdroidPython = pkgs.python3.withPackages (p: with p; [ requests ]);
    in {
      Type = "oneshot";
      ExecStart = "${fdroidPython} ${fdroidScript}";
    };
    environment.JAVA_HOME = "${pkgs.jdk11_headless}";
    path = [ pkgs.jdk11_headless ];
  };
}
