{ config
, router-lib
, lib
, ... }:
let
  cfg = config.router-settings;
  netAddresses.lan4 = (router-lib.parseCidr cfg.network).address;
in {
  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = [ "logind" "systemd" ];
      listenAddress = netAddresses.lan4;
      port = 9101; # cups is 9100
    };
    process = {
      enable = true;
      listenAddress = netAddresses.lan4;
    };
    unbound = {
      enable = true;
      # controlInterface = "/run/unbound/unbound.ctl";
      host = "unix:///run/unbound/unbound.ctl";
      listenAddress = netAddresses.lan4;
      group = config.services.unbound.group;
    };
    kea = {
      enable = true;
      controlSocketPaths = [
        config.router.interfaces.br0.ipv4.kea.settings.control-socket.socket-name
        config.router.interfaces.br0.ipv6.kea.settings.control-socket.socket-name
      ];
      listenAddress = netAddresses.lan4;
    };
    ping2 = {
      enable = true;
      listenAddress = netAddresses.lan4;
      port = 9380;
      config = {
        type = "raw";
        targets = [
          "8.8.8.8"
          { target = "8.8.8.8"; netns = "wan"; }
        ];
      };
    };
  };
  router.interfaces.br0 = let
    # all of this just to avoid logging commands...
    keaLogs = v: [
      "alloc-engine"
      "auth"
      "bad-packets"
      "database"
      "ddns"
      "dhcp${toString v}"
      "dhcpsrv"
      "eval"
      "hosts"
      "leases"
      "options"
      "packets"
      "tcp"
    ];
  in {
    ipv4.kea.settings = {
      control-socket = {
        socket-name = "/run/kea4-br0/kea.sock";
        socket-type = "unix";
      };
      loggers = lib.toList {
        name = "kea-dhcp4";
        severity = "WARN";
        output_options = [ { output = "syslog"; } ];
      } ++ map (name: {
        name = "kea-dhcp4.${name}";
        severity = "INFO";
        output_options = [ { output = "syslog"; } ];
      }) (keaLogs 4);
    };
    ipv6.kea.settings = {
      control-socket = {
        socket-name = "/run/kea6-br0/kea.sock";
        socket-type = "unix";
      };
      loggers = lib.toList {
        name = "kea-dhcp6";
        severity = "WARN";
        output_options = [ { output = "syslog"; } ];
      } ++ map (name: {
        name = "kea-dhcp6.${name}";
        severity = "INFO";
        output_options = [ { output = "syslog"; } ];
      }) (keaLogs 6);
    };
    ipv6.corerad.settings.debug = {
      address = "${netAddresses.lan4}:9430";
      prometheus = true;
    };
  };
  services.unbound.settings.server = {
    extended-statistics = true;
  };
}
