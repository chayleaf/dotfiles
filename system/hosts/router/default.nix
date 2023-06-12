{ config
, ... }:

let
  rootUuid = "44444444-4444-4444-8888-888888888888";
  rootPart = "/dev/disk/by-uuid/${rootUuid}";
in {
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
  services.openssh.enable = true;
  impermanence = {
    enable = true;
    path = /persist;
    directories = [
      { directory = /home/${config.common.mainUsername}; user = config.common.mainUsername; group = config.common.mainUsername; mode = "0700"; }
      { directory = /root; mode = "0700"; }
    ];
  };
}
