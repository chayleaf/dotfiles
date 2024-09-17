{ config
, ...
}:

let
  uuids.enc = "e2abdea5-71dc-4a9e-aff3-242117342d60";
  uuids.boot = "9DA3-28AC";
  uuids.root = "5fadc23c-f374-442d-8b05-fb76611c9eb7";
  parts = builtins.mapAttrs (k: v: "/dev/disk/by-uuid/${v}") uuids;
in

{
  imports = [
    ../hardware/oneplus-enchilada
    ../hosts/phone
  ];

  # https://gitlab.com/postmarketOS/pmaports/-/issues/2440
  # networking.wireless.iwd.enable = true;
  networking.networkmanager.enable = true;

  boot.loader = {
    grub.enable = false;
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = false;
  };

  boot.initrd = {
    luks.devices.cryptroot = {
      device = parts.enc;
      allowDiscards = true;
    };
  };

  fileSystems = let
    neededForBoot = true;
  in {
    "/" =     { device = "none"; fsType = "tmpfs"; inherit neededForBoot;
                options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
              { device = parts.root; fsType = "btrfs"; inherit neededForBoot;
                options = [ "discard=async" "compress=zstd:15" ]; };
    "/boot" = { device = parts.boot; fsType = "vfat"; inherit neededForBoot; };
  };

  zramSwap.enable = true;

  impermanence = {
    enable = true;
    path = /persist;
    directories = [
      { directory = /home/${config.common.mainUsername}; user = config.common.mainUsername; group = "users"; mode = "0700"; }
      { directory = /root; mode = "0700"; }
      { directory = /nix; }
      { directory = /secrets; mode = "0000"; }
    ];
  };
}
