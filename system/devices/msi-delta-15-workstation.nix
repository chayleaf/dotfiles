# device-specific non-portable config
{
  ...
}:

let
  uuids.efi = "D97E-A4D5";
  uuids.encroot = "a2c3c9ea-2c73-4786-bff7-5f0aa7097912";
  uuids.root = "dc669123-d6d3-447f-9ce3-c22587e5fa6a";
  uuids.encdata = "f1447692-fa7c-4bd6-9cb5-e44c13fddfe3";
  uuids.data = "fa754b1e-ac83-4851-bf16-88efcd40b657";
  uuids.swap = "01c21ed8-0f40-4892-825d-81f5ddb9a0a2";
  parts = builtins.mapAttrs (k: v: "/dev/disk/by-uuid/${v}") uuids;
in

{
  imports = [
    ../hardware/msi-delta-15
    ../hosts/nixmsi.nix
  ];

  boot.initrd.systemd.enable = false;
  boot.initrd = {
    luks.devices.cryptroot = {
      device = parts.encroot;
      # see https://asalor.blogspot.de/2011/08/trim-dm-crypt-problems.html before enabling
      allowDiscards = true;
    };
    luks.devices.dataroot = {
      device = parts.encdata;
      allowDiscards = true;
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [ "boot.shell_on_fail" ];

  fileSystems = {
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
      device = parts.root;
      fsType = "bcachefs";
      neededForBoot = true;
      options = [ "discard=1" ];
    };
    "/boot" = {
      device = parts.efi;
      fsType = "vfat";
      neededForBoot = true;
    };
    "/data" = {
      device = parts.data;
      fsType = "btrfs";
      options = [
        "discard=async"
        "compress=zstd:15"
      ];
    };
  };
  impermanence.directories = [
    /root
    /home
    /nix
  ];

  impermanence = {
    enable = true;
    path = /persist;
  };

  # fix for my realtek usb ethernet adapter
  services.tlp.settings.USB_DENYLIST = "0bda:8156";

  swapDevices = [ { device = parts.swap; } ];
  boot.resumeDevice = parts.swap;

  # dedupe
  services.beesd = {
    filesystems.dataroot = {
      spec = "UUID=${uuids.data}";
      hashTableSizeMB = 256;
      extraOptions = [
        "--loadavg-target"
        "8.0"
      ];
    };
  };
}
