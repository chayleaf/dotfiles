{ lib
, config
, pkgs
, utils
, ... }:

let
  cfg = config.router;
  # add x to last component of an ipv4
  addToLastComp4 = x: split:
    let
      n0 = lib.last split;
      nx = n0 + x;
      n = if nx >= 255 then 254 else if nx < 2 then 2 else nx;
    in
      if x > 0 && n0 >= 255 then null
      else if x < 0 && n0 < 2 then null
      else lib.init split ++ [ n ];
  # add x to last component of an ipv6
  addToLastComp6 = x: split:
    let
      n0 = lib.last split;
      nx = n0 + x;
      n = if nx >= 65535 then 65534 else if nx <= 2 then 2 else nx;
    in
      if x > 0 && n0 >= 65535 then null
      else if x < 0 && n0 < 2 then null
      else lib.init split ++ [ n ];
  # generate an integer of `total` bits with `set` most significant bits set
  genMask = total: set:
    parseBin (builtins.concatStringsSep "" (builtins.genList (i: if i < set then "1" else "0") total));
  # generate subnet mask for ipv4
  genMask4 = len:
    builtins.genList (i: let
      len' = len - i * 8;
    in
      if len' <= 0 then 0
      else if len' >= 8 then 255
      else genMask 8 len') 4;
  # generate subnet mask for ipv6
  genMask6 = len:
    builtins.genList (i: let
      len' = len - i * 16;
    in
      if len' <= 0 then 0
      else if len' >= 16 then 65535
      else genMask 16 len') 8;
  # invert a mask
  invMask4 = map (builtins.bitXor 255);
  invMask6 = map (builtins.bitXor 65535);
  orMask = lib.zipListsWith builtins.bitOr;
  andMask = lib.zipListsWith builtins.bitAnd;
  # parses hexadecimal number
  parseHex = x: (builtins.fromTOML "x=0x${x}").x;
  # parses binary number
  parseBin = x: (builtins.fromTOML "x=0b${x}").x;
  # finds the longest zero-only sequence
  # returns an attrset with maxS (start of the sequence) and max (sequence length)
  longestZeroSeq =
    builtins.foldl' ({ cur, max, curS, maxS, i }: elem: let self = {
      i = i + 1;
      cur = if elem == 0 then cur + 1 else 0;
      max = if max >= self.cur then max else self.cur;
      curS = if self.cur > 0 && cur > 0 then curS else if self.cur > 0 then i else -1;
      maxS = if max >= self.cur then maxS else self.curS;
    }; in self) { cur = 0; max = 0; curS = -1; maxS = -1; i = 0; };
  # parses an IPv4 address
  parseIp4 = x: map builtins.fromJSON (lib.splitString "." x);
  # serializes an IPv4 address
  compIp4 = x: builtins.concatStringsSep "." (map toString x);
  # parses an IPv6 address
  parseIp6 = x:
    let
      nzparts = map (x: if x == "" then [] else map parseHex (lib.splitString ":" x)) (lib.splitString "::" x);
    in
      if builtins.length nzparts == 1 then builtins.head nzparts
      else let a = builtins.head nzparts; b = builtins.elemAt nzparts 1; in
      a ++ (builtins.genList (_: 0) (8 - builtins.length a - builtins.length b)) ++ b;
  # serializes an IPv6 address
  compIp6 = x:
    let
      long = longestZeroSeq x;
      joined = builtins.concatStringsSep ":" (builtins.foldl' ({ i, res }: x: {
        i = i + 1;
        res = res ++ (if i >= long.maxS && i < long.maxS + long.max then [ "" ] else [ (lib.toLower (lib.toHexString x)) ]);
      }) { i = 0; res = [ ]; } x).res;
      fix = builtins.replaceStrings [":::"] ["::"];
    in
      fix (fix (fix (fix (fix joined))));
  format = pkgs.formats.json {};
  package = pkgs.kea;
  commonServiceConfig = {
    ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
    DynamicUser = true;
    User = "kea";
    ConfigurationDirectory = "kea";
    RuntimeDirectory = "kea";
    StateDirectory = "kea";
    UMask = "0077";
  };
