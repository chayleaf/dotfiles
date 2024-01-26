{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.services.prometheus.exporters.ping2;
  inherit (lib) concatStrings literalExpression mkMerge mkDefault mkEnableOption mkIf mkOption types;
  # copied from nixpkgs/nixos/modules/services/monitoring/prometheus/exporters
  mkExporterOpts = { name, port }: {
    enable = mkEnableOption (lib.mdDoc "the prometheus ${name} exporter");
    port = mkOption {
      type = types.port;
      default = port;
      description = lib.mdDoc ''
        Port to listen on.
      '';
    };
    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = lib.mdDoc ''
        Address to listen on.
      '';
    };
    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = lib.mdDoc ''
        Extra commandline options to pass to the ${name} exporter.
      '';
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Open port in firewall for incoming connections.
      '';
    };
    firewallFilter = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = literalExpression ''
        "-i eth0 -p tcp -m tcp --dport ${toString port}"
      '';
      description = lib.mdDoc ''
        Specify a filter for iptables to use when
        {option}`services.prometheus.exporters.${name}.openFirewall`
        is true. It is used as `ip46tables -I nixos-fw firewallFilter -j nixos-fw-accept`.
      '';
    };
    user = mkOption {
      type = types.str;
      default = "${name}-exporter";
      description = lib.mdDoc ''
        User name under which the ${name} exporter shall be run.
      '';
    };
    group = mkOption {
      type = types.str;
      default = "${name}-exporter";
      description = lib.mdDoc ''
        Group under which the ${name} exporter shall be run.
      '';
    };
  };
  mkExporterConf = { name, conf, serviceOpts }:
    let
      enableDynamicUser = serviceOpts.serviceConfig.DynamicUser or true;
    in
    mkIf conf.enable {
      warnings = conf.warnings or [];
      users.users."${name}-exporter" = (mkIf (conf.user == "${name}-exporter" && !enableDynamicUser) {
        description = "Prometheus ${name} exporter service user";
        isSystemUser = true;
        inherit (conf) group;
      });
      users.groups = (mkIf (conf.group == "${name}-exporter" && !enableDynamicUser) {
        "${name}-exporter" = {};
      });
      networking.firewall.extraCommands = mkIf conf.openFirewall (concatStrings [
        "ip46tables -A nixos-fw ${conf.firewallFilter} "
        "-m comment --comment ${name}-exporter -j nixos-fw-accept"
      ]);
      systemd.services."prometheus-${name}-exporter" = mkMerge ([{
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig.Restart = mkDefault "always";
        serviceConfig.PrivateTmp = mkDefault true;
        serviceConfig.WorkingDirectory = mkDefault /tmp;
        serviceConfig.DynamicUser = mkDefault enableDynamicUser;
        serviceConfig.User = mkDefault conf.user;
        serviceConfig.Group = conf.group;
        # Hardening
        serviceConfig.CapabilityBoundingSet = mkDefault [ "" ];
        serviceConfig.DeviceAllow = [ "" ];
        serviceConfig.LockPersonality = true;
        serviceConfig.MemoryDenyWriteExecute = true;
        serviceConfig.NoNewPrivileges = true;
        serviceConfig.PrivateDevices = mkDefault true;
        serviceConfig.ProtectClock = mkDefault true;
        serviceConfig.ProtectControlGroups = true;
        serviceConfig.ProtectHome = true;
        serviceConfig.ProtectHostname = true;
        serviceConfig.ProtectKernelLogs = true;
        serviceConfig.ProtectKernelModules = true;
        serviceConfig.ProtectKernelTunables = true;
        serviceConfig.ProtectSystem = mkDefault "strict";
        serviceConfig.RemoveIPC = true;
        serviceConfig.RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        serviceConfig.RestrictNamespaces = true;
        serviceConfig.RestrictRealtime = true;
        serviceConfig.RestrictSUIDSGID = true;
        serviceConfig.SystemCallArchitectures = "native";
        serviceConfig.UMask = "0077";
      } serviceOpts ]);
  };
  format = pkgs.formats.toml { };
in {
  options.services.prometheus.exporters.ping2 = mkExporterOpts { name = "ping2"; port = 9390; } // {
    config = mkOption {
      type = format.type;
      default = { };
      description = "Exporter config";
    };
  };
  config = mkExporterConf {
    name = "ping2";
    conf = cfg;
    serviceOpts = {
      serviceConfig = rec {
        # netns switching
        AmbientCapabilities = [
          # set network namespace
          "CAP_SYS_ADMIN"
          # open icmp socket
          "CAP_NET_RAW"
        ];
        CapabilityBoundingSet = AmbientCapabilities;
        RestrictNamespaces = lib.mkForce false;
        ExecStart = ''
          ${pkgs.ping-exporter}/bin/ping-exporter \
            --listen ${cfg.listenAddress}:${toString cfg.port} \
            --config ${format.generate "ping-exporter-config.toml" cfg.config} \
            ${lib.escapeShellArgs cfg.extraFlags}
        '';
      };
    };
  };
}
