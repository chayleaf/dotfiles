{ config
, lib
, router-config
, ... }:

let
  encUuid = "15945050-df48-418b-b736-827749b9262a";
  encPart = "/dev/disk/by-uuid/${encUuid}";
  rootUuid = "de454394-8cc1-4267-b62b-1e25062f7cf4";
  rootPart = "/dev/disk/by-uuid/${rootUuid}";
  bootUuid = "0603-5955";
  bootPart = "/dev/disk/by-uuid/${bootUuid}";
in

{
  imports = [
    ../hardware/radxa-rock5a
    ../hosts/nixserver
  ];

  networking.useDHCP = true;

  boot.initrd = {
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
    luks.devices."cryptroot" = {
      device = encPart;
      # idk whether this is needed but it works
      preLVM = true;
      # see https://asalor.blogspot.de/2011/08/trim-dm-crypt-problems.html before enabling
      allowDiscards = true;
      # improve SSD performance
      bypassWorkqueues = true;
    };
  };

  fileSystems = {
    "/" =    { device = "none"; fsType = "tmpfs"; neededForBoot = true;
               options = [ "defaults" "size=2G" "mode=755" ]; };
    # TODO: switch to bcachefs?
    # I wanna do it some day, but maybe starting with the next disk I get for this server
    "/persist" =
             { device = rootPart; fsType = "btrfs"; neededForBoot = true;
               options = [ "subvol=@" "compress=zstd" ]; };
    "/boot" =
             { device = bootPart; fsType = "vfat"; neededForBoot = true; };
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
