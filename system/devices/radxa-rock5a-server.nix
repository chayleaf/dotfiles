{ config
, lib
, pkgs
, router-config
, hardware
, ...
}:

# TODO: SYSTEMD_SULOGIN_FORCE

let
  uuids.enc = "15945050-df48-418b-b736-827749b9262a";
  uuids.swap = "5c7f9e4e-c245-4ccb-98a2-1211ea7008e8";
  uuids.boot = "0603-5955";
  uuids.bch0 = "9f10b9ac-3102-4816-8f2c-e0526c2aa65b";
  uuids.bch1 = "4ffed814-057c-4f9f-9a12-9d8ac6331e62";
  uuids.bch2 = "e761df86-35ce-4586-9349-2d646fcb1b2a";
  uuids.bch = "088a3d70-b54c-4437-8e01-feda6bfb7236";
  parts = builtins.mapAttrs (k: v: "/dev/disk/by-uuid/${v}") uuids;
in

{
  imports = [
    ../hardware/radxa-rock5a
    ../hosts/server
    hardware.common-pc-ssd
  ];

  boot.initrd.availableKernelModules = [
    # network in initrd
    "dwmac-rk" 
    # fde unlock in initrd
    "dm_mod" "dm_crypt" "encrypted_keys"
  ];

  systemd.enableEmergencyMode = false;
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.resolvconf.extraConfig = let
    ip = cidr: builtins.head (lib.splitString "/" cidr);
  in ''
    name_servers='${ip router-config.router-settings.network} ${ip router-config.router-settings.network6}'
  '';
  systemd.network = {
    enable = true;
    links."10-mac" = {
      matchConfig.OriginalName = "e*";
      linkConfig = {
        MACAddressPolicy = "none";
        MACAddress = router-config.router-settings.serverMac;
      };
    };
    networks."10-dhcp" = {
      DHCP = "yes";
      name = "e*";
      networkConfig.IPv6AcceptRA = "yes";
      dhcpV4Config = {
        ClientIdentifier = "mac";
        DUIDType = "link-layer";
      };
      dhcpV6Config.DUIDType = "link-layer";
    };
  };

  boot.initrd = {
    systemd = {
      services.unlock-bcachefs-persist.enable = false;
      enable = true;
      network = {
        enable = true;
        links."10-mac" = {
          matchConfig.OriginalName = "e*";
          linkConfig = {
            MACAddressPolicy = "none";
            MACAddress = router-config.router-settings.serverInitrdMac;
          };
        };
        networks."10-dhcp" = {
          DHCP = "yes";
          name = "e*";
          networkConfig = {
            IPv6AcceptRA = "yes";
          };
          dhcpV4Config = {
            ClientIdentifier = "mac";
            DUIDType = "link-layer";
          };
          dhcpV6Config = {
            DUIDType = "link-layer";
          };
        };
      };
    };
    network.enable = false;
    network.flushBeforeStage2 = true;
    systemd.initrdBin = [ pkgs.iproute2 pkgs.vim pkgs.bashInteractive pkgs.util-linux ];
    systemd.storePaths = [ pkgs.vim pkgs.busybox ];
    systemd.users.root.shell = "/bin/bash";
    network.ssh = {
      enable = true;
      port = 22;
      authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
      hostKeys = [
        "/secrets/initrd/ssh_host_rsa_key"
        "/secrets/initrd/ssh_host_ed25519_key"
      ];
    };
    luks.devices.cryptroot = {
      device = parts.enc;
      # idk whether this is needed but it works
      preLVM = true;
      # see https://asalor.blogspot.de/2011/08/trim-dm-crypt-problems.html before enabling
      allowDiscards = true;
      # improve SSD performance
      bypassWorkqueues = true;
    };
    luks.devices.bch0 = { device = parts.bch0; preLVM = true; allowDiscards = true; bypassWorkqueues = true; };
    luks.devices.bch1 = { device = parts.bch1; preLVM = true; allowDiscards = true; bypassWorkqueues = true; };
    luks.devices.bch2 = { device = parts.bch2; preLVM = true; allowDiscards = true; bypassWorkqueues = true; };
  };

  boot.supportedFilesystems = [ "bcachefs" ];

  fileSystems = let
    neededForBoot = true;
  in {
    "/" =     { device = "none"; fsType = "tmpfs"; inherit neededForBoot;
                options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
              { device = "UUID=${uuids.bch}"; fsType = "bcachefs"; inherit neededForBoot;
                # TODO: remove the if when systemd >= 257
                options = let
                  dep = if lib.versionAtLeast config.boot.initrd.systemd.package.version "257" then "wants" else "requires";
                in [
                  "degraded"
                  "errors=ro"
                  "x-systemd.device-timeout=0"
                  "x-systemd.mount-timeout=0"
                  "x-systemd.${dep}=dev-mapper-bch0.device"
                  "x-systemd.${dep}=dev-mapper-bch1.device"
                  "x-systemd.${dep}=dev-mapper-bch2.device"
                ]; };
    "/boot" = { device = parts.boot; fsType = "vfat"; inherit neededForBoot; };
  };

  swapDevices = [ { device = parts.swap; } ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };

  impermanence = {
    enable = true;
    path = /persist;
    directories = [
      { directory = /home/${config.common.mainUsername}; user = config.common.mainUsername; group = "users"; mode = "0700"; }
      { directory = /root; mode = "0700"; }
      { directory = /nix; }
    ];
  };
}
