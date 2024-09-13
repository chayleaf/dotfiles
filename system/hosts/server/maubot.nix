{ config
, lib
, pkgs
, ... }:

let
  cfg = config.server;
in {
  services.nginx.virtualHosts."matrix.${cfg.domainName}".locations = let
    inherit (config.services.maubot) settings;
  in {
    "^~ /_matrix/maubot/" = {
      proxyPass = "http://${lib.quoteListenAddr settings.server.hostname}:${toString settings.server.port}";
      proxyWebsockets = true;
    };
  };
  services.maubot.enable = true;
  services.maubot.settings = {
    database = "postgresql://maubot@localhost/maubot";
    server.public_url = "https://matrix.${cfg.domainName}";
  };
  services.maubot.plugins = with config.services.maubot.package.plugins; [
    weather
    urban
    media
    reactbot
    reminder
    translate
    rss
  ];
  services.maubot.pythonPackages = with pkgs.python3.pkgs; [
    levenshtein
    pillow
  ];
}
