{ config
, ... }:

let
  rootUuid = "00000000-0000-0000-0000-000000000000";
  rootPart = "/dev/disk/by-uuid/${rootUuid}";
in {
  system.stateVersion = "22.11";
  # TODO
  fileSystems = {
    # mount root on tmpfs
    "/" =     { device = "none"; fsType = "tmpfs"; neededForBoot = true;
                options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
              { device = rootPart; fsType = "btrfs"; neededForBoot = true;
                options = [ ]; };
  };
  impermanence = {
    enable = true;
    path = /persist;
    directories = [
      { directory = /home/${config.common.mainUsername}; user = config.common.mainUsername; group = config.common.mainUsername; mode = "0700"; }
      { directory = /root; mode = "0700"; }
      /nix
      /boot
    ];
  };
}
