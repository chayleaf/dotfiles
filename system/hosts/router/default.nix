{ config
, pkgs
, ... }:

# EMMC size: 7818182656

let
  rootUuid = "44444444-4444-4444-8888-888888888888";
  rootPart = "/dev/disk/by-uuid/${rootUuid}";
  rootfsImage = pkgs.callPackage "${pkgs.path}/nixos/lib/make-ext4-fs.nix" {
    storePaths = config.system.build.toplevel;
    compressImage = false;
    volumeLabel = "NIX_ROOTFS";
  };
in {
  system.stateVersion = "22.11";
  # TODO
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
  hardware.wirelessRegulatoryDatabase = true;
  system.build.emmcImage = pkgs.callPackage ./image.nix {
    inherit config rootfsImage;
    bpiR3Stuff = pkgs.bpiR3StuffEmmc;
  };
  system.build.sdImage = pkgs.callPackage ./image.nix {
    inherit config rootfsImage;
    bpiR3Stuff = pkgs.bpiR3StuffSd;
  };
  system.build.rootfs = rootfsImage;
  boot.postBootCommands = ''
    if [ -f ${toString config.impermanence.path}/nix-path-registration ]; then
      ${config.nix.package.out}/bin/nix-store --load-db < ${toString config.impermanence.path}/nix-path-registration
      mkdir -p /etc
      touch /etc/NIXOS
      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      rm -f ${toString config.impermanence.path}/nix-path-registration
    fi
  '';
  boot.kernelParams = [ "boot.shell_on_fail" ];
}
