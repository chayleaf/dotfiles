{ config
, pkgs
, notnft
, lib
, router-lib
, server-config
, ... }:

let
  cfg = config.router-settings;
  hapdConfig = {
    inherit (cfg) country_code wpa_passphrase;
    he_su_beamformer = true;
    he_su_beamformee = true;
    he_mu_beamformer = true;
    he_spr_sr_control = 3;
    he_default_pe_duration = 4;
    he_rts_threshold = 1023;
    he_mu_edca_qos_info_param_count = 0;
    he_mu_edca_qos_info_q_ack = 0;
    he_mu_edca_qos_info_queue_request = 0;
    he_mu_edca_qos_info_txop_request = 0;
    he_mu_edca_ac_be_aifsn = 8;
    he_mu_edca_ac_be_aci = 0;
    he_mu_edca_ac_be_ecwmin = 9;
    he_mu_edca_ac_be_ecwmax = 10;
    he_mu_edca_ac_be_timer = 255;
    he_mu_edca_ac_bk_aifsn = 15;
    he_mu_edca_ac_bk_aci = 1;
    he_mu_edca_ac_bk_ecwmin = 9;
    he_mu_edca_ac_bk_ecwmax = 10;
    he_mu_edca_ac_bk_timer = 255;
    he_mu_edca_ac_vi_ecwmin = 5;
    he_mu_edca_ac_vi_ecwmax = 7;
    he_mu_edca_ac_vi_aifsn = 5;
    he_mu_edca_ac_vi_aci = 2;
    he_mu_edca_ac_vi_timer = 255;
    he_mu_edca_ac_vo_aifsn = 5;
    he_mu_edca_ac_vo_aci = 3;
    he_mu_edca_ac_vo_ecwmin = 5;
    he_mu_edca_ac_vo_ecwmax = 7;
    he_mu_edca_ac_vo_timer = 255;
    preamble = true;
    country3 = "0x49"; # indoor
  };

  # routing tables
  wan_table = 1;
  # vpn table, assign an id but don't actually add a rule for it, so it is the default
  vpn_table = 2;

  vpn_mtu = config.networking.wireguard.interfaces.wg0.mtu;
  vpn_ipv4_mss = vpn_mtu - 40;
  vpn_ipv6_mss = vpn_mtu - 60;

  dnatRuleMode = rule:
    if rule.mode != "" then rule.mode
    else if rule.target4.address or null == netAddresses.lan4 || rule.target6.address or null == netAddresses.lan6 then "rule"
    else "mark";

  dnatRuleProtos = rule:
    let
      inherit (notnft.inetProtos) tcp udp;
    in
      if rule.tcp && rule.udp then notnft.dsl.set [ tcp udp ]
      else if rule.tcp then tcp
      else if rule.udp then udp
      else throw "Invalid rule: either tcp or udp must be set";

  setIfNeeded = arr:
    if builtins.length arr == 1 then builtins.head arr
    else notnft.dsl.set arr;

  # nftables rules generator
  # selfIp4/selfIp6 = block packets from these addresses
  # extraInetEntries = stuff to add to inet table
  # extraNetdevEntries = stuff to add to netdev table
  # wans = external interfaces (internet)
  # lans = internal interfaces (lan)
  # netdevIngressWanRules = additional rules for ingress (netdev)
  # inetInboundWanRules = additional rules for input from wan (inet)
  # inetInboundLanRules = same for lan
  # inetForwardRules = additional forward rules besides allow lan->wan forwarding
  # inetSnatRules = snat rules (changing source address, usually just called nat)
  # inetDnatRules = dnat rules (changing destination address, i.e. port forwarding)
  # logPrefix = log prefix for drops
  mkRules = {
    selfIp4,
    selfIp6,
    extraInetEntries ? {},
    extraNetdevEntries ? {},
    wans,
    lans,
    netdevIngressWanRules ? [],
    inetInboundWanRules ? [],
    inetInboundLanRules ? [],
    inetForwardRules ? [],
    inetSnatRules ? [],
    inetDnatRules ? [],
    logPrefix ? "",
  }:
  let
    logIfWan = prefix: lib.optional (logPrefix == "wan") (notnft.dsl.log prefix);
  in with notnft.dsl; with payload; ruleset {
    filter = add table.netdev ({
      ingress_common = add chain
        ([(is.eq (bit.and tcp.flags (f: bit.or f.fin f.syn)) (f: bit.or f.fin f.syn))] ++ logIfWan "${logPrefix}fin+syn drop " ++ [drop])
        ([(is.eq (bit.and tcp.flags (f: bit.or f.syn f.rst)) (f: bit.or f.syn f.rst))] ++ logIfWan "${logPrefix}syn+rst drop " ++ [drop])
        [(is.eq (bit.and tcp.flags (f: with f; bit.or fin syn rst psh ack urg)) 0) (log "${logPrefix}null drop ") drop]
        [(is tcp.flags (f: f.syn)) (is.eq tcpOpt.maxseg.size (range 0 500)) (log "${logPrefix}maxseg drop ") drop]
        # reject requests with own saddr
        # log if they are meant for us...
        [(is.eq ip.saddr selfIp4) (is.eq (fib (f: with f; [ daddr iif ]) (f: f.type)) (f: f.local)) (log "${logPrefix}self4 ") drop]
        [(is.eq ip6.saddr selfIp6) (is.eq (fib (f: with f; [ daddr iif ]) (f: f.type)) (f: f.local)) (log "${logPrefix}self6 ") drop]
        # ...but ignore if they're multicast/broadcast
        [return];

      ingress_lan_common = add chain
        # there are some issues with this, disable it for lan
        # [(is.eq (fib (f: with f; [ saddr mark iif ]) (f: f.oif)) missing) (log "${logPrefix}oif missing ") drop]
        inetInboundLanRules
        [(jump "ingress_common")];

      ingress_wan_common = add chain
        netdevIngressWanRules
        [(jump "ingress_common")]
        # [(is.ne (fib (f: with f; [ daddr iif ]) (f: f.type)) (f: set [ f.local f.broadcast f.multicast ])) (log "${logPrefix}non-{local,broadcast,multicast} ") drop]
        # separate limits for echo-request and all other icmp types
        [(is.eq ip.protocol (f: f.icmp)) (is.eq icmp.type (f: f.echo-request)) (limit { rate = 50; per = f: f.second; }) accept]
        [(is.eq ip.protocol (f: f.icmp)) (is.ne icmp.type (f: f.echo-request)) (limit { rate = 100; per = f: f.second; }) accept]
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.eq icmpv6.type (f: f.echo-request)) (limit { rate = 50; per = f: f.second; }) accept]
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.ne icmpv6.type (f: f.echo-request)) (limit { rate = 100; per = f: f.second; }) accept]
        # always accept destination unreachable, time-exceeded, parameter-problem, packet-too-big
        [(is.eq ip.protocol (f: f.icmp)) (is.eq icmp.type (f: with f; set [ destination-unreachable time-exceeded parameter-problem ])) accept]
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.eq icmpv6.type (f: with f; set [ destination-unreachable time-exceeded parameter-problem packet-too-big ])) accept]
        # don't log echo-request drops
        [(is.eq ip.protocol (f: f.icmp)) (is.eq icmp.type (f: f.echo-request)) drop]
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.eq icmpv6.type (f: f.echo-request)) drop]
        [(is.eq ip.protocol (f: f.icmp)) (log "${logPrefix}icmp flood ") drop]
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (log "${logPrefix}icmp6 flood ") drop];
    }
    // extraNetdevEntries
    // builtins.listToAttrs (map (name: {
      name = "ingress_${name}";
      value = add chain { type = f: f.filter; hook = f: f.ingress; dev = name; prio = -500; policy = f: f.accept; }
        [(jump "ingress_lan_common")];
    }) lans)
    // builtins.listToAttrs (map (name: {
      name = "ingress_${name}";
      value = add chain { type = f: f.filter; hook = f: f.ingress; dev = name; prio = -500; policy = f: f.accept; }
        [(jump "ingress_wan_common")];
    }) wans));
    global = add table { family = f: f.inet; } ({
      inbound_wan_common = add chain
        [(vmap ct.state { established = accept; related = accept; invalid = drop; })]
        [(is ct.status (f: f.dnat)) accept]
        ([(is.eq (bit.and tcp.flags (f: f.syn)) 0) (is.eq ct.state (f: f.new))] ++ logIfWan "${logPrefix}new non-syn " ++ [drop])
        # icmp: only accept ping requests
        [(is.eq ip.protocol (f: f.icmp)) (is.eq icmp.type (f: f.echo-request)) accept]
        # icmpv6: accept no-route info from link-local addresses
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.eq ip6.saddr (cidr "fe80::/10")) (is.eq icmpv6.code (f: f.no-route))
          (is.eq icmpv6.type (f: with f; set [ mld-listener-query mld-listener-report mld-listener-done mld2-listener-report ]))
          accept]
        # icmpv6: accept commonly useful stuff
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.eq icmpv6.type (f: with f; set [ destination-unreachable time-exceeded echo-request echo-reply ])) accept]
        # icmpv6: more common stuff
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.eq icmpv6.code (f: f.no-route))
          (is.eq icmpv6.type (f: with f; set [ packet-too-big parameter-problem ])) accept]
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.eq icmpv6.code (f: f.admin-prohibited))
          (is.eq icmpv6.type (f: f.parameter-problem)) accept]
        inetInboundWanRules;

      # trust the lan
      inbound_lan_common = add chain
        [accept];

      inbound = add chain { type = f: f.filter; hook = f: f.input; prio = f: f.filter; policy = f: f.drop; }
        [(vmap meta.iifname ({
            lo = accept;
          }
          // lib.genAttrs lans (_: jump "inbound_lan_common")
          // lib.genAttrs wans (_: jump "inbound_wan_common")
        ))];
        #[(log "${logPrefix}inbound drop ")];

      forward = add chain { type = f: f.filter; hook = f: f.forward; prio = f: f.filter; policy = f: f.drop; }
        [(vmap ct.state { established = accept; related = accept; invalid = drop; })]
        [(is ct.status (f: f.dnat)) accept]
        # accept lan->wan fw
        [(is.eq meta.iifname (setIfNeeded lans)) (is.eq meta.oifname (setIfNeeded wans)) accept]
        # accept lan->lan fw
        [(is.eq meta.iifname (setIfNeeded lans)) (is.eq meta.oifname (setIfNeeded lans)) accept]
        # accept wan->lan icmpv6 forward
        [(is.eq meta.iifname (setIfNeeded wans)) (is.eq icmpv6.type (f: with f; set [ destination-unreachable time-exceeded echo-request echo-reply ])) accept]
        [(is.eq meta.iifname (setIfNeeded wans)) (is.eq icmpv6.code (f: f.no-route)) (is.eq icmpv6.type (f: with f; set [ packet-too-big parameter-problem ])) accept]
        [(is.eq meta.iifname (setIfNeeded wans)) (is.eq icmpv6.code (f: f.admin-prohibited)) (is.eq icmpv6.type (f: f.parameter-problem)) accept]
        inetForwardRules
        [(log "${logPrefix}forward drop ")];

      snat = add chain { type = f: f.nat; hook = f: f.postrouting; prio = f: f.srcnat; policy = f: f.accept; }
        # masquerade ipv6 because my isp doesn't provide it and my vpn gives a single ipv6
        [(is.eq meta.protocol (f: set [ f.ip f.ip6 ])) (is.eq meta.iifname (setIfNeeded lans)) (is.eq meta.oifname (setIfNeeded wans)) masquerade]
        inetSnatRules;

      dnat = add chain { type = f: f.nat; hook = f: f.prerouting; prio = f: f.dstnat; policy = f: f.accept; }
        inetDnatRules;
    } // extraInetEntries);
  };

  netAddressesWithPrefixLen = {
    lan4 = cfg.network;
    lan6 = cfg.network6;
    netns4 = cfg.netnsNet;
    netns6 = cfg.netnsNet6;
  };

  # parse a.b.c.d/x into { address, prefixLength }
  netParsedCidrs = builtins.mapAttrs (_: router-lib.parseCidr) netAddressesWithPrefixLen;

  # generate network cidr from device address
  # (normalizeCidr applies network mask to the address)
  netCidrs = builtins.mapAttrs (_: v: router-lib.serializeCidr (router-lib.normalizeCidr v)) netParsedCidrs;

  netAddresses = builtins.mapAttrs (_: v: v.address) netParsedCidrs // {
    netnsWan4 = cfg.wanNetnsAddr;
    netnsWan6 = cfg.wanNetnsAddr6;
  };

  parsedGatewayAddr4 = router-lib.parseIp4 netAddresses.lan4;
  parsedGatewayAddr6 = router-lib.parseIp6 netAddresses.lan6;

  addToIp' = ip: n: lib.init ip ++ [ (lib.last ip + n) ];
  addToIp = ip: n: router-lib.serializeIp (addToIp' ip n);

  # server
  serverAddress4 = addToIp parsedGatewayAddr4 1;
  serverAddress6 = addToIp parsedGatewayAddr6 1;
  # robot vacuum (valetudo)
  vacuumAddress4 = addToIp parsedGatewayAddr4 2;
  vacuumAddress6 = addToIp parsedGatewayAddr6 2;
  # light bulb (tasmota)
  lightBulbAddress4 = addToIp parsedGatewayAddr4 3;
  lightBulbAddress6 = addToIp parsedGatewayAddr6 3;
  # server in initrd
  serverInitrdAddress4 = addToIp parsedGatewayAddr4 4;
  serverInitrdAddress6 = addToIp parsedGatewayAddr6 4;

  hosted-domains =
    builtins.filter (domain: domain != "localhost")
      (builtins.concatLists
        (builtins.attrValues
          (builtins.mapAttrs
            (k: v: [ k ] ++ v.serverAliases)
            server-config.services.nginx.virtualHosts)));
in {
  imports = [ ./options.nix ./metrics.nix ];
  system.stateVersion = "22.11";

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.src_valid_mark" = true;
    "net.ipv4.conf.default.src_valid_mark" = true;
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  services.openssh.enable = true;
  services.fail2ban = {
    enable = true;
    ignoreIP = [ netCidrs.lan4 netCidrs.lan6 ];
    maxretry = 10;
  };

  router-settings.dhcpReservations = [
    { ipAddress = serverAddress4;
      macAddress = cfg.serverMac; }
    { ipAddress = vacuumAddress4;
      macAddress = cfg.vacuumMac; }
    { ipAddress = lightBulbAddress4;
      macAddress = cfg.lightBulbMac; }
    { ipAddress = serverInitrdAddress4;
      macAddress = cfg.serverInitrdMac; }
  ];
  router-settings.dhcp6Reservations = [
    { ipAddress = serverAddress6;
      duid = cfg.serverDuid;
      macAddress = cfg.serverMac; }
    { ipAddress = vacuumAddress6;
      macAddress = cfg.vacuumMac; }
    { ipAddress = lightBulbAddress6;
      macAddress = cfg.lightBulbMac; }
    { ipAddress = serverInitrdAddress6;
      macAddress = cfg.serverInitrdMac; }
  ];

  # dnat to server, take ports from its firewall config
  router-settings.dnatRules = let
    bannedPorts = [
      631 9100 # printing
      5353 # avahi
    ];
    inherit (server-config.networking.firewall) allowedTCPPorts allowedTCPPortRanges allowedUDPPorts allowedUDPPortRanges;

    tcpAndUdp = builtins.filter (x: !builtins.elem x bannedPorts && builtins.elem x allowedTCPPorts) allowedUDPPorts;
    tcpOnly = builtins.filter (x: !builtins.elem x (bannedPorts ++ allowedUDPPorts)) allowedTCPPorts;
    udpOnly = builtins.filter (x: !builtins.elem x (bannedPorts ++ allowedTCPPorts)) allowedUDPPorts;

    rangesTcpAndUdp = builtins.filter (x: builtins.elem x allowedTCPPortRanges) allowedUDPPortRanges;
    rangesTcpOnly = builtins.filter (x: !builtins.elem x allowedUDPPortRanges) allowedTCPPortRanges;
    rangesUdpOnly = builtins.filter (x: !builtins.elem x allowedTCPPortRanges) allowedUDPPortRanges;
  in lib.optional (tcpAndUdp != [ ]) {
    port = setIfNeeded tcpAndUdp; tcp = true; udp = true;
    target4.address = serverAddress4; target6.address = serverAddress6;
  } ++ lib.optional (tcpOnly != [ ]) {
    port = setIfNeeded tcpOnly; tcp = true; udp = false;
    target4.address = serverAddress4; target6.address = serverAddress6;
  } ++ lib.optional (udpOnly != [ ]) {
    port = setIfNeeded udpOnly; tcp = false; udp = true;
    target4.address = serverAddress4; target6.address = serverAddress6;
  } ++ lib.flip map rangesTcpAndUdp (range: {
    port = notnft.dsl.range range.from range.to; tcp = true; udp = true;
    target4.address = serverAddress4; target6.address = serverAddress6;
  }) ++ lib.flip map rangesTcpOnly (range: {
    port = notnft.dsl.range range.from range.to; tcp = true; udp = false;
    target4.address = serverAddress4; target6.address = serverAddress6;
  }) ++ lib.flip map rangesUdpOnly (range: {
    port = notnft.dsl.range range.from range.to; tcp = false; udp = true;
    target4.address = serverAddress4; target6.address = serverAddress6;
  }) ++ lib.toList {
    port = 24; tcp = true; udp = true; target4.port = 22; target6.port = 22;
    target4.address = serverInitrdAddress4; target6.address = serverInitrdAddress6;
  };

  router.enable = true;
  # 2.4g ap
  router.interfaces.wlan0 = {
    bridge = "br0";
    hostapd.enable = true;
    hostapd.settings = {
      inherit (cfg) ssid;
      hw_mode = "g";
      channel = 3;
      chanlist = [ 3 ];
      supported_rates = [ 60 90 120 180 240 360 480 540 ];
      basic_rates = [ 60 120 240 ];
      ht_capab = "[LDPC][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][MAX-AMSDU-7935]";
    } // hapdConfig;
  };
  # 5g ap
  router.interfaces.wlan1 = {
    bridge = "br0";
    hostapd.enable = true;
    hostapd.settings = {
      ssid = "${cfg.ssid}_5G";
      ieee80211h = true;
      hw_mode = "a";
      channel = 60;
      chanlist = [ 60 ];
      tx_queue_data2_burst = 2;
      ht_capab = "[HT40+][LDPC][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][MAX-AMSDU-7935]";
      vht_oper_chwidth = 1; # 80mhz ch width
      vht_oper_centr_freq_seg0_idx = 42;
      vht_capab = "[RXLDPC][SHORT-GI-80][SHORT-GI-160][TX-STBC-2BY1][SU-BEAMFORMER][SU-BEAMFORMEE][MU-BEAMFORMER][MU-BEAMFORMEE][RX-ANTENNA-PATTERN][TX-ANTENNA-PATTERN][RX-STBC-1][SOUNDING-DIMENSION-4][BF-ANTENNA-4][VHT160][MAX-MPDU-11454][MAX-A-MPDU-LEN-EXP7]";
    } // hapdConfig;
  };
  # ethernet lan0-3
  router.interfaces.lan0 = {
    bridge = "br0";
    systemdLink.linkConfig.MACAddressPolicy = "persistent";
  };
  router.interfaces.lan1 = {
    bridge = "br0";
    systemdLink.linkConfig.MACAddressPolicy = "persistent";
  };
  router.interfaces.lan2 = {
    bridge = "br0";
    systemdLink.linkConfig.MACAddressPolicy = "persistent";
  };
  router.interfaces.lan3 = {
    bridge = "br0";
    systemdLink.linkConfig.MACAddressPolicy = "persistent";
  };
  # sfp lan4
  router.interfaces.lan4 = {
    bridge = "br0";
    systemdLink.linkConfig.MACAddressPolicy = "persistent";
  };
  /*
  # sfp lan5
  router.interfaces.lan5 = {
    bridge = "br0";
    # i could try to figure out why this doesn't work... but i don't even have sfp to plug into this
    systemdLink.matchConfig.OriginalName = "eth1";
    systemdLink.linkConfig.MACAddressPolicy = "persistent";
  };
  */
  # ethernet wan
  router.interfaces.wan = {
    dependentServices = [
      { service = "wireguard-wg0"; inNetns = false; }
    ];
    systemdLink.linkConfig.MACAddressPolicy = "none";
    systemdLink.linkConfig.MACAddress = cfg.routerMac;
    dhcpcd = {
      enable = true;
      # technically this should be assigned to br0 instead of veth-wan-b
      # however, br0 is in a different namespace!
      # Considering this doesn't work at all because my ISP doesn't offer IPv6,
      # I'd say this is "good enough" since it might still work in the wan
      # namespace, though I can't test it.
      extraConfig = ''
        interface wan
          ipv6rs
          ia_na 0
          ia_pd 1 veth-wan-b/0
      '';
    };
    networkNamespace = "wan";
  };
  # disable default firewall as it uses iptables
  # (and we have our own firewall)
  networking.firewall.enable = false;
  # br0, which bridges all lan devices
  # this is "the" lan device
  router.interfaces.br0 = {
    dependentServices = [ { service = "unbound"; bindType = "wants"; } ];
    ipv4.addresses = lib.toList (netParsedCidrs.lan4 // {
      dns = [ netAddresses.lan4 ];
      keaSettings.reservations = map (res: {
        hw-address = res.macAddress;
        ip-address = res.ipAddress;
      }) cfg.dhcpReservations;
    });
    ipv6.addresses = lib.toList (netParsedCidrs.lan6 // {
      dns = [ netAddresses.lan6 ];
      gateways = [ netAddresses.lan6 ];
      radvdSettings.AdvAutonomous = true;
      coreradSettings.autonomous = true;
      # don't allocate addresses for most devices
      keaSettings.pools = [ ];
      # just assign the reservations
      keaSettings.reservations = map (res:
      (if res.duid != null then { duid = res.duid; } else { hw-address = res.macAddress; }) // {
        ip-addresses = [ res.ipAddress ];
      }) cfg.dhcp6Reservations;
    });
    ipv4.routes = [
      { extraArgs = [ netCidrs.lan4 "dev" "br0" "proto" "kernel" "scope" "link" "src" netAddresses.lan4 "table" wan_table ]; }
    ];
    ipv6.routes = [
      { extraArgs = [ netCidrs.lan6 "dev" "br0" "proto" "kernel" "metric" "256" "pref" "medium" "table" wan_table ]; }
    ];
    ipv4.kea.enable = true;
    ipv6.corerad.enable = true;
    ipv6.kea.enable = true;
  };

  router.networkNamespaces.default = {
    # set routing table depending on packet mark
    rules = [
      { ipv6 = false; extraArgs = [ "fwmark" wan_table "table" wan_table ]; }
      { ipv6 = true; extraArgs = [ "fwmark" wan_table "table" wan_table ]; }
      # below is dnat config
    ] ++ builtins.concatLists (map (rule: let
      table = if rule.inVpn then 0 else wan_table;
      forEachPort = func: port:
        if builtins.isInt port then [ (func port) ]
        else if port?set then builtins.concatLists (map (forEachPort func) port.set)
        else if port?range.min then let inherit (port.range) min max; in [ (func "${toString min}-${toString max}") ]
        else if port?range then let max = builtins.elemAt port.range 1; min = builtins.head port.range; in [ (func "${toString min}-${toString max}" ) ]
        else throw "Unsupported expr: ${builtins.toJSON port}";
      gen = len: proto: tgt:
        forEachPort
          (port: [ "from" "${tgt.address}/${toString len}" "ipproto" proto "sport" port "table" table ])
          (if tgt.port == null then rule.port else tgt.port);
    in   lib.optionals (rule.tcp && rule.target4 != null) (map (x: { ipv6 = false; extraArgs = x; }) (gen 32  "tcp" rule.target4))
      ++ lib.optionals (rule.udp && rule.target4 != null) (map (x: { ipv6 = false; extraArgs = x; }) (gen 32  "udp" rule.target4))
      ++ lib.optionals (rule.tcp && rule.target6 != null) (map (x: { ipv6 = true;  extraArgs = x; }) (gen 128 "tcp" rule.target6))
      ++ lib.optionals (rule.udp && rule.target6 != null) (map (x: { ipv6 = true;  extraArgs = x; }) (gen 128 "udp" rule.target6))
    ) (builtins.filter (x: (x.tcp || x.udp) && dnatRuleMode x == "rule") cfg.dnatRules));

    # nftables rules
    # things to note: this has the code for switching between rtables
    # otherwise, boring stuff
    nftables.jsonRules = mkRules {
      selfIp4 = netAddresses.lan4;
      selfIp6 = netAddresses.lan6;
      lans = [ "br0" ];
      wans = [ "wg0" "veth-wan-a" ];
      logPrefix = "lan ";
      netdevIngressWanRules = with notnft.dsl; with payload; [
        # check oif only from vpn
        # dont check it from veth-wan-a because of dnat fuckery and because we already check packets coming from wan there
        [(is.eq meta.iifname "wg0") (is.eq (fib (f: with f; [ saddr mark iif ]) (f: f.oif)) missing) (log "lan oif missing ") drop]
      ];
      inetDnatRules = 
        builtins.concatLists (map
          (rule: let
            protocols = dnatRuleProtos rule;
            rule4 = rule.target4; rule6 = rule.target6;
          in with notnft.dsl; with payload;
            lib.optional (rule4 != null)
              [ (is.eq meta.iifname "wg0") (is.eq ip.protocol protocols) (is.eq th.dport rule.port)
                (if rule4.port == null then dnat.ip rule4.address else dnat.ip rule4.address rule4.port) ]
            ++ lib.optional (rule6 != null)
              [ (is.eq meta.iifname "wg0") (is.eq ip6.nexthdr protocols) (is.eq th.dport rule.port)
                (if rule6.port == null then dnat.ip6 rule6.address else dnat.ip6 rule6.address rule6.port) ]
            )
          (builtins.filter (x: x.inVpn && (x.tcp || x.udp)) cfg.dnatRules))
        ++ (with notnft.dsl; with payload; [
          # hijack Microsoft DNS server hosted on Cloudflare
          [(is.eq meta.iifname "br0") (is.eq ip.daddr "162.159.36.2") (is.eq ip.protocol (f: set [ f.tcp f.udp ])) (dnat.ip netAddresses.lan4)]
        ] ++ lib.optionals (cfg.naughtyMacs != []) [
          [(is.eq meta.iifname "br0") (is.eq ether.saddr (setIfNeeded cfg.naughtyMacs)) (is.eq ip.protocol (f: set [ f.tcp f.udp ]))
           (is.eq th.dport (set [ 53 853 ])) (dnat.ip netAddresses.lan4)]
          [(is.eq meta.iifname "br0") (is.eq ether.saddr (setIfNeeded cfg.naughtyMacs)) (is.eq ip6.nexthdr (f: set [ f.tcp f.udp ]))
           (is.eq th.dport (set [ 53 853 ])) (dnat.ip6 netAddresses.lan6)]
        ]);
      inetForwardRules = with notnft.dsl; with payload; [
        # allow access to lan from the wan namespace
        [(is.eq meta.iifname "veth-wan-a") (is.eq meta.oifname "br0") accept]
        # allow dnat ("ct status dnat" doesn't work)
      ];
      inetInboundWanRules = with notnft.dsl; with payload; [
        [(is.eq ip.saddr (cidr netCidrs.netns4)) accept]
        [(is.eq ip6.saddr (cidr netCidrs.netns6)) accept]
      ];
      extraInetEntries = with notnft.dsl; with payload; {
        block4 = add set { type = f: f.ipv4_addr; flags = f: with f; [ interval ]; } [
          (cidr "194.190.137.0" 24)
          (cidr "194.190.157.0" 24)
          (cidr "194.190.21.0" 24)
          (cidr "194.226.130.0" 23)
          # no idea what this IP is, but it got a port 53 connection from one of the devices in this network - so off it goes
          "84.1.213.156"
        ];

        block6 = add set { type = f: f.ipv6_addr; flags = f: with f; [ interval ]; };

        # those tables get populated by unbound
        force_unvpn4 = add set { type = f: f.ipv4_addr; flags = f: with f; [ interval ]; };
        force_unvpn6 = add set { type = f: f.ipv6_addr; flags = f: with f; [ interval ]; };
        force_vpn4 = add set { type = f: f.ipv4_addr; flags = f: with f; [ interval ]; };
        force_vpn6 = add set { type = f: f.ipv6_addr; flags = f: with f; [ interval ]; };
        allow_iot4 = add set { type = f: f.ipv4_addr; flags = f: with f; [ interval ]; };
        allow_iot6 = add set { type = f: f.ipv6_addr; flags = f: with f; [ interval ]; };

        # TODO: is type=route hook=output better? It might help get rid of the routing inconsistency
        # between router-originated and forwarded traffic. The problem is type=route isn't supported
        # for family=inet, so I don't care enough to test it right now.
        prerouting = add chain { type = f: f.filter; hook = f: f.prerouting; prio = f: f.filter; policy = f: f.accept; } ([
          [(mangle meta.mark ct.mark)]
          [(is.ne meta.mark 0) accept]
          # ban requests to/from block4/block6
          # (might as well do this in ingress but i'm lazy)
          [(is.eq ip.daddr "@block4") (log "block4 ") drop]
          [(is.eq ip6.daddr "@block6") (log "block6 ") drop]
          [(is.eq ip.saddr "@block4") (log "block4/s ") drop]
          [(is.eq ip6.saddr "@block6") (log "block6/s ") drop]
          # default to vpn...
          [(mangle meta.mark vpn_table)]
          # ...but unvpn traffic to/from force_unvpn4/force_unvpn6
          [(is.eq ip.daddr "@force_unvpn4") (mangle meta.mark wan_table)]
          [(is.eq ip6.daddr "@force_unvpn6") (mangle meta.mark wan_table)]
          [(is.eq ip.saddr "@force_unvpn4") (mangle meta.mark wan_table)]
          [(is.eq ip6.saddr "@force_unvpn6") (mangle meta.mark wan_table)]
          # ...force vpn to/from force_vpn4/force_vpn6
          # (temporarily disable this because it breaks codeforces.org)
          # [(is.eq ip.daddr "@force_vpn4") (mangle meta.mark vpn_table)]
          # [(is.eq ip6.daddr "@force_vpn6") (mangle meta.mark vpn_table)]
          # [(is.eq ip.saddr "@force_vpn4") (mangle meta.mark vpn_table)]
          # [(is.eq ip6.saddr "@force_vpn6") (mangle meta.mark vpn_table)]
          # block requests to port 25 from hosts other than the server so they can't send mail pretending to originate from my domain
          # only do this for br0 since traffic from other interfaces isn't forwarded to wan
          [(is.eq meta.iifname "br0") (is.ne ether.saddr cfg.serverMac) (is.eq meta.l4proto (f: f.tcp)) (is.eq tcp.dport 25) (log "smtp ") drop]
          # don't vpn smtp requests so spf works fine (and in case the vpn blocks requests over port 25, which it usually does)
          [(is.eq meta.l4proto (f: f.tcp)) (is.eq tcp.dport 25) (mangle meta.mark wan_table)]
        ] ++ # 1. dnat non-vpn: change rttable to wan
        builtins.concatLists (map
          (rule: let
            protocols = dnatRuleProtos rule;
            rule4 = rule.target4; rule6 = rule.target6;
          in with notnft.dsl; with payload;
            lib.optionals (rule4 != null) [
              [ (is.eq meta.iifname "br0") (is.eq ip.protocol protocols) (is.eq ip.saddr rule4.address)
                (is.eq th.sport (if rule4.port != null then rule4.port else rule.port)) (mangle meta.mark wan_table) ]
              [ (is.eq meta.iifname "veth-wan-a") (is.eq ip.protocol protocols) (is.eq ip.daddr rule4.address)
                (is.eq th.dport (if rule4.port != null then rule4.port else rule.port)) (mangle meta.mark wan_table) ]
            ] ++ lib.optionals (rule6 != null) [
              [ (is.eq meta.iifname "br0") (is.eq ip6.nexthdr protocols) (is.eq ip6.saddr rule6.address)
                (is.eq th.sport (if rule6.port != null then rule6.port else rule.port)) (mangle meta.mark wan_table) ]
              [ (is.eq meta.iifname "veth-wan-a") (is.eq ip6.nexthdr protocols) (is.eq ip6.daddr rule6.address)
                (is.eq th.dport (if rule6.port != null then rule6.port else rule.port)) (mangle meta.mark wan_table) ]
            ])
          (builtins.filter (x: !x.inVpn && (x.tcp || x.udp) && dnatRuleMode x == "mark") cfg.dnatRules))
        ++ # 2. dnat vpn: change rttable to vpn
        builtins.concatLists (map
          (rule: let
            protocols = dnatRuleProtos rule;
            rule4 = rule.target4; rule6 = rule.target6;
          in with notnft.dsl; with payload;
            lib.optionals (rule4 != null) [
              [ (is.eq meta.iifname "br0") (is.eq ip.protocol protocols) (is.eq ip.saddr rule4.address)
                (is.eq th.sport (if rule4.port != null then rule4.port else rule.port)) (mangle meta.mark vpn_table) ]
              [ (is.eq meta.iifname "wg0") (is.eq ip.protocol protocols) (is.eq ip.daddr rule4.address)
                (is.eq th.dport (if rule4.port != null then rule4.port else rule.port)) (mangle meta.mark vpn_table) ]
            ] ++ lib.optionals (rule6 != null) [
              [ (is.eq meta.iifname "br0") (is.eq ip6.nexthdr protocols) (is.eq ip6.saddr rule6.address)
                (is.eq th.sport (if rule6.port != null then rule6.port else rule.port)) (mangle meta.mark vpn_table) ]
              [ (is.eq meta.iifname "wg0") (is.eq ip6.nexthdr protocols) (is.eq ip6.daddr rule6.address)
                (is.eq th.dport (if rule6.port != null then rule6.port else rule.port)) (mangle meta.mark vpn_table) ]
            ])
          (builtins.filter (x: x.inVpn && (x.tcp || x.udp) && dnatRuleMode x == "mark") cfg.dnatRules))
        ++ [
          # for the robot vacuum, only allow traffic to/from allow_iot4/allow_iot6
          [(is.eq ether.saddr cfg.vacuumMac) (is.ne ip.daddr (cidr netCidrs.lan4)) (is.ne ip.daddr "@allow_iot4") (log "iot4 ") drop]
          [(is.eq ether.saddr cfg.vacuumMac) (is.ne ip6.daddr (cidr netCidrs.lan6)) (is.ne ip6.daddr "@allow_iot6") (log "iot6 ") drop]
          [(is.eq ether.daddr cfg.vacuumMac) (is.ne ip.saddr (cidr netCidrs.lan4)) (is.ne ip.saddr "@allow_iot4") (log "iot4/d ") drop]
          [(is.eq ether.daddr cfg.vacuumMac) (is.ne ip6.saddr (cidr netCidrs.lan6)) (is.ne ip6.saddr "@allow_iot6") (log "iot6/d ") drop]
          # MSS clamping - since VPN reduces max MTU
          # We only do this for the first packet in a connection, which should be enough
          [(is.eq meta.nfproto (f: f.ipv4)) (is.eq meta.mark vpn_table) (is.gt tcpOpt.maxseg.size vpn_ipv4_mss)
           (mangle tcpOpt.maxseg.size vpn_ipv4_mss)]
          [(is.eq meta.nfproto (f: f.ipv6)) (is.eq meta.mark vpn_table) (is.gt tcpOpt.maxseg.size vpn_ipv6_mss)
           (mangle tcpOpt.maxseg.size vpn_ipv6_mss)]
          # warn about dns requests to foreign servers
          # TODO: check back and see if I should forcefully redirect DNS requests from certain IPs to router
          [(is.eq meta.iifname "br0") (is.ne ip.daddr (netAddresses.lan4)) (is.eq ip.protocol (f: set [ f.tcp f.udp ]))
           (is.eq th.dport (set [ 53 853 ])) (log "dns4 ")]
          [(is.eq meta.iifname "br0") (is.ne ip6.daddr (netAddresses.lan6)) (is.eq ip6.nexthdr (f: set [ f.tcp f.udp ]))
           (is.eq th.dport (set [ 53 853 ])) (log "dns6 ")]
          # finally, preserve the mark via conntrack
          [(mangle ct.mark meta.mark)]
        ]);
      };
    };
  };

  # veths are virtual ethernet cables
  # veth-wan-a - located in the default namespace
  # veth-wan-b - located in the wan namespace
  # this allows routing traffic to wan namespace from default namespace via veth-wan-a
  # (and vice versa)
  router.veths.veth-wan-a.peerName = "veth-wan-b";
  router.interfaces.veth-wan-a = {
    ipv4.addresses = [ netParsedCidrs.netns4 ];
    ipv6.addresses = [ netParsedCidrs.netns6 ];
    ipv4.routes = [
      # default config duplicated for wan_table
      { extraArgs = [ netCidrs.netns4 "dev" "veth-wan-a" "proto" "kernel" "scope" "link" "src" netAddresses.netns4 "table" wan_table ]; }
      # default all traffic to wan in wan_table
      { extraArgs = [ "default" "via" netAddresses.netnsWan4 "table" wan_table ]; }
    ];
    ipv6.routes = [
      # default config duplicated for wan_table
      { extraArgs = [ netCidrs.netns6 "dev" "veth-wan-a" "proto" "kernel" "metric" "256" "pref" "medium" "table" wan_table ]; }
      # default all traffic to wan in wan_table
      { extraArgs = [ "default" "via" netAddresses.netnsWan6 "table" wan_table ]; }
    ];
  };
  router.interfaces.veth-wan-b = {
    networkNamespace = "wan";
    ipv4.addresses = [ {
      address = netAddresses.netnsWan4;
      inherit (netParsedCidrs.netns4) prefixLength;
    } ];
    ipv6.addresses = [ {
      address = netAddresses.netnsWan6;
      inherit (netParsedCidrs.netns6) prefixLength;
    } ];
    # allow wan->default namespace communication
    ipv4.routes = [
      { extraArgs = [ netCidrs.lan4 "via" netAddresses.netns4 ]; }
    ];
    ipv6.routes = [
      { extraArgs = [ netCidrs.lan6 "via" netAddresses.netns6 ]; }
    ];
  };
  router.networkNamespaces.wan = {
    # this is the even more boring nftables config
    nftables.jsonRules = mkRules {
      selfIp4 = netAddresses.netnsWan4;
      selfIp6 = netAddresses.netnsWan6;
      lans = [ "veth-wan-b" ];
      wans = [ "wan" ];
      netdevIngressWanRules = with notnft.dsl; with payload; [
        [(is.eq (fib (f: with f; [ saddr mark iif ]) (f: f.oif)) missing) (log "wan oif missing ") drop]
      ];
      inetDnatRules = 
        builtins.concatLists (map
          (rule: let
            protocols = dnatRuleProtos rule;
            rule4 = rule.target4; rule6 = rule.target6;
          in with notnft.dsl; with payload;
            lib.optionals (rule4 != null) [
              [ (is.eq meta.iifname "wan") (is.eq ip.protocol protocols) (is.eq th.dport rule.port)
                (if rule4.port == null then dnat.ip rule4.address else dnat.ip rule4.address rule4.port) ]
            ] ++ lib.optionals (rule6 != null) [
              [ (is.eq meta.iifname "wan") (is.eq ip6.nexthdr protocols) (is.eq th.dport rule.port)
                (if rule6.port == null then dnat.ip6 rule6.address else dnat.ip6 rule6.address rule6.port) ]
            ])
          (builtins.filter (x: !x.inVpn && (x.tcp || x.udp)) cfg.dnatRules));
      inetSnatRules =
        # historically, i needed this, now i switched to ip rules
        # if i ever need this again, i have it right here
        builtins.concatLists (map
          (rule: let
            protocols = dnatRuleProtos rule;
            rule4 = rule.target4; rule6 = rule.target6;
          in with notnft.dsl; with payload;
            lib.optionals (rule4 != null) [
              [ (is.eq meta.iifname "wan") (is.eq meta.oifname "veth-wan-b") (is.eq ip.protocol protocols)
                (is.eq th.dport (if rule4.port != null then rule4.port else rule.port)) (is.eq ip.daddr rule4.address) masquerade ]
            ] ++ lib.optionals (rule6 != null) [
              [ (is.eq meta.iifname "wan") (is.eq meta.oifname "veth-wan-b") (is.eq ip6.nexthdr protocols)
                (is.eq th.dport (if rule6.port != null then rule6.port else rule.port)) (is.eq ip6.daddr rule6.address) masquerade ]
            ])
          (builtins.filter (x: !x.inVpn && (x.tcp || x.udp) && dnatRuleMode x == "snat") cfg.dnatRules));
      logPrefix = "wan ";
      inetInboundWanRules = with notnft.dsl; with payload; [
        # DHCP
        [(is.eq meta.nfproto (x: x.ipv4)) (is.eq udp.dport 68) accept]
        [(is.eq meta.nfproto (x: x.ipv6)) (is.eq udp.dport 546) accept]
        # igmp, used for setting up multicast groups
        [(is.eq ip.protocol (f: f.igmp)) accept]
        # accept router solicitation stuff
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.eq icmpv6.type (f: with f; set [ nd-router-solicit nd-router-advert ])) accept]
        # accept neighbor solicitation stuff
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (is.eq icmpv6.code (f: f.no-route))
          (is.eq icmpv6.type (f: with f; set [ nd-neighbor-solicit nd-neighbor-advert ]))
          accept]
        # SSH
        [(is.eq tcp.dport 23) accept]
      ];
    };
  };

  # vpn socket is in wan namespace, meaning traffic gets sent through the wan namespace
  # vpn interface is in default namespace, meaning it can be used in the default namespace
  networking.wireguard.interfaces.wg0 = cfg.wireguard // {
    socketNamespace = "wan";
    interfaceNamespace = "init";
  };

  # use main netns's address instead of 127.0.0.1
  # this ensures all network namespaces can access it
  networking.resolvconf.extraConfig = ''
    name_servers="${netAddresses.netns4} ${netAddresses.netns6}"
  '';
  users.users.${config.common.mainUsername}.extraGroups = [ config.services.unbound.group ];
  services.unbound = {
    enable = true;
    package = pkgs.unbound-full;
    localControlSocketPath = "/run/unbound/unbound.ctl";
    # we override resolvconf above manually
    resolveLocalQueries = false;
    settings = {
      server = rec {
        interface = [ netAddresses.netns4 netAddresses.netns6 netAddresses.lan4 netAddresses.lan6 ];
        access-control = [ "${netCidrs.netns4} allow" "${netCidrs.netns6} allow" "${netCidrs.lan4} allow" "${netCidrs.lan6} allow" ];
        aggressive-nsec = true;
        do-ip6 = true;
        module-config = ''"validator python iterator"'';
        local-zone = [
          # incompatible with avahi resolver
          # ''"local." static''
          ''"${server-config.server.domainName}." typetransparent''
        ];
        local-data = builtins.concatLists (map (domain:
          [
            ''"${domain}. A ${serverAddress4}"''
            ''"${domain}. AAAA ${serverAddress6}"''
          ]) hosted-domains);
          # incompatible with avahi resolver
          # ++ [
          #   ''"retracker.local. A ${netAddresses.lan4}"''
          #   ''"retracker.local. AAAA ${netAddresses.lan6}"''
          # ];

        # performance tuning
        num-threads = 4; # cpu core count
        msg-cache-slabs = 4; # nearest power of 2 to num-threads
        rrset-cache-slabs = msg-cache-slabs;
        infra-cache-slabs = msg-cache-slabs;
        key-cache-slabs = msg-cache-slabs;
        so-reuseport = true;
        msg-cache-size = "50m"; # (default 4m)
        rrset-cache-size = "100m"; # msg*2 (default 4m)
        # timeouts
        unknown-server-time-limit = 752; # default=376
      };
      # normally it would refer to the flake path, but then the service changes on every flake update
      # instead, write a new file in nix store
      python.python-script = builtins.toFile "avahi-resolver-v2.py" (builtins.readFile ./avahi-resolver-v2.py);
      remote-control.control-enable = true;
    };
  };
  environment.etc."unbound/iot_ips.json".text = builtins.toJSON [
    # local multicast
    "224.0.0.0/24"
    # local broadcast
    "255.255.255.255"
  ];
  environment.etc."unbound/iot_domains.json".text = builtins.toJSON [
    # ntp time sync
    "pool.ntp.org"
    # valetudo update check
    "api.github.com" "github.com" "*.githubusercontent.com"
  ];
  networking.hosts."${serverAddress4}" = hosted-domains;
  networking.hosts."${serverAddress6}" = hosted-domains;
  systemd.services.unbound = lib.mkIf config.services.unbound.enable {
    environment.PYTHONPATH = let
      unbound-python = pkgs.python3.withPackages (ps: with ps; [ pydbus dnspython requests pytricia nftables ]);
    in
      "${unbound-python}/${unbound-python.sitePackages}";
    environment.MDNS_ACCEPT_NAMES = "^(.*\\.)?local\\.$";
    # resolve retracker.local to whatever router.local resolves to
    # we can't add a local zone alongside using avahi resolver, so we have to use hacks like this
    environment.DOMAIN_NAME_OVERRIDES = "retracker.local->router.local";
    # load vpn_domains.json and vpn_ips.json, as well as unvpn_domains.json and unvpn_ips.json
    # resolve domains and append it to ips and add it to the nftables sets
    # TODO: allow changing family/table name
    environment.NFT_QUERIES = "vpn:force_vpn4,force_vpn6;unvpn!:force_unvpn4,force_unvpn6;iot:allow_iot4,allow_iot6";
    serviceConfig.EnvironmentFile = "/secrets/unbound_env";
    # it needs to run after nftables has been set up because it sets up the sets
    after = [ "nftables-default.service" "avahi-daemon.service" ];
    wants = [ "nftables-default.service" "avahi-daemon.service" ];
    # allow it to call nft
    serviceConfig.AmbientCapabilities = [ "CAP_NET_ADMIN" ];
  };
  systemd.services.update-rkn-blacklist = {
    # fetch vpn_ips.json and vpn_domains.json for unbound
    script = ''
      BLACKLIST=$(${pkgs.coreutils}/bin/mktemp) || exit 1
      ${pkgs.curl}/bin/curl "https://reestr.rublacklist.net/api/v2/ips/json/" -o "$BLACKLIST" || exit 1
      ${pkgs.jq}/bin/jq ".[0:0]" "$BLACKLIST" && chown unbound:unbound "$BLACKLIST" && mv "$BLACKLIST" /var/lib/unbound/vpn_ips.json
      ${pkgs.curl}/bin/curl "https://reestr.rublacklist.net/api/v2/domains/json/" -o "$BLACKLIST" || exit 1
      ${pkgs.jq}/bin/jq ".[0:0]" "$BLACKLIST" && chown unbound:unbound "$BLACKLIST" && mv "$BLACKLIST" /var/lib/unbound/vpn_domains.json
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };
  systemd.timers.update-rkn-blacklist = {
    wantedBy = [ "timers.target" ];
    partOf = [ "update-rkn-blacklist.service" ];
    # slightly unusual time to reduce server load
    timerConfig.OnCalendar = [ "*-*-* 00:00:00" ]; # every day
    timerConfig.RandomizedDelaySec = 43200; # execute at random time in the first 12 hours
  };

  # run an extra sshd so we can connect even if forwarding/routing between namespaces breaks
  # (use port 23 because 22 is forwarded to the server)
  systemd.services.sshd-wan = {
    description = "SSH Daemon (WAN)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "netns-wan.service" ]; 
    bindsTo = [ "netns-wan.service" ]; 
    stopIfChanged = false;
    path = with pkgs; [ gawk config.programs.ssh.package ];
    environment.LD_LIBRARY_PATH = config.system.nssModules.path;
    restartTriggers = [ config.environment.etc."ssh/sshd_config".source ];
    preStart = config.systemd.services.sshd.preStart;
    serviceConfig = {
      ExecStart = "${config.programs.ssh.package}/bin/sshd -D -f /etc/ssh/sshd_config -p 23";
      KillMode = "process";
      Restart = "always";
      Type = "simple";
      NetworkNamespacePath = "/var/run/netns/wan";
    };
  };

  services.printing = {
    enable = true;
    allowFrom = [ "localhost" netCidrs.lan4 netCidrs.lan6 ];
    browsing = true;
    clientConf = ''
      ServerName router.local
    '';
    defaultShared = true;
    drivers = [ pkgs.hplip ];
    startWhenNeeded = false;
  };

  # share printers (and allow unbound to resolve .local)
  services.avahi = {
    enable = true;
    hostName = "router";
    allowInterfaces = [ "br0" ];
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      userServices = true;
    };
  };

  services.iperf3 = {
    enable = true;
    bind = netAddresses.lan4;
  };

  services.opentracker = {
    enable = true;
    extraOptions = "-i ${netAddresses.lan4} -p 6969 -P 6969 -p 80";
  };

  impermanence.directories = [
    # for wireguard key
    { directory = /secrets; mode = "0000"; }
    # my custom impermanence module doesnt detect it
    { directory = /var/db/dhcpcd; mode = "0755"; }
    { directory = /var/lib/private/kea; mode = "0750"; }
  ];
}
