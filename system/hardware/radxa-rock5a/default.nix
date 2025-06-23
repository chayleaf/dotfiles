{
  pkgs,
  config,
  ...
}:

{
  boot.initrd.availableKernelModules = [
    "ahci"
    "usbhid"
    "usb_storage"
    "phy-rockchip-naneng-combphy"
  ];

  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_latest;

  boot.kernelParams = [
    "dtb=/${config.hardware.deviceTree.name}"
    # TODO: hopefully remove in late 2025 or whatever
    # https://lore.kernel.org/lkml/20250220-rk3588-gpu-pwr-domain-regulator-v6-0-a4f9c24e5b81@kernel.org/
    "modprobe.blacklist=panthor"
  ];
  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "rockchip/rk3588s-rock-5a.dtb";
  hardware.deviceTree.filter = "*-rock-5a*.dtb";
  hardware.deviceTree.overlays = [
    {
      name = "rock-5a-pcie";
      filter = "*-rock-5a*.dtb";
      dtsFile = ./rock-5a-pcie.dtso;
    }
  ];

  # for a change, I have a big EFI partition on this device
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.extraFiles.${config.hardware.deviceTree.name} =
    "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.compressor = "zstd";
  nixpkgs.hostPlatform = "aarch64-linux";
}
