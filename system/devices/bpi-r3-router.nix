storage:

{ config, ... }:

let
  rootUuid = "44444444-4444-4444-8888-888888888888";
  rootPart = "/dev/disk/by-uuid/${rootUuid}";
in

{
  imports = [
    ../hardware/bpi-r3/${storage}.nix
    ../hosts/router
  ];
  networking.hostName = "nixos-router";

  systemd.enableEmergencyMode = false;
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  fileSystems = {
    # mount root on tmpfs
    "/" = {
      device = "none";
      fsType = "tmpfs";
      neededForBoot = true;
      options = [
        "defaults"
        "size=2G"
        "mode=755"
      ];
    };
    "/persist" = {
      device = rootPart;
      fsType = "btrfs";
      neededForBoot = true;
      options = [
        "compress=zstd:15"
        "subvol=@"
      ];
    };
    "/boot" = {
      device = rootPart;
      fsType = "btrfs";
      neededForBoot = true;
      options = [ "subvol=@boot" ];
    };
    "/nix" = {
      device = rootPart;
      fsType = "btrfs";
      neededForBoot = true;
      options = [
        "compress=zstd:15"
        "subvol=@nix"
      ];
    };
  };

  impermanence = {
    enable = true;
    path = /persist;
    directories = [
      {
        directory = /home/${config.common.mainUsername};
        user = config.common.mainUsername;
        group = "users";
        mode = "0700";
      }
      {
        directory = /root;
        mode = "0700";
      }
    ];
  };

  # technically hostapd/lan0..4 interface config should be here as well
  # but for easier demonstration i'll keep it all in ../hosts/router
}