in {
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (let
      configs = builtins.mapAttrs (interface: icfg:
      let
        escapedInterface = utils.escapeSystemdPath interface;
        cfg4 = icfg.ipv4.kea;
      in if cfg4.configFile != null then cfg4.configFile else (format.generate "kea-dhcp4-${escapedInterface}.conf" {
        Dhcp4 = {
          valid-lifetime = 4000;
          interfaces-config.interfaces = [ interface ];
          lease-database = {
            type = "memfile";
            persist = true;
            name = "/var/lib/kea/dhcp4-${escapedInterface}.leases";
          };
          subnet4 = map ({ address, prefixLength, gateways, dns, keaSettings, ... }:
          let
            subnetMask = genMask4 prefixLength;
            parsed = parseIp4 address;
            minIp = andMask subnetMask parsed;
            maxIp = orMask (invMask4 subnetMask) parsed;
          in {
            subnet = "${address}/${toString prefixLength}";
            option-data =
              lib.optional (dns != [ ]) {
                name = "domain-name-servers";
                code = 6;
                csv-format = true;
                space = "dhcp4";
                data = builtins.concatStringsSep ", " dns;
              }
              ++ lib.optional (gateways != [ ]) {
                name = "routers";
                code = 3;
                csv-format = true;
                space = "dhcp4";
                data = builtins.concatStringsSep ", " gateways;
              };
            pools = let
              a = addToLastComp4 16 minIp;
              b = addToLastComp4 (-16) parsed;
              c = addToLastComp4 16 parsed;
              d = addToLastComp4 (-16) maxIp;
            in
              lib.optional (a != null && b != null && a <= b) { pool = "${compIp4 a}-${compIp4 b}"; }
              ++ lib.optional (c != null && d != null && c <= d) { pool = "${compIp4 c}-${compIp4 d}"; };
          } // keaSettings) icfg.ipv4.addresses;
        } // cfg4.settings;
      })) cfg.interfaces;
    in {
      environment.etc = lib.mapAttrs' (interface: icfg: {
        name = "kea/dhcp4-server-${utils.escapeSystemdPath interface}.conf";
        value = lib.mkIf (icfg.ipv4.kea.enable && icfg.ipv4.addresses != [ ]) {
          source = configs.${interface};
        };
      }) cfg.interfaces;
      systemd.services = lib.mapAttrs' (interface: icfg: let
        escapedInterface = utils.escapeSystemdPath interface;
      in {
        name = "kea-dhcp4-server-${escapedInterface}";
        value = lib.mkIf (icfg.ipv4.kea.enable && icfg.ipv4.addresses != [ ]) {
          description = "Kea DHCP4 Server (${interface})";
          documentation = [ "man:kea-dhcp4(8)" "https://kea.readthedocs.io/en/kea-${package.version}/arm/dhcp4-srv.html" ];
          after = [ "network-online.target" "time-sync.target" "sys-subsystem-net-devices-${escapedInterface}.device" ];
          bindsTo = [ "sys-subsystem-net-devices-${escapedInterface}.device" ];
          wantedBy = [ "multi-user.target" ];
          environment = { KEA_PIDFILE_DIR = "/run/kea"; KEA_LOCKFILE_DIR = "/run/kea"; };
          restartTriggers = [ configs.${interface} ];

          serviceConfig = {
            ExecStart = "${package}/bin/kea-dhcp4 -c "
              + lib.escapeShellArgs ([ "/etc/kea/dhcp4-server-${escapedInterface}.conf" ]);
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
          } // commonServiceConfig;
        };
      }) cfg.interfaces;
    })
    (let
      configs = builtins.mapAttrs (interface: icfg:
      let
        escapedInterface = utils.escapeSystemdPath interface;
        cfg6 = icfg.ipv6.kea;
      in if cfg6.configFile != null then cfg6.configFile else (format.generate "kea-dhcp6-${escapedInterface}.conf" {
        Dhcp6 = {
          valid-lifetime = 4000;
          preferred-lifetime = 3000;
          interfaces-config.interfaces = [ interface ];
          lease-database = {
            type = "memfile";
            persist = true;
            name = "/var/lib/kea/dhcp6-${escapedInterface}.leases";
          };
          subnet6 = map ({ address, prefixLength, dns, keaSettings, ... }:
          let
            subnetMask = genMask6 prefixLength;
            parsed = parseIp6 address;
            minIp = andMask subnetMask parsed;
            maxIp = orMask (invMask6 subnetMask) parsed;
          in {
            option-data =
              lib.optional (dns != [ ]) {
                name = "dns-servers";
                code = 23;
                csv-format = true;
                space = "dhcp6";
                data = builtins.concatStringsSep ", " (map (x: if builtins.isString x then x else x.address) dns);
              };
            subnet = "${address}/${toString prefixLength}";
            pools = let
              a = addToLastComp6 16 minIp;
              b = addToLastComp6 (-16) parsed;
              c = addToLastComp6 16 parsed;
              d = addToLastComp6 (-16) maxIp;
            in
              lib.optional (a != null && b != null && a <= b) {
                pool = "${compIp6 a}-${compIp6 b}";
              } ++ lib.optional (c != null && d != null && c <= d) {
                pool = "${compIp6 c}-${compIp6 d}";
              };
          } // keaSettings) icfg.ipv6.addresses;
        } // cfg6.settings;
      })) cfg.interfaces;
    in {
      environment.etc = lib.mapAttrs' (interface: icfg: {
        name = "kea/dhcp6-server-${utils.escapeSystemdPath interface}.conf";
        value = lib.mkIf (icfg.ipv6.kea.enable && icfg.ipv6.addresses != [ ]) {
          source = configs.${interface};
        };
      }) cfg.interfaces;
      systemd.services = lib.mapAttrs' (interface: icfg: let
        escapedInterface = utils.escapeSystemdPath interface;
      in {
        name = "kea-dhcp6-server-${escapedInterface}";
        value = lib.mkIf (icfg.ipv6.kea.enable && icfg.ipv6.addresses != [ ]) {
          description = "Kea DHCP6 Server (${interface})";
          documentation = [ "man:kea-dhcp6(8)" "https://kea.readthedocs.io/en/kea-${package.version}/arm/dhcp6-srv.html" ];
          after = [ "network-online.target" "time-sync.target" "sys-subsystem-net-devices-${escapedInterface}.device" ];
          bindsTo = [ "sys-subsystem-net-devices-${escapedInterface}.device" ];
          wantedBy = [ "multi-user.target" ];
          environment = { KEA_PIDFILE_DIR = "/run/kea"; KEA_LOCKFILE_DIR = "/run/kea"; };
          restartTriggers = [ configs.${interface} ];

          serviceConfig = {
            ExecStart = "${package}/bin/kea-dhcp6 -c "
              + lib.escapeShellArgs ([ "/etc/kea/dhcp6-server-${escapedInterface}.conf" ]);
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
          } // commonServiceConfig;
        };
      }) cfg.interfaces;
    })
  ]);
}
