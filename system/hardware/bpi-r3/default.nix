{ pkgs
, config
, ... }:

{
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  boot.kernelPackages = config._module.args.fromSourcePkgs.linuxPackages_bpiR3_ccache or pkgs.linuxPackages_bpiR3_ccache;

  hardware.deviceTree.enable = true;
  hardware.deviceTree.filter = "mt7986a-bananapi-bpi-r3.dtb";
  hardware.enableRedistributableFirmware = true;
  hardware.deviceTree.overlays = [
    {
      name = "mt7986a-bananapi-bpi-r3-wireless.dts";
      dtsFile = ./mt7986a-bananapi-bpi-r3-wireless.dts;
    }
  ];

  # # disable a bunch of useless drivers
  # boot.initrd.includeDefaultModules = false;
  boot.initrd.availableKernelModules = [ "mmc_block" "dm_mod" "rfkill" "cfg80211" "mt7915e" ];
  boot.kernelParams = [ "boot.shell_on_fail" "console=ttyS0,115200" ];

  boot.initrd.compressor = "zstd";

  system.build.rootfsImage = pkgs.callPackage "${pkgs.path}/nixos/lib/make-ext4-fs.nix" {
    storePaths = config.system.build.toplevel;
    compressImage = false;
    volumeLabel = "NIX_ROOTFS";
  };

  boot.postBootCommands = ''
    if [ -f ${toString config.impermanence.path}/nix-path-registration ]; then
      ${config.nix.package.out}/bin/nix-store --load-db < ${toString config.impermanence.path}/nix-path-registration
      mkdir -p /etc
      touch /etc/NIXOS
      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      rm -f ${toString config.impermanence.path}/nix-path-registration
    fi
  '';

  hardware.wirelessRegulatoryDatabase = true;
}
