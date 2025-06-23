{
  pkgs,
  config,
  lib,
  ...
}:

let
  pkgs' = pkgs.hw.kobo-clara;
in
{
  options = {
    ereader.epdc-firmware = lib.mkOption {
      type = lib.types.path;
    };
  };
  config = lib.mkMerge [
    {
      boot.loader = {
        grub.enable = false;
        generic-extlinux-compatible.enable = true;
      };

      boot.kernelPackages = pkgs.linuxPackagesFor pkgs'.linux;

      boot.initrd.preLVMCommands = ''
        echo 0 > /sys/class/graphics/fbcon/cursor_blink
        (cd /sys/bus/platform/devices && echo *epdc >/sys/bus/platform/drivers/mxc_epdc/bind)
      '';
      boot.consoleLogLevel = 7;
      hardware.deviceTree.enable = true;
      hardware.deviceTree.filter = "imx6sll-kobo-clarahd.dtb";
      hardware.firmware = [
        (pkgs.runCommand "epdc-firmware" { } ''
          mkdir -p $out/lib/firmware/imx/epdc
          cp ${config.ereader.epdc-firmware} $out/lib/firmware/imx/epdc/epdc.fw
        '')
      ];
      # boot.initrd.extraFiles."lib/firmware/imx/epdc/epdc.fw".source = pkgs.copyPathToStore config.ereader.epdc-firmware;
      nixpkgs.overlays = [
        (self: super: {
          makeModulesClosure =
            args:
            (super.makeModulesClosure args).overrideAttrs (old: {
              builder = pkgs.writeShellScript "builder.sh" ''
                source ${old.builder}
                cd "$firmware"
                mkdir -p "$out/lib/firmware/imx"
                cp --no-preserve=mode -vrL lib/firmware/imx/* "$out/lib/firmware/imx/"
              '';
            });
        })
      ];

      hardware.enableRedistributableFirmware = true;

      boot.initrd.kernelModules = [
        "tps6518x_hwmon"
        "tps6518x_regulator"
        "mxc_epdc_drm"
      ];
      boot.initrd.availableKernelModules = [
        "mmc_block"
        "dm_mod"
      ];
      boot.kernelParams = [
        "console=ttymxc0,115200"
        "detect_clara_rev"
      ];
      # "dtb=/${config.hardware.deviceTree.name}"

      boot.initrd.compressor = "zstd";

      boot.postBootCommands = ''
        if [ -f ${toString config.impermanence.path}/nix-path-registration ]; then
          ${config.nix.package.out}/bin/nix-store --load-db < ${toString config.impermanence.path}/nix-path-registration
          mkdir -p /etc
          touch /etc/NIXOS
          ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
          rm -f ${toString config.impermanence.path}/nix-path-registration
        fi
      '';

      system.build.uboot = pkgs'.uboot;
      boot.initrd.includeDefaultModules = false;
    }
    (lib.mkIf config.phone.buffyboard.enable {
      common.gettyAutologin = true;
    })
  ];
}
