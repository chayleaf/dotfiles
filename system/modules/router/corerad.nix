{ lib
, config
, pkgs
, utils
, ... }:

let
  cfg = config.router;
in {
  config = lib.mkIf cfg.enable {
    systemd.services = lib.mapAttrs' (interface: icfg: let
      cfg = icfg.ipv6.corerad;
      escapedInterface = utils.escapeSystemdPath interface;
      settingsFormat = pkgs.formats.toml {};
      configFile = if cfg.configFile != null then cfg.configFile else settingsFormat.generate "corerad-${escapedInterface}.toml" ({
        interfaces = [
          (rec {
            name = interface;
            monitor = false;
            advertise = true;
            managed = icfg.ipv6.kea.enable && builtins.any (x: lib.hasInfix ":" x.address) icfg.ipv6.addresses;
            other_config = managed && cfg.interfaceSettings.managed or true;
            prefix = map ({ address, prefixLength, coreradSettings, ... }: {
              prefix = "${address}/${toString prefixLength}";
              autonomous = !(other_config && cfg.interfaceSettings.other_config or true);
            } // coreradSettings) icfg.ipv6.addresses;
            route = builtins.concatLists (map ({ address, prefixLength, gateways, ... }: map (gateway: {
              prefix = "${if builtins.isString gateway then gateway else gateway.address}/${toString (if gateway.prefixLength or null != null then gateway.prefixLength else prefixLength)}";
            } // (gateway.coreradSettings or { })) gateways) icfg.ipv6.addresses);
            rdnss = builtins.concatLists (map ({ dns, ... }: map (dns: {
              servers = if builtins.isString dns then dns else dns.address;
            } // (dns.coreradSettings or { })) dns) icfg.ipv6.addresses);
          } // cfg.interfaceSettings)
        ];
      } // cfg.settings);
      package = pkgs.corerad;
    in {
      name = "corerad-${escapedInterface}";
      value = lib.mkIf icfg.ipv6.corerad.enable {
        description = "CoreRAD IPv6 NDP RA daemon (${interface})";
        after = [ "network.target" "sys-subsystem-net-devices-${escapedInterface}.device" ];
        bindsTo = [ "sys-subsystem-net-devices-${escapedInterface}.device" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          LimitNPROC = 512;
          LimitNOFILE = 1048576;
          CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_RAW";
          AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_RAW";
          NoNewPrivileges = true;
          DynamicUser = true;
          Type = "notify";
          NotifyAccess = "main";
          ExecStart = "${lib.getBin package}/bin/corerad -c=${configFile}";
          Restart = "on-failure";
          RestartKillSignal = "SIGHUP";
        };
      };
    }) cfg.interfaces;
  };
}
