{ pkgs
, config
, ... }:

{
  boot.initrd.availableKernelModules = [
    "ahci" "usbhid" "usb_storage"
    # network in initrd
    "dwmac-rk" 
    # fde unlock in initrd
    "dm_mod" "dm_crypt" "encrypted_keys"
  ];

  # TODO: switch to upstream when PCIe support works
  # boot.kernelPackages = pkgs.linuxPackages_testing;
  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.buildLinux {
    version = "6.6.0-rc1";
    kernelPatches = [ ];
    src = pkgs.fetchFromGitLab {
      domain = "gitlab.collabora.com";
      group = "hardware-enablement";
      owner = "rockchip-3588";
      repo = "linux";
      rev = "f04271158aee35d270748301c5077231a75bc589";
      hash = "sha256-B85162plbt92p51f/M82y2zOg3/TqrBWqgw80ksJVGc=";
    };
  });

  boot.kernelParams = [ "boot.shell_on_fail" "dtb=/${config.hardware.deviceTree.name}" ];
  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "rockchip/rk3588s-rock-5a.dtb";
  hardware.deviceTree.filter = "*-rock-5a*.dtb";
  hardware.deviceTree.overlays = [ { name = "rock-5a-pcie"; filter = "*-rock-5a*.dtb"; dtsFile = ./rock-5a-pcie.dtso; } ];
  nixpkgs.hostPlatform = "aarch64-linux";

  # for a change, I have a big EFI partition on this device
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.extraFiles.${config.hardware.deviceTree.name} = "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.compressor = "zstd";
}
