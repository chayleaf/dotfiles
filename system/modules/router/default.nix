{ lib
, config
, pkgs
, ... }:

let
  cfg = config.router;
in {
  imports = [
    /*./avahi.nix*/
    ./hostapd.nix
    ./kea.nix
    ./radvd.nix
    ./corerad.nix
  ];

  options.router = {
    enable = lib.mkEnableOption "router config";
    interfaces = lib.mkOption {
      default = { };
      description = "All interfaces managed by the router";
      type = lib.types.attrsOf (lib.types.submodule {
        options.matchUdevAttrs = lib.mkOption {
          default = { };
          description = lib.mdDoc ''
            When a device with those attrs is detected by udev, the device is automatically renamed to this interface name.

            See [kernel docs](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/ABI/testing/sysfs-class-net?h=linux-6.3.y) for the list of attrs available.
          '';
          example = lib.literalExpression { address = "11:22:33:44:55:66"; };
          type = lib.types.attrs;
        };
        options.bridge = lib.mkOption {
          description = "Add this device to this bridge";
          default = null;
          type = with lib.types; nullOr str;
        };
        options.macAddress = lib.mkOption {
          description = "Change this device's mac address to this";
          default = null;
          type = with lib.types; nullOr str;
        };
        options.hostapd = lib.mkOption {
          description = "hostapd options";
          default = { };
          type = lib.types.submodule {
            options.enable = lib.mkEnableOption "hostapd";
            options.settings = lib.mkOption {
              description = "hostapd config";
              default = { };
              type = lib.types.attrs;
            };
          };
        };
        options.dhcpcd = lib.mkOption {
          description = "dhcpcd options";
          default = { };
          type = lib.types.submodule {
            options.enable = lib.mkEnableOption "dhcpcd";
            options.extraConfig = lib.mkOption {
              description = "dhcpcd text config";
              default = "";
              type = lib.types.lines;
            };
          };
        };
        options.ipv4 = lib.mkOption {
          description = "IPv4 config";
          default = { };
          type = lib.types.submodule {
            options.addresses = lib.mkOption {
              description = "Device's IPv4 addresses";
              default = [ ];
              type = lib.types.listOf (lib.types.submodule {
                options.address = lib.mkOption {
                  description = "IPv4 address";
                  type = lib.types.str;
                };
                options.prefixLength = lib.mkOption {
                  description = "IPv4 prefix length";
                  type = lib.types.int;
                };
                options.assign = lib.mkOption {
                  description = "Whether to assign this address to the device. Default: no if the first hextet is zero, yes otherwise.";
                  type = with lib.types; nullOr bool;
                  default = null;
                };
                options.gateways = lib.mkOption {
                  description = "IPv4 gateway addresses (optional)";
                  default = [ ];
                  type = with lib.types; listOf str;
                };
                options.dns = lib.mkOption {
                  description = "IPv4 DNS servers associated with this device";
                  type = with lib.types; listOf str;
                  default = [ ];
                };
                options.keaSettings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.json {}).type;
                  example = lib.literalExpression {
                    pools = [ { pool = "192.168.1.15 - 192.168.1.200"; } ];
                    option-data = [ {
                      name = "domain-name-servers";
                      code = 6;
                      csv-format = true;
                      space = "dhcp4";
                      data = "8.8.8.8, 8.8.4.4";
                    } ];
                  };
                  description = "Kea IPv4 prefix-specific settings";
                };
              });
            };
            options.kea = lib.mkOption {
              description = "Kea options";
              default = { };
              type = lib.types.submodule {
                options.enable = lib.mkOption {
                  type = lib.types.bool;
                  description = "Enable Kea for IPv4";
                  default = true;
                };
                options.extraArgs = lib.mkOption {
                  type = with lib.types; listOf str;
                  default = [ ];
                  description = "List of additional arguments to pass to the daemon.";
                };
                options.configFile = lib.mkOption {
                  type = with lib.types; nullOr path;
                  default = null;
                  description = "Kea config file (takes precedence over settings)";
                };
                options.settings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.json {}).type;
                  description = "Kea settings";
                };
              };
            };
          };
        };
        options.ipv6 = lib.mkOption {
          description = "IPv6 config";
          default = { };
          type = lib.types.submodule {
            options.addresses = lib.mkOption {
              description = "Device's IPv6 addresses";
              default = [ ];
              type = lib.types.listOf (lib.types.submodule {
                options.address = lib.mkOption {
                  description = "IPv6 address";
                  type = lib.types.str;
                };
                options.prefixLength = lib.mkOption {
                  description = "IPv6 prefix length";
                  type = lib.types.int;
                };
                options.assign = lib.mkOption {
                  description = "Whether to assign this address to the device. Default: no if the first hextet is zero, yes otherwise";
                  type = with lib.types; nullOr bool;
                  default = null;
                };
                options.gateways = lib.mkOption {
                  description = "IPv6 gateways information (optional)";
                  default = [ ];
                  type = with lib.types; listOf (either str (submodule {
                    options.address = lib.mkOption {
                      description = "Gateway's IPv6 address";
                      type = str;
                    };
                    options.prefixLength = lib.mkOption {
                      description = "Gateway's IPv6 prefix length (defaults to interface address's prefix length)";
                      type = nullOr int;
                      default = null;
                    };
                    options.radvdSettings = lib.mkOption {
                      default = { };
                      type = attrsOf (oneOf [ bool str int ]);
                      example = lib.literalExpression {
                        AdvRoutePreference = "high";
                      };
                      description = "radvd prefix-specific route settings";
                    };
                    options.coreradSettings = lib.mkOption {
                      default = { };
                      type = (pkgs.formats.toml {}).type;
                      example = lib.literalExpression {
                        preference = "high";
                      };
                      description = "CoreRAD prefix-specific route settings";
                    };
                  }));
                };
                options.dns = lib.mkOption {
                  description = "IPv6 DNS servers associated with this device";
                  type = with lib.types; listOf (either str (submodule {
                    options.address = lib.mkOption {
                      description = "DNS server's address";
                      type = lib.types.str;
                    };
                    options.radvdSettings = lib.mkOption {
                      default = { };
                      type = attrsOf (oneOf [ bool str int ]);
                      example = lib.literalExpression { FlushRDNSS = false; };
                      description = "radvd prefix-specific RDNSS settings";
                    };
                    options.coreradSettings = lib.mkOption {
                      default = { };
                      type = (pkgs.formats.toml {}).type;
                      example = lib.literalExpression { lifetime = "auto"; };
                      description = "CoreRAD prefix-specific RDNSS settings";
                    };
                  }));
                  default = [ ];
                };
                options.keaSettings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.json {}).type;
                  example = lib.literalExpression {
                    pools = [ {
                      pool = "192.168.1.15 - 192.168.1.200";
                    } ];
                    option-data = [ {
                      name = "dns-servers";
                      code = 23;
                      csv-format = true;
                      space = "dhcp6";
                      data = "aaaa::, bbbb::";
                    } ];
                  };
                  description = "Kea prefix-specific settings";
                };
                options.radvdSettings = lib.mkOption {
                  default = { };
                  type = with lib.types; attrsOf (oneOf [ bool str int ]);
                  example = lib.literalExpression {
                    AdvOnLink = true;
                    AdvAutonomous = true;
                    Base6to4Interface = "ppp0";
                  };
                  description = "radvd prefix-specific settings";
                };
                options.coreradSettings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.toml {}).type;
                  example = lib.literalExpression {
                    on_link = true;
                    autonomous = true;
                  };
                  description = "CoreRAD prefix-specific settings";
                };
              });
            };
            options.kea = lib.mkOption {
              description = "Kea options";
              default = { };
              type = lib.types.submodule {
                options.enable = lib.mkEnableOption "Kea for IPv6";
                options.extraArgs = lib.mkOption {
                  type = with lib.types; listOf str;
                  default = [ ];
                  description = "List of additional arguments to pass to the daemon.";
                };
                options.configFile = lib.mkOption {
                  type = with lib.types; nullOr path;
                  default = null;
                  description = "Kea config file (takes precedence over settings)";
                };
                options.settings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.json {}).type;
                  description = "Kea settings";
                };
              };
            };
            options.radvd = lib.mkOption {
              description = "radvd options";
              default = { };
              type = lib.types.submodule {
                options.enable = lib.mkOption {
                  type = lib.types.bool;
                  description = "Enable radvd";
                  default = true;
                };
                options.interfaceSettings = lib.mkOption {
                  default = { };
                  type = with lib.types; attrsOf (oneOf [ bool str int ]);
                  example = lib.literalExpression {
                    UnicastOnly = true;
                  };
                  description = "radvd interface-specific settings";
                };
              };
            };
            options.corerad = lib.mkOption {
              description = "CoreRAD options";
              default = { };
              type = lib.types.submodule {
                options.enable = lib.mkEnableOption "CoreRAD (don't forget to disable radvd)";
                options.configFile = lib.mkOption {
                  type = with lib.types; nullOr path;
                  default = null;
                  description = "CoreRAD config file (takes precedence over settings)";
                };
                options.interfaceSettings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.toml {}).type;
                  description = "CoreRAD interface-specific settings";
                };
                options.settings = lib.mkOption {
                  default = { };
                  type = (pkgs.formats.toml {}).type;
                  example = lib.literalExpression {
                    debug.address = "localhost:9430";
                    debug.prometheus = true;
                  };
                  description = "General CoreRAD settings";
                };
              };
            };
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      dig.dnsutils
      ethtool
      tcpdump
    ];

    # performance tweaks
    powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
    services.irqbalance.enable = lib.mkDefault true;
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_xanmod;

    boot.kernel.sysctl = {
      "net.netfilter.nf_log_all_netns" = true;
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv4.conf.default.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = config.networking.enableIPv6;
      "net.ipv6.conf.default.forwarding" = config.networking.enableIPv6;
    };

    networking.enableIPv6 = lib.mkDefault true;
    networking.usePredictableInterfaceNames = true;
    networking.firewall.allowPing = lib.mkDefault true;
    networking.firewall.rejectPackets = lib.mkDefault false; # drop rather than reject
    services.udev.extraRules =
      let
        devs = lib.filterAttrs (k: v: (v.matchUdevAttrs or { }) != { }) cfg.interfaces;
      in lib.mkIf (devs != { })
        (builtins.concatStringsSep "\n" (lib.mapAttrsToList (k: v:
        let
          attrs = lib.mapAttrsToList (k: v: "ATTR{${k}}==${builtins.toJSON (toString v)}") v.matchUdevAttrs;
        in ''
          SUBSYSTEM=="net", ACTION=="add", ${builtins.concatStringsSep ", " attrs}, NAME="${k}"
        '') devs));
    networking.interfaces = builtins.mapAttrs (interface: icfg: {
      ipv4.addresses = map
        ({ address, prefixLength, ... }: { inherit address prefixLength; })
        (builtins.filter
          (x: x.assign == true || (x.assign == null && (lib.hasPrefix "0." x.address)))
          icfg.ipv4.addresses);
      ipv6.addresses = map
        ({ address, prefixLength, ... }: { inherit address prefixLength; })
        (builtins.filter
          (x: x.assign == true || (x.assign == null && (lib.hasPrefix ":" x.address || lib.hasPrefix "0:" x.address)))
          icfg.ipv6.addresses);
    } // lib.optionalAttrs (icfg.macAddress != null) {
      inherit (icfg) macAddress;
    }) cfg.interfaces;
    networking.bridges =
      builtins.zipAttrsWith
        (k: vs: { interfaces = vs; })
        (lib.mapAttrsToList
          (interface: icfg:
            if icfg.bridge != null && !icfg.hostapd.enable then {
              ${icfg.bridge} = interface;
            } else {})
          cfg.interfaces);
    networking.useDHCP = lib.mkIf (builtins.any (x: x.dhcpcd.enable) (builtins.attrValues cfg.interfaces)) false;
  };
}
