{ config
, lib
, pkgs
, ... }:

let
  cfg = config.server;
  # i've yet to create a maubot module so this is hardcoded
  maubotAddr = "127.0.0.1";
  maubotPort = 29316;
in {
  impermanence.directories = [
    { directory = /var/lib/maubot; user = "maubot"; group = "maubot"; mode = "0755"; }
  ];
  services.nginx.virtualHosts."matrix.${cfg.domainName}".locations = {
    "/_matrix/maubot/" = {
      proxyPass = "http://${lib.quoteListenAddr maubotAddr}:${toString maubotPort}";
      proxyWebsockets = true;
    };
  };
  /*users.users.maubot = {
    home = "/var/lib/maubot";
    group = "maubot";
    isSystemUser = true;
  };
  users.groups.maubot = { };*/
  /*systemd.services.maubot = {
    description = "Maubot";
    wants = [ "matrix-synapse.service" "nginx.service" ];
    after = [ "matrix-synapse.service" "nginx.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
    };
    serviceConfig = {
      User = "maubot";
      Group = "maubot";
      WorkingDirectory = "/var/lib/maubot/data";
    };
    script = "${pkgs.python3.withPackages (pks: with pks; [
      pkgs.maubot (pkgs.pineapplebot.override {
        magic = cfg.pizzabotMagic;
      }) feedparser levenshtein python-dateutil pytz
    ])}/bin/python3 -m maubot";
  };*/
  systemd.services.maubot = {
    after = [ "nginx.service" ];
    requires = [ "nginx.service" ];
  };
  services.maubot.enable = true;
  services.maubot.settings = {
    database = "postgresql://maubot@localhost/maubot";
    server.public_url = "https://matrix.${cfg.domainName}";
  };
  services.maubot.plugins = with config.services.maubot.package.plugins; [
    com.arachnitech.weather
    com.dvdgsng.maubot.urban
    xyz.maubot.media
    xyz.maubot.reactbot
    xyz.maubot.reminder
    xyz.maubot.translate
    xyz.maubot.rss
  ];
  services.maubot.pythonPackages = [
    (pkgs.pineapplebot.override { magic = cfg.pizzabotMagic; })
  ] ++ (with pkgs.python3.pkgs; [
    levenshtein
  ]);
}
