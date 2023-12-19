{ config
, lib
, ...
}:

let
  uuids.enc = "e2abdea5-71dc-4a9e-aff3-242117342d60";
  uuids.boot = "9DA3-28AC";
  uuids.bch = "ac343ffb-407c-4966-87bf-a0ef1075e93d";
  parts = builtins.mapAttrs (k: v: "/dev/disk/by-uuid/${v}") uuids;
in

{
  imports = [
    ../hardware/oneplus-enchilada
    ../hosts/phone
  ];

  # https://gitlab.com/postmarketOS/pmaports/-/issues/2440
  # networking.wireless.iwd.enable = true;
  networking.modemmanager.enable = lib.mkForce false;
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

  boot.supportedFilesystems = [ "bcachefs" ];

  fileSystems = let
    neededForBoot = true;
  in {
    "/" =     { device = "none"; fsType = "tmpfs"; inherit neededForBoot;
                options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
              { device = "UUID=${uuids.bch}"; fsType = "bcachefs"; inherit neededForBoot;
                options = [ "errors=ro" ]; };
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
