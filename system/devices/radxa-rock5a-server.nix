{ config
, lib
, router-config
, hardware
, ... }:

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

  networking.useDHCP = true;
  /*
  # as expected, systemd initrd and networking didn't work well, and i really cba to debug it
  networking.useDHCP = false;
  networking.useNetworkd = true;
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
    };
  };*/

  boot.initrd = {
    /*systemd = {
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
        };
      };
    };*/
    preLVMCommands = lib.mkOrder 499 ''
      ip link set eth0 address ${router-config.router-settings.serverInitrdMac} || true
    '';
    postMountCommands = ''
      ip link set eth0 address ${router-config.router-settings.serverMac} || true
    '';
    network.enable = true;
    network.udhcpc.extraArgs = [ "-t6" ];
    network.ssh = {
      enable = true;
      port = 22;
      authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
      hostKeys = [
        "/secrets/initrd/ssh_host_rsa_key"
        "/secrets/initrd/ssh_host_ed25519_key"
      ];
      # shell = "/bin/cryptsetup-askpass";
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
    "/" =    { device = "none"; fsType = "tmpfs"; inherit neededForBoot;
               options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
              { device = "UUID=${uuids.bch}"; fsType = "bcachefs"; inherit neededForBoot;
                options = [ "errors=ro" ]; };
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
