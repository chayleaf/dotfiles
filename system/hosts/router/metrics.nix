{ config
, router-lib
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
      controlInterface = "/run/unbound/unbound.ctl";
      listenAddress = netAddresses.lan4;
      group = config.services.unbound.group;
    };
    kea = {
      enable = true;
      controlSocketPaths = [
        "/run/kea/kea-dhcp4-ctrl.sock"
        "/run/kea/kea-dhcp6-ctrl.sock"
      ];
      listenAddress = netAddresses.lan4;
    };
  };
  router.interfaces.br0 = {
    ipv4.kea.settings.control-socket = {
      socket-name = "/run/kea/kea-dhcp4-ctrl.sock";
      socket-type = "unix";
    };
    ipv6.kea.settings.control-socket = {
      socket-name = "/run/kea/kea-dhcp6-ctrl.sock";
      socket-type = "unix";
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
