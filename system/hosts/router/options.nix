{ lib
, notnft
, router-lib
, ... }:

{
  options.router-settings = {
    vpn = {
      tunnel = {
        mode = lib.mkOption {
          description = "tunnel mode";
          type = with lib.types; nullOr (enum [ "ssh" "sit" ]);
        };
        ifaceAddr = lib.mkOption {
          description = "interface cidr";
          type = router-lib.types.cidr;
        };
        localIp = lib.mkOption {
          description = "local ip";
          type = router-lib.types.ip;
        };
        localPort = lib.mkOption {
          description = "local port";
          type = lib.types.port;
        };
        remotePort = lib.mkOption {
          description = "remote port";
          type = lib.types.port;
        };
        ip = lib.mkOption {
          description = "remote ip";
          type = router-lib.types.ip;
        };
        port = lib.mkOption {
          description = "SSH port";
          type = lib.types.port;
          default = 22;
        };
        user = lib.mkOption {
          description = "SSH user";
          type = lib.types.str;
          default = "sshtunnel";
        };
      };
      openvpn.enable = lib.mkEnableOption "OpenVPN";
      openvpn.config = lib.mkOption {
        description = "OpenVPN config";
        type = lib.types.lines;
      };
      wireguard.enable = lib.mkEnableOption "Wireguard";
      wireguard.config = lib.mkOption {
        description = "wireguard config";
        type = lib.types.attrs;
      };
    };
    routerMac = lib.mkOption {
      description = "router's mac address";
      type = lib.types.str;
    };
    serverMac = lib.mkOption {
      description = "server's mac address";
      type = lib.types.str;
    };
    serverDuid = lib.mkOption {
      description = "server's duid";
      type = with lib.types; nullOr str;
      default = null;
    };
    serverInitrdMac = lib.mkOption {
      description = "server's mac address in initrd";
      type = lib.types.str;
    };
    serverInitrdDuid = lib.mkOption {
      description = "server's duid in initrd";
      type = with lib.types; nullOr str;
      default = null;
    };
    vacuumMac = lib.mkOption {
      description = "robot vacuum's mac address";
      type = lib.types.str;
    };
    lightBulbMac = lib.mkOption {
      description = "light bulb's mac address";
      type = lib.types.str;
    };
    naughtyMacs = lib.mkOption {
      description = "misbehaving (using wrong DNS server) clients' macs";
      type = with lib.types; listOf str;
    };
    network = lib.mkOption {
      description = "network gateway+cidr (ex: 192.168.1.1/24)";
      type = router-lib.types.cidr4;
    };
    network6 = lib.mkOption {
      description = "network gateway+cidr6 (ex: fd00:1234:5678:90ab::1/64)";
      type = router-lib.types.cidr6;
    };
    netnsNet = lib.mkOption {
      description = "private inter-netns communication network cidr+main netns addr (ex: 192.168.2.1/24)";
      type = router-lib.types.cidr4;
    };
    netnsNet6 = lib.mkOption {
      description = "private inter-netns communication network cidr6+main netns addr6 (ex: fd01:ba09:8765:4321::1/64)";
      type = router-lib.types.cidr6;
    };
    wanNetnsAddr = lib.mkOption {
      description = "ip to assign to wan netns";
      type = router-lib.types.ipv4;
    };
    wanNetnsAddr6 = lib.mkOption {
      description = "ipv6 to assign to wan netns";
      type = router-lib.types.ipv6;
    };
    wgNetwork = lib.mkOption {
      description = "wg network gateway+cidr (ex: 192.168.2.1/24)";
      type = router-lib.types.cidr4;
    };
    wgNetwork6 = lib.mkOption {
      description = "wg network gateway+cidr6 (ex: fd00:abab:8989:3434::1/64)";
      type = router-lib.types.cidr6;
    };
    wgPubkeys = lib.mkOption {
      description = "wg pubkeys";
      type = lib.types.listOf lib.types.str;
    };
    country_code = lib.mkOption {
      description = "wlan country_code (ex: US)";
      type = lib.types.str;
    };
    ssid = lib.mkOption {
      description = "wlan ssid";
      type = lib.types.str;
    };
    wpa_passphrase = lib.mkOption {
      description = "wlan passphrase";
      type = lib.types.str;
    };
    dhcpReservations = lib.mkOption {
      description = "dhcp reservations (ipv4)";
      default = [ ];
      type = lib.types.listOf (lib.types.submodule {
        options.ipAddress = lib.mkOption {
          type = router-lib.types.ipv4;
          description = "device's ip address";
        };
        options.macAddress = lib.mkOption {
          type = lib.types.str;
          description = "device's mac address";
        };
      });
    };
    dhcp6Reservations = lib.mkOption {
      description = "dhcp reservations (ipv6)";
      default = [ ];
      type = lib.types.listOf (lib.types.submodule {
        options.ipAddress = lib.mkOption {
          type = router-lib.types.ipv6;
          description = "device's ip address";
        };
        options.macAddress = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "device's mac address";
        };
        options.duid = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "device's duid";
        };
      });
    };
    dnatRules = lib.mkOption {
      description = "dnat (port forwarding) rules";
      default = [ ];
      type = lib.types.listOf (lib.types.submodule {
        options.inVpn = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "whether this is a vpn port forward";
        };
        options.mode = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = ''
            forward mode.
            snat = snat to router ip so routing is always correct; this mangles source ip and may not be desirable
            mark = change ct mark if the sport/saddr match the target
            rule = add an ip rule that does the above
            none = do nothing
            default = snat for target=router, mark otherwise
          '';
        };
        # at least one of target4/target6 must be set
        options.port = lib.mkOption {
          type = notnft.types.expression;
          description = "source port (nft expr)";
        };
        options.target4 = lib.mkOption {
          default = null;
          type = with lib.types; nullOr (submodule {
            options.address = lib.mkOption {
              type = router-lib.types.ipv4;
              description = "ipv4 address";
            };
            options.port = lib.mkOption {
              type = nullOr port;
              description = "target port";
              default = null;
            };
          });
          description = "port forwarding target (ipv4)";
        };
        options.target6 = lib.mkOption {
          default = null;
          type = with lib.types; nullOr (submodule {
            options.address = lib.mkOption {
              type = router-lib.types.ipv6;
              description = "ipv6 address";
            };
            options.port = lib.mkOption {
              type = nullOr port;
              description = "target port";
              default = null;
            };
          });
          description = "port forwarding target (ipv6)";
        };
        options.tcp = lib.mkOption {
          type = lib.types.bool;
          description = "whether to forward tcp";
        };
        options.udp = lib.mkOption {
          type = lib.types.bool;
          description = "whether to forward udp";
        };
      });
    };
  };
}
