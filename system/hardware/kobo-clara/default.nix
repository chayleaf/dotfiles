{ pkgs
, config
, lib
, ...
}:

{
  config = lib.mkMerge [
    {
      boot.loader = {
        grub.enable = false;
        generic-extlinux-compatible.enable = true;
      };

      boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.buildLinuxWithCcache pkgs.linux_koboClara);

      hardware.deviceTree.enable = true;
      hardware.deviceTree.filter = "imx6sll-kobo-clarahd.dtb";
      hardware.enableRedistributableFirmware = true;

      boot.initrd.availableKernelModules = [ "mmc_block" "dm_mod" "tps6518x_hwmon" "tps6518x_regulator" "mxc_epdc_drm" ];
      boot.kernelParams = [ "console=ttymxc0,115200" ];
      # "dtb=/${config.hardware.deviceTree.name}"

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

      hardware.firmware = [ pkgs.firmware-kobo-clara ];
      nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "firmware-kobo-clara"
      ];
      system.build.uboot = pkgs.ubootKoboClara;
      boot.initrd.includeDefaultModules = false;
    }
    (lib.mkIf config.phone.buffyboard.enable {
      common.gettyAutologin = true;
    })
  ];
}
