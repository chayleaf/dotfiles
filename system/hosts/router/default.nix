{ config
, pkgs
, notnft
, lib
, router-lib
, ... }:

let
  rootUuid = "44444444-4444-4444-8888-888888888888";
  rootPart = "/dev/disk/by-uuid/${rootUuid}";
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
  # iot table without a route into the internet
  iot_table = 3;

  dnatRuleMode = rule:
    if rule.mode != "" then rule.mode
    else if rule.target4.address or null == gatewayAddr4 || rule.target6.address or null == gatewayAddr6 then "rule"
    else "mark";

  # nftables rules generator
  # selfIp4/selfIp6 = block packets from these addresses
  # extraInetEntries = stuff to add to inet table
  # extraNetdevEntries = stuff to add to netdev table
  # wans = external interfaces (internet)
  # lans = internal interfaces (lan)
  # netdevIngressWanRules = additional rules for ingress (netdev)
  # inetInboundWanRules = additional rules for input from wan (inet), i.e. stuff meant directly for the router and not for any other device
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
    inetForwardRules ? [],
    inetSnatRules ? [],
    inetDnatRules ? [],
    logPrefix ? "",
  }: with notnft.dsl; with payload; ruleset {
    filter = add table.netdev ({
      ingress_common = add chain
        [(is.eq (bit.and tcp.flags (f: bit.or f.fin f.syn)) (f: bit.or f.fin f.syn)) (log "${logPrefix}fin+syn drop ") drop]
        [(is.eq (bit.and tcp.flags (f: bit.or f.syn f.rst)) (f: bit.or f.syn f.rst)) (log "${logPrefix}syn+rst drop ") drop]
        [(is.eq (bit.and tcp.flags (f: with f; bit.or fin syn rst psh ack urg)) 0) (log "${logPrefix}null drop ") drop]
        [(is tcp.flags (f: f.syn)) (is.eq tcpOpt.maxseg.size (range 0 500)) (log "${logPrefix}maxseg drop ") drop]
        # reject requests with own saddr
        # log if they are meant for us...
        [(is.eq ip.saddr selfIp4) (is.eq (fib (f: with f; [ daddr iif ]) (f: f.type)) (f: f.local)) (log "${logPrefix}self4 ") drop]
        [(is.eq ip6.saddr selfIp6) (is.eq (fib (f: with f; [ daddr iif ]) (f: f.type)) (f: f.local)) (log "${logPrefix}self6 ") drop]
        # ...but drop silently if they're multicast/broadcast
        [(is.eq ip.saddr selfIp4) drop]
        [(is.eq ip6.saddr selfIp6) drop]
        [return];

      ingress_lan_common = add chain
        [(is.eq (fib (f: with f; [ saddr mark iif ]) (f: f.oif)) missing) (log "${logPrefix}oif missing ") drop]
        [(jump "ingress_common")];

      ingress_wan_common = add chain
        netdevIngressWanRules
        [(jump "ingress_common")]
        # [(is.ne (fib (f: with f; [ daddr iif ]) (f: f.type)) (f: set [ f.local f.broadcast f.multicast ])) (log "${logPrefix}non-{local,broadcast,multicast} ") drop]
        [(is.eq ip.protocol (f: f.icmp)) (limit { rate = 100; per = f: f.second; }) accept]
        [(is.eq ip6.nexthdr (f: f.ipv6-icmp)) (limit { rate = 100; per = f: f.second; }) accept]
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
        [(is.eq (bit.and tcp.flags (f: f.syn)) 0) (is.eq ct.state (f: f.new)) (log "${logPrefix}new non-syn ") drop]
        # icmp: only accept ping requests
        [(is.eq ip.protocol (f: f.icmp)) (is.eq icmp.type (f: with f; set [ echo-request ])) accept]
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
          (is.eq icmpv6.type (f: with f; set [ parameter-problem ])) accept]
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
        ))]
        [(log "${logPrefix}inbound drop ")];

      forward = add chain { type = f: f.filter; hook = f: f.forward; prio = f: f.filter; policy = f: f.drop; }
        [(vmap ct.state { established = accept; related = accept; invalid = drop; })]
        [(is ct.status (f: f.dnat)) accept]
        # accept lan->wan fw
        [(is.eq meta.iifname (set lans)) (is.eq meta.oifname (set wans)) accept]
        # accept lan->lan fw
        [(is.eq meta.iifname (set lans)) (is.eq meta.oifname (set lans)) accept]
        # accept wan->lan icmpv6 forward
        [(is.eq meta.iifname (set wans)) (is.eq icmpv6.type (f: with f; set [ destination-unreachable time-exceeded echo-request echo-reply ])) accept]
        [(is.eq meta.iifname (set wans)) (is.eq icmpv6.code (f: f.no-route)) (is.eq icmpv6.type (f: with f; set [ packet-too-big parameter-problem ])) accept]
        [(is.eq meta.iifname (set wans)) (is.eq icmpv6.code (f: f.admin-prohibited)) (is.eq icmpv6.type (f: f.parameter-problem)) accept]
        inetForwardRules
        [(log "${logPrefix}forward drop ")];

      postrouting = add chain { type = f: f.nat; hook = f: f.postrouting; prio = f: f.srcnat; policy = f: f.accept; }
        # masquerade ipv6 because my isp doesn't provide it and my vpn gives a single ipv6
        [(is.eq meta.protocol (f: set [ f.ip f.ip6 ])) (is.eq meta.iifname (set lans)) (is.eq meta.oifname (set wans)) masquerade]
        inetSnatRules;

      prerouting = add chain { type = f: f.nat; hook = f: f.prerouting; prio = f: f.dstnat; policy = f: f.accept; }
        inetDnatRules;
    } // extraInetEntries);
  };

  mkFlushRules = {}: with notnft.dsl; ruleset [ (flush ruleset) ];
  unbound-python = pkgs.python3.withPackages (ps: with ps; [ pydbus dnspython requests pytricia nftables ]);

  # parse a.b.c.d/x into { address, prefixLength }
  netParsedCidr4 = router-lib.parseCidr cfg.network;
  netParsedCidr6 = router-lib.parseCidr cfg.network6;
  netnsParsedCidr4 = router-lib.parseCidr cfg.netnsNet;
  netnsParsedCidr6 = router-lib.parseCidr cfg.netnsNet6;

  # generate network cidr from device address
  # (normalizeCidr applies network mask to the address)
  netCidr4 = router-lib.serializeCidr (router-lib.normalizeCidr netParsedCidr4);
  netCidr6 = router-lib.serializeCidr (router-lib.normalizeCidr netParsedCidr6);
  netnsCidr4 = router-lib.serializeCidr (router-lib.normalizeCidr netnsParsedCidr4);
  netnsCidr6 = router-lib.serializeCidr (router-lib.normalizeCidr netnsParsedCidr6);

  gatewayAddr4 = netParsedCidr4.address;
  gatewayAddr6 = netParsedCidr6.address;
  mainNetnsAddr4 = netnsParsedCidr4.address;
  mainNetnsAddr6 = netnsParsedCidr6.address;

  wanNetnsAddr4 = cfg.wanNetnsAddr;
  wanNetnsAddr6 = cfg.wanNetnsAddr6;

  parsedGatewayAddr4 = router-lib.parseIp4 gatewayAddr4;
  parsedGatewayAddr6 = router-lib.parseIp6 gatewayAddr6;

  addToIp' = ip: n: lib.init ip ++ [ (lib.last ip + n) ];
  addToIp = ip: n: router-lib.serializeIp (addToIp' ip n);

  # server
  serverAddress4 = addToIp parsedGatewayAddr4 1;
  serverAddress6 = addToIp parsedGatewayAddr6 1;
  # robot vacuum
  vacuumAddress4 = addToIp parsedGatewayAddr4 2;
  vacuumAddress6 = addToIp parsedGatewayAddr6 2;

  # TODO: take from server config?
  hosted-domains =
    map
      (prefix: if prefix == null then cfg.domainName else "${prefix}.${cfg.domainName}")
  [
    null "dns" "mumble" "mail" "music" "www" "matrix"
    "search" "git" "cloud" "ns1" "ns2"
  ];
in {
  router-settings.domainName = "pavluk.org";
  router-settings.dhcpReservations = [
    { ipAddress = serverAddress4;
      macAddress = cfg.serverMac; }
    { ipAddress = vacuumAddress4;
      macAddress = cfg.vacuumMac; }
  ];
  router-settings.dhcp6Reservations = [
    { ipAddress = serverAddress6;
      macAddress = cfg.serverMac; }
    { ipAddress = vacuumAddress6;
      macAddress = cfg.vacuumMac; }
  ];
  router-settings.dnatRules = [
    {
      # TODO: take firewall settings from server config
      port = notnft.dsl.set [
        # http
        80 443 8008 8448
        # mail
        25 587 465 143 993 110 995 4190
      ];
      tcp = true; udp = false;
      target4.address = serverAddress4;
      target6.address = serverAddress6;
    }
    {
      # mumble
      port = 64738; tcp = true; udp = true;
      target4.address = serverAddress4;
      target6.address = serverAddress6;
    }
    {
      # expose the default namespace's ssh via port 23
      port = 23; tcp = true; udp = false;
      target4.address = gatewayAddr4;
      target4.port = 22;
      target6.address = gatewayAddr6;
      target6.port = 22;
    }
  ];

  imports = [ ./options.nix ];
  system.stateVersion = "22.11";
  fileSystems = {
    # mount root on tmpfs
    "/" =     { device = "none"; fsType = "tmpfs"; neededForBoot = true;
                options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
              { device = rootPart; fsType = "btrfs"; neededForBoot = true;
                options = [ "compress=zstd:15" "subvol=@" ]; };
    "/boot" =
              { device = rootPart; fsType = "btrfs"; neededForBoot = true;
                options = [ "subvol=@boot" ]; };
    "/nix" =
              { device = rootPart; fsType = "btrfs"; neededForBoot = true;
                options = [ "compress=zstd:15" "subvol=@nix" ]; };
  };
  impermanence = {
    enable = true;
    path = /persist;
    directories = [
      { directory = /home/${config.common.mainUsername}; user = config.common.mainUsername; group = "users"; mode = "0700"; }
      { directory = /root; mode = "0700"; }
      { directory = /var/db/dhcpcd; mode = "0755"; }
      { directory = /var/lib/private/kea; mode = "0750"; }
      # for wireguard key
      { directory = /secrets; mode = "0000"; }
    ];
  };
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.src_valid_mark" = true;
    "net.ipv4.conf.default.src_valid_mark" = true;
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };
  services.openssh.enable = true;
  /*services.fail2ban = {
    enable = true;
  };*/
  router.enable = true;
  router.interfaces.wlan0 = {
    bridge = "br0";
    hostapd.enable = true;
    hostapd.settings = {
      inherit (cfg) ssid;
      hw_mode = "g";
      channel = 1;
      chanlist = [ 1 ];
      supported_rates = [ 60 90 120 180 240 360 480 540 ];
      basic_rates = [ 60 120 240 ];
      ht_capab = "[LDPC][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][MAX-AMSDU-7935]";
    } // hapdConfig;
  };
  router.interfaces.wlan1 = {
    bridge = "br0";
    hostapd.enable = true;
    hostapd.settings = {
      ssid = "${cfg.ssid}_5G";
      ieee80211h = true;
      hw_mode = "a";
      channel = 36;
      chanlist = [ 36 ];
      tx_queue_data2_burst = 2;
      ht_capab = "[HT40+][LDPC][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1][MAX-AMSDU-7935]";
      vht_oper_chwidth = 1; # 80mhz ch width
      vht_oper_centr_freq_seg0_idx = 42;
      vht_capab = "[RXLDPC][SHORT-GI-80][SHORT-GI-160][TX-STBC-2BY1][SU-BEAMFORMER][SU-BEAMFORMEE][MU-BEAMFORMER][MU-BEAMFORMEE][RX-ANTENNA-PATTERN][TX-ANTENNA-PATTERN][RX-STBC-1][SOUNDING-DIMENSION-4][BF-ANTENNA-4][VHT160][MAX-MPDU-11454][MAX-A-MPDU-LEN-EXP7]";
    } // hapdConfig;
  };
  router.interfaces.lan0 = {
    bridge = "br0";
    systemdLinkLinkConfig.MACAddressPolicy = "persistent";
  };
  router.interfaces.lan1 = {
    bridge = "br0";
    systemdLinkLinkConfig.MACAddressPolicy = "persistent";
  };
  router.interfaces.lan2 = {
    bridge = "br0";
    systemdLinkLinkConfig.MACAddressPolicy = "persistent";
  };
  router.interfaces.lan3 = {
    bridge = "br0";
    systemdLinkLinkConfig.MACAddressPolicy = "persistent";
  };
  router.interfaces.lan4 = {
    bridge = "br0";
    systemdLinkLinkConfig.MACAddressPolicy = "persistent";
  };
  /*router.interfaces.lan5 = {
    bridge = "br0";
    systemdLinkMatchConfig.OriginalName = "eth1";
    systemdLinkLinkConfig.MACAddressPolicy = "persistent";
  };*/
  router.interfaces.wan = {
    dependentServices = [
      { service = "wireguard-wg0"; inNetns = false; }
    ];
    systemdLinkLinkConfig.MACAddressPolicy = "none";
    systemdLinkLinkConfig.MACAddress = "11:22:33:44:55:66";
    dhcpcd.enable = true;
    networkNamespace = "wan";
  };
  networking.firewall.enable = false;
  router.interfaces.br0 = {
    dependentServices = [ { service = "unbound"; bindType = "wants"; } ];
    ipv4.addresses = [ {
      address = gatewayAddr4;
      inherit (netParsedCidr4) prefixLength;
      dns = [ gatewayAddr4 ];
      keaSettings.reservations = map (res: {
        hw-address = res.macAddress;
        ip-address = res.ipAddress;
      }) cfg.dhcpReservations;
    } ];
    ipv6.addresses = [ {
      address = gatewayAddr6;
      inherit (netParsedCidr6) prefixLength;
      dns = [ gatewayAddr6 ];
      gateways = [ gatewayAddr6 ];
      radvdSettings.AdvAutonomous = true;
      coreradSettings.autonomous = true;
      # don't autoallocate addresses
      keaSettings.pools = [ ];
      # just assign the reservations
      keaSettings.reservations = map (res: {
        hw-address = res.macAddress;
        ip-addresses = [ res.ipAddress ];
      }) cfg.dhcp6Reservations;
    } ];
    ipv4.routes = [
      { extraArgs = [ netCidr4 "dev" "br0" "proto" "kernel" "scope" "link" "src" gatewayAddr4 "table" wan_table ]; }
      # allow iot to contact ips inside the network
      { extraArgs = [ netCidr4 "dev" "br0" "proto" "kernel" "scope" "link" "src" gatewayAddr4 "table" iot_table ]; }
    ];
    ipv6.routes = [
      { extraArgs = [ netCidr6 "dev" "br0" "proto" "kernel" "metric" "256" "pref" "medium" "table" wan_table ]; }
      # allow iot to contact ips inside the network
      { extraArgs = [ netCidr6 "dev" "br0" "proto" "kernel" "metric" "256" "pref" "medium" "table" iot_table ]; }
    ];
    ipv4.kea.enable = true;
    ipv6.radvd.enable = true;
    ipv6.kea.enable = true;
    nftables.stopJsonRules = mkFlushRules {};
    nftables.jsonRules = mkRules {
      selfIp4 = gatewayAddr4;
      selfIp6 = gatewayAddr6;
      lans = [ "br0" ];
      wans = [ "wg0" "veth-wan-a" ];
      netdevIngressWanRules = with notnft.dsl; with payload; [
        # check oif only from vpn
        # dont check it from veth-wan-a because of dnat fuckery and because we already check packets coming from wan there
        [(is.eq meta.iifname "wg0") (is.eq (fib (f: with f; [ saddr mark iif ]) (f: f.oif)) missing) (log "lan oif missing ") drop]
      ];
      inetDnatRules = 
        builtins.concatLists (map
          (rule: let
            inherit (notnft.inetProtos) tcp udp;
            protocols = if rule.tcp && rule.udp then notnft.dsl.set [ tcp udp ] else if rule.tcp then tcp else udp;
            rule4 = rule.target4; rule6 = rule.target6;
          in with notnft.dsl; with payload;
            lib.optionals (rule4 != null) [
              [ (is.eq meta.iifname "wg0") (is.eq ip.protocol protocols) (is.eq th.dport rule.port)
                (if rule4.port == null then dnat.ip rule4.address else dnat.ip rule4.address rule4.port) ]
            ] ++ lib.optionals (rule6 != null) [
              [ (is.eq meta.iifname "wg0") (is.eq ip6.protocol protocols) (is.eq th.dport rule.port)
                (if rule6.port == null then dnat.ip6 rule6.address else dnat.ip6 rule6.address rule6.port) ]
            ])
          (builtins.filter (x: x.inVpn && (x.tcp || x.udp)) cfg.dnatRules));
      inetForwardRules = with notnft.dsl; with payload; [
        # allow access to lan from the wan namespace
        [(is.eq meta.iifname "veth-wan-a") (is.eq meta.oifname "br0") accept]
        # allow dnat ("ct status dnat" doesn't work)
      ];
      logPrefix = "lan ";
      inetInboundWanRules = with notnft.dsl; with payload; [
        [(is.eq th.dport 22) accept]
        [(is.eq ip.saddr (cidr netnsCidr4)) accept]
        [(is.eq ip6.saddr (cidr netnsCidr6)) accept]
      ];
      extraInetEntries = with notnft.dsl; with payload; {
        block4 = add set { type = f: f.ipv4_addr; flags = f: with f; [ interval ]; } [
          (cidr "194.190.137.0" 24)
          (cidr "194.190.157.0" 24)
          (cidr "194.190.21.0" 24)
          (cidr "194.226.130.0" 23)
        ];

        block6 = add set { type = f: f.ipv6_addr; flags = f: with f; [ interval ]; };

        # those tables get populated by unbound
        force_unvpn4 = add set { type = f: f.ipv4_addr; flags = f: with f; [ interval ]; };
        force_vpn4 = add set { type = f: f.ipv4_addr; flags = f: with f; [ interval ]; };
        force_unvpn6 = add set { type = f: f.ipv6_addr; flags = f: with f; [ interval ]; };
        force_vpn6 = add set { type = f: f.ipv6_addr; flags = f: with f; [ interval ]; };

        prerouting = add chain { type = f: f.filter; hook = f: f.prerouting; prio = f: f.filter; policy = f: f.accept; } ([
          [(mangle meta.mark ct.mark)]
          [(is.ne meta.mark 0) accept]
          [(is.eq meta.iifname "br0") (mangle meta.mark vpn_table)]
          [(is.eq ip.daddr "@force_unvpn4") (mangle meta.mark wan_table)]
          [(is.eq ip6.daddr "@force_unvpn6") (mangle meta.mark wan_table)]
          [(is.eq ip.daddr "@force_vpn4") (mangle meta.mark vpn_table)]
          [(is.eq ip6.daddr "@force_vpn6") (mangle meta.mark vpn_table)]
        ] ++ # 1. dnat non-vpn: change rttable to wan
        builtins.concatLists (map
          (rule: let
            inherit (notnft.inetProtos) tcp udp;
            protocols = if rule.tcp && rule.udp then notnft.dsl.set [ tcp udp ] else if rule.tcp then tcp else udp;
            rule4 = rule.target4; rule6 = rule.target6;
          in with notnft.dsl; with payload;
            lib.optionals (rule4 != null && rule4.address != gatewayAddr4) [
              [ (is.eq meta.iifname "br0") (is.eq ip.protocol protocols) (is.eq ip.saddr rule4.address)
                (is.eq th.sport (if rule4.port != null then rule4.port else rule.port)) (mangle meta.mark wan_table) ]
            ] ++ lib.optionals (rule6 != null && rule6.address != gatewayAddr6) [
              [ (is.eq meta.iifname "br0") (is.eq ip6.nexthdr protocols) (is.eq ip6.saddr rule6.address)
                (is.eq th.sport (if rule6.port != null then rule6.port else rule.port)) (mangle meta.mark wan_table) ]
            ])
          (builtins.filter (x: !x.inVpn && (x.tcp || x.udp) && dnatRuleMode x == "mark") cfg.dnatRules))
        ++ # 2. dnat vpn: change rttable to vpn
        builtins.concatLists (map
          (rule: let
            inherit (notnft.inetProtos) tcp udp;
            protocols = if rule.tcp && rule.udp then notnft.dsl.set [ tcp udp ] else if rule.tcp then tcp else udp;
            rule4 = rule.target4; rule6 = rule.target6;
          in with notnft.dsl; with payload;
            lib.optionals (rule4 != null && rule4.address != gatewayAddr4) [
              [ (is ct.status (f: f.dnat)) (is.eq meta.iifname "br0") (is.eq ip.protocol protocols) (is.eq ip.saddr rule4.address)
                (is.eq th.sport (if rule4.port != null then rule4.port else rule.port)) (mangle meta.mark vpn_table) ]
            ] ++ lib.optionals (rule6 != null && rule6.address != gatewayAddr6) [
              [ (is ct.status (f: f.dnat)) (is.eq meta.iifname "br0") (is.eq ip6.protocol protocols) (is.eq ip6.saddr rule6.address)
                (is.eq th.sport (if rule6.port != null then rule6.port else rule.port)) (mangle meta.mark vpn_table) ]
            ])
          (builtins.filter (x: x.inVpn && (x.tcp || x.udp) && dnatRuleMode x == "mark") cfg.dnatRules))
        ++ [
          [(is.eq ip.daddr "@block4") drop]
          [(is.eq ip6.daddr "@block6") drop]
          [(is.eq ether.saddr cfg.vacuumMac) (mangle meta.mark iot_table)]
          [(mangle ct.mark meta.mark)]
        ]);
      };
    };
  };
  router.veths.veth-wan-a.peerName = "veth-wan-b";
  router.interfaces.veth-wan-a = {
    ipv4.addresses = [ netnsParsedCidr4 ];
    ipv6.addresses = [ netnsParsedCidr6 ];
    ipv4.routes = [
      # default config duplicated for wan_table
      { extraArgs = [ netnsCidr4 "dev" "veth-wan-a" "proto" "kernel" "scope" "link" "src" mainNetnsAddr4 "table" wan_table ]; }
      # default all traffic to wan in wan_table
      { extraArgs = [ "default" "via" wanNetnsAddr4 "table" wan_table ]; }
    ];
    ipv6.routes = [
      # default config duplicated for wan_table
      { extraArgs = [ netnsCidr6 "dev" "veth-wan-a" "proto" "kernel" "metric" "256" "pref" "medium" "table" wan_table ]; }
      # default all traffic to wan in wan_table
      { extraArgs = [ "default" "via" wanNetnsAddr6 "table" wan_table ]; }
    ];
  };
  router.interfaces.veth-wan-b = {
    networkNamespace = "wan";
    ipv4.addresses = [ {
      address = wanNetnsAddr4;
      inherit (netnsParsedCidr4) prefixLength;
    } ];
    ipv6.addresses = [ {
      address = wanNetnsAddr6;
      inherit (netnsParsedCidr6) prefixLength;
    } ];
    ipv4.routes = [
      { extraArgs = [ netCidr4 "via" mainNetnsAddr4 ]; }
    ];
    ipv6.routes = [
      { extraArgs = [ netCidr6 "via" mainNetnsAddr6 ]; }
    ];
    nftables.stopJsonRules = mkFlushRules {};
    nftables.jsonRules = mkRules {
      selfIp4 = wanNetnsAddr4;
      selfIp6 = wanNetnsAddr6;
      lans = [ "veth-wan-b" ];
      wans = [ "wan" ];
      netdevIngressWanRules = with notnft.dsl; with payload; [
        [(is.eq (fib (f: with f; [ saddr mark iif ]) (f: f.oif)) missing) (log "wan oif missing ") drop]
      ];
      inetDnatRules = 
        builtins.concatLists (map
          (rule: let
            inherit (notnft.inetProtos) tcp udp;
            protocols = if rule.tcp && rule.udp then notnft.dsl.set [ tcp udp ] else if rule.tcp then tcp else udp;
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
            inherit (notnft.inetProtos) tcp udp;
            protocols = if rule.tcp && rule.udp then notnft.dsl.set [ tcp udp ] else if rule.tcp then tcp else udp;
            rule4 = rule.target4; rule6 = rule.target6;
          in with notnft.dsl; with payload;
            lib.optionals (rule4 != null && rule4.address == gatewayAddr4) [
              [ (is.eq meta.iifname "wan") (is.eq meta.oifname "veth-wan-b") (is.eq ip.protocol protocols)
                (is.eq th.dport (if rule4.port != null then rule4.port else rule.port)) (is.eq ip.daddr rule4.address) masquerade ]
            ] ++ lib.optionals (rule6 != null && rule6.address == gatewayAddr6) [
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
        [(is.eq th.dport 22) accept]
      ];
    };
  };
  router.networkNamespaces.default.rules = [
    { ipv6 = false; extraArgs = [ "fwmark" wan_table "table" wan_table ]; }
    { ipv6 = true; extraArgs = [ "fwmark" wan_table "table" wan_table ]; }
    # don't add vpn_table as it should be the default
    { ipv6 = false; extraArgs = [ "fwmark" iot_table "table" iot_table ]; }
    { ipv6 = true; extraArgs = [ "fwmark" iot_table "table" iot_table ]; }
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

  networking.wireguard.interfaces.wg0 = cfg.wireguard // {
    socketNamespace = "wan";
    interfaceNamespace = "init";
  };

  networking.resolvconf.extraConfig = ''
    name_servers="${mainNetnsAddr4} ${mainNetnsAddr6}"
  '';
  users.users.${config.common.mainUsername}.extraGroups = [ config.services.unbound.group ];
  services.unbound = {
    enable = true;
    package = pkgs.unbound-with-systemd.override {
      stdenv = pkgs.ccacheStdenv;
      withPythonModule = true;
      python = unbound-python;
    };
    localControlSocketPath = "/run/unbound/unbound.ctl";
    # we override resolvconf above manually
    resolveLocalQueries = false;
    settings = {
      server = {
        interface = [ mainNetnsAddr4 mainNetnsAddr6 gatewayAddr4 gatewayAddr6 ];
        access-control = [ "${netnsCidr4} allow" "${netnsCidr6} allow" "${netCidr4} allow" "${netCidr6} allow" ];
        aggressive-nsec = true;
        do-ip6 = true;
        module-config = ''"validator python iterator"'';
        local-zone = [
          ''"local." static''
          ''"${cfg.domainName}." typetransparent''
        ];
        local-data = builtins.concatLists (map (domain:
          [
            ''"${domain}. A ${serverAddress4}"''
            ''"${domain}. AAAA ${serverAddress6}"''
          ]) hosted-domains);
      };
      python.python-script = toString ./avahi-resolver-v2.py;
      remote-control.control-enable = true;
    };
  };
  networking.hosts."${serverAddress4}" = hosted-domains;
  networking.hosts."${serverAddress6}" = hosted-domains;
  systemd.services.unbound = {
    environment.PYTHONPATH = "${unbound-python}/${unbound-python.sitePackages}";
    environment.MDNS_ACCEPT_NAMES = "^.*\\.local\\.$";
    # load vpn_domains.json and vpn_ips.json, as well as unvpn_domains.json and unvpn_ips.json
    # resolve domains and append it to ips and add it to the nftables sets
    environment.NFT_QUERIES = "vpn:force_vpn4,force_vpn6;unvpn:force_unvpn4,force_unvpn6";
    # it needs to run after br0 has been set up because it sets up the sets
    after = [ "nftables-br0.service" ];
    wants = [ "nftables-br0.service" ];
    # allow it to call nft
    serviceConfig.AmbientCapabilities = [ "CAP_NET_ADMIN" ];
  };
  systemd.services.update-rkn-blacklist = {
    # fetch vpn_ips.json and vpn_domains.json for unbound
    script = ''
      BLACKLIST=$(${pkgs.coreutils}/bin/mktemp) || exit 1
      ${pkgs.curl}/bin/curl "https://reestr.rublacklist.net/api/v2/ips/json/" -o "$BLACKLIST" || exit 1
      chown unbound:unbound "$BLACKLIST" && mv "$BLACKLIST" /var/lib/unbound/vpn_ips.json
      ${pkgs.curl}/bin/curl "https://reestr.rublacklist.net/api/v2/domains/json/" -o "$BLACKLIST" || exit 1
      chown unbound:unbound "$BLACKLIST" && mv "$BLACKLIST" /var/lib/unbound/vpn_domains.json
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
  # i don't want to connect by uart each time something goes wrong
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
      ExecStart = "${config.programs.ssh.package}/bin/sshd -D -f /etc/ssh/sshd_config";
      KillMode = "process";
      Restart = "always";
      Type = "simple";
      NetworkNamespacePath = "/var/run/netns/wan";
    };
  };

  services.printing = {
    enable = true;
    allowFrom = [ "localhost" netCidr4 netCidr6 ];
    browsing = true;
    clientConf = ''
      ServerName router.local
    '';
    defaultShared = true;
    drivers = [ pkgs.hplip ];
    startWhenNeeded = false;
  };

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

  # it takes a stupidly long time when done via qemu
  # (also it's supposed to be disabled by default but it was enabled for me, why?)
  documentation.man.generateCaches = false;
}
