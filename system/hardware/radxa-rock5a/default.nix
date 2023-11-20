{ pkgs
, config
, ... }:

{
  boot.initrd.availableKernelModules = [ "ahci" "usbhid" "usb_storage" ];

  # TODO: switch to mainline when PCIe support works
  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.buildLinuxWithCcache pkgs.linux_testing);
  boot.kernelPatches = [
    {
      name = "linux_6.7.patch";
      patch = ./linux_6.7.patch;
    }
  ];

  boot.kernelParams = [ "dtb=/${config.hardware.deviceTree.name}" ];
  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "rockchip/rk3588s-rock-5a.dtb";
  hardware.deviceTree.filter = "*-rock-5a*.dtb";
  hardware.deviceTree.overlays = [ { name = "rock-5a-pcie"; filter = "*-rock-5a*.dtb"; dtsFile = ./rock-5a-pcie.dtso; } ];

  # for a change, I have a big EFI partition on this device
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.extraFiles.${config.hardware.deviceTree.name} = "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.compressor = "zstd";
  nixpkgs.hostPlatform = "aarch64-linux";
}
