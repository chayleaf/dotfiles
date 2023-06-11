{ pkgs
, ... }:

{
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  # i'm not about to build a kernel on every update without an arm device...
  # i guess i could use my phone for building it, but no, not interested
  # boot.kernelPackages = pkgs.linuxPackages_testing;
  boot.kernelPackages = pkgs.linuxPackages_bpiR3;

  hardware.deviceTree.enable = true;
  hardware.deviceTree.filter = "*mt7986*";
  hardware.enableRedistributableFirmware = true;

  # # disable a bunch of useless drivers
  # boot.initrd.includeDefaultModules = false;
  boot.initrd.availableKernelModules = [ "mmc_block" "dm_mod" "rfkill" "cfg80211" "mt7915e" ];
  boot.kernelParams = [ "console=ttyS0,115200" ];

  boot.initrd.compressor = "zstd";
  nixpkgs.buildPlatform = "x86_64-linux";
}
