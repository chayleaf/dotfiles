# device-specific non-portable config
let
  efiPart = "/dev/disk/by-uuid/D77D-8CE0";

  encPart = "/dev/disk/by-uuid/ce6ccdf0-7b6a-43ae-bfdf-10009a55041a";
  cryptrootUuid = "f4edc0df-b50b-42f6-94ed-1c8f88d6cdbb";
  cryptroot = "/dev/disk/by-uuid/${cryptrootUuid}";

  dataPart = "/dev/disk/by-uuid/f1447692-fa7c-4bd6-9cb5-e44c13fddfe3";
  datarootUuid = "fa754b1e-ac83-4851-bf16-88efcd40b657";
  dataroot = "/dev/disk/by-uuid/${datarootUuid}";
in {
  imports = [
    ../hardware/msi-delta-15
    ../hosts/nixmsi.nix
  ];

  boot.initrd = {
    # insert crypto_keyfile into initrd so that grub can tell the kernel the
    # encryption key once I unlock the /boot partition
    secrets."/crypto_keyfile.bin" = "/boot/initrd/crypto_keyfile.bin";
    luks.devices."cryptroot" = {
      device = encPart;
      # idk whether this is needed but it works
      preLVM = true;
      # see https://asalor.blogspot.de/2011/08/trim-dm-crypt-problems.html before enabling
      allowDiscards = true;
      # improve SSD performance
      bypassWorkqueues = true;
      keyFile = "/crypto_keyfile.bin";
    };
    luks.devices."dataroot" = {
      device = dataPart;
      preLVM = true;
      allowDiscards = true;
      bypassWorkqueues = true;
      keyFile = "/crypto_keyfile.bin";
    };
  };
  boot.loader = {
    grub = {
      enable = true;
      enableCryptodisk = true;
      efiSupport = true;
      # nodev = disable bios support 
      device = "nodev";
    };
    efi.canTouchEfiVariables = true;
    efi.efiSysMountPoint = "/boot/efi";
  };
  boot.resumeDevice = cryptroot;
  boot.kernelParams = [
    "resume=/@swap/swapfile"
    # resume_offset = $(btrfs inspect-internal map-swapfile -r path/to/swapfile)
    "resume_offset=533760"
  ];
  fileSystems = let
    device = cryptroot;
    fsType = "btrfs";
    # max compression! my cpu is pretty good anyway
    compress = "compress=zstd:15";
    discard = "discard=async";
    neededForBoot = true;
  in {
    # mount root on tmpfs
    "/" =     { device = "none"; fsType = "tmpfs"; inherit neededForBoot;
                options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
              { inherit device fsType neededForBoot;
                options = [ discard compress "subvol=@" ]; };
    "/nix" =  { inherit device fsType neededForBoot;
                options = [ discard compress "subvol=@nix" "noatime" ]; };
    "/swap" = { inherit device fsType neededForBoot;
                options = [ discard "subvol=@swap" "noatime" ]; };
    "/home" = { inherit device fsType;
                options = [ discard compress "subvol=@home" ]; };
    # why am I even bothering with creating this subvolume every time if I don't use snapshots anyway?
    "/.snapshots" =
              { inherit device fsType;
                options = [ discard compress "subvol=@snapshots" ]; };
    "/boot" = { inherit device fsType neededForBoot;
                options = [ discard compress "subvol=@boot" ]; };
    "/boot/efi" =
              { device = efiPart; fsType = "vfat"; inherit neededForBoot; };
    "/data" =
              { device = dataroot; fsType = "btrfs";
                options = [ discard compress ]; };
  };

  impermanence = {
    enable = true;
    path = /persist;
  };

  # fix for my realtek usb ethernet adapter
  services.tlp.settings.USB_DENYLIST = "0bda:8156";

  swapDevices = [ { device = "/swap/swapfile"; } ];

  # dedupe
  services.beesd = {
    # i have a lot of ram :tonystark:
    filesystems.cryptroot = {
      spec = "UUID=${cryptrootUuid}";
      hashTableSizeMB = 128;
      extraOptions = [ "--loadavg-target" "8.0" ];
    };
    filesystems.dataroot = {
      spec = "UUID=${datarootUuid}";
      hashTableSizeMB = 256;
      extraOptions = [ "--loadavg-target" "8.0" ];
    };
  };
}
