{
  pkgs,
  pkgs-kernel,
  lib,
  config,
  inputs,
  ...
}:

let
  cfg = config.phone;
  hw = pkgs.hw.oneplus-enchilada;
  hw-kernel = pkgs-kernel.hw.oneplus-enchilada;
in
{
  imports = [
    "${inputs.mobile-nixos}/modules/quirks/qualcomm/sdm845-modem.nix"
    "${inputs.mobile-nixos}/modules/quirks/audio.nix"
  ];

  options.phone = {
    adb.enable = lib.mkEnableOption "adb";
  };

  config = lib.mkMerge [
    {
      nixpkgs.overlays = [
        (self: super: {
          inherit (self.hw.oneplus-enchilada)
            pd-mapper
            qrtr
            rmtfs
            tqftpserv
            ;
        })
      ];
      hardware.enableRedistributableFirmware = true;
      mobile.quirks.qualcomm.sdm845-modem.enable = true;
      specialisation.nomodem.configuration = {
        mobile.quirks.qualcomm.sdm845-modem.enable = lib.mkForce false;
        systemd.services.q6voiced.enable = false;
      };
      mobile.quirks.audio.alsa-ucm-meld = true;
      environment.systemPackages = [ hw.alsa-ucm-conf ];
      systemd.services.q6voiced = {
        description = "QDSP6 driver daemon";
        after = [
          "ModemManager.service"
          "dbus.socket"
        ];
        wantedBy = [ "ModemManager.service" ];
        requires = [ "dbus.socket" ];
        serviceConfig.ExecStart = "${hw.q6voiced}/bin/q6voiced hw:0,6";
      };
      # TODO when testing PipeWire instead of PulseAudio, the following is needed:
      # https://gitlab.freedesktop.org/pipewire/wireplumber/-/blob/master/docs/rst/daemon/configuration/migration.rst
      # https://gitlab.com/postmarketOS/pmaports/-/tree/master/device/community/soc-qcom-sdm845/
      /*
        systemd.user.services.wireplumber.environment.WIREPLUMBER_CONFIG_DIR = pkgs.runCommand "wireplumber-config" {} ''
          cp -a "${pkgs.wireplumber}/share/wireplumber" "$out"
          chmod +w "$out" "$out/wireplumber.conf.d"
          ln -s ${pkgs.fetchurl {
            url = "https://gitlab.com/postmarketOS/pmaports/-/raw/a82d8636562805d71e16e93f7571cc1f6ddbeb45/device/community/soc-qcom-sdm845/51-qcom-sdm845.conf";
            hash = "sha256-EM2I9hwTYnK5FepB4RBI5t8sIFQ/uqN5AuTwGepzjB0=";
          }} "$out/wireplumber.conf.d/51-qcom-sdm845.conf"
        '';
        systemd.services.wireplumber.environment.WIREPLUMBER_CONFIG_DIR = config.systemd.user.services.wireplumber.environment.WIREPLUMBER_CONFIG_DIR;
      */
      networking.modemmanager.enable = !config.networking.networkmanager.enable;
      services.udev.extraRules = ''
        SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT}=="1", SUBSYSTEMS=="input", ATTRS{name}=="spmi_haptics", TAG+="uaccess", ENV{FEEDBACKD_TYPE}="vibra"
        SUBSYSTEM=="misc", KERNEL=="fastrpc-*", ENV{ACCEL_MOUNT_MATRIX}+="-1, 0, 0; 0, -1, 0; 0, 0, -1"
      '';
      services.upower = {
        enable = true;
        percentageLow = 10;
        percentageCritical = 5;
        percentageAction = 3;
        criticalPowerAction = "PowerOff";
      };
      hardware.firmware = lib.mkAfter [ hw.firmware ];
      boot.kernelPackages = lib.mkForce (pkgs-kernel.linuxPackagesFor hw-kernel.linux);
      hardware.deviceTree.enable = true;
      hardware.deviceTree.name = "qcom/sdm845-oneplus-enchilada.dtb";
      systemd.services.ModemManager.serviceConfig.ExecStart = [
        ""
        "${pkgs.modemmanager}/bin/ModemManager --test-quick-suspend-resume"
      ];
      # loglevel=7 console=ttyMSM0,115200 is a way to delay boot
      # see https://gitlab.freedesktop.org/drm/msm/-/issues/46
      boot.consoleLogLevel = 7;
      boot.kernelParams = [
        "console=ttyMSM0,115200"
        "console=tty0"
        "dtb=/${config.hardware.deviceTree.name}"
      ];
      boot.loader.systemd-boot.extraFiles.${config.hardware.deviceTree.name} =
        "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "firmware-oneplus-sdm845"
          "firmware-oneplus-sdm845-xz"
        ];
      system.build.uboot = pkgs.ubootImage;
      boot.initrd.includeDefaultModules = false;
      boot.initrd.availableKernelModules = [
        "sd_mod"
        "usbhid"
        "ehci_hcd"
        "ohci_hcd"
        "xhci_hcd"
        "uhci_hcd"
        "ehci_pci"
        "ohci_pci"
        "xhci_pci"
        "hid_generic"
        "hid_lenovo"
        "hid_apple"
        "hid_roccat"
        "hid_logitech_hidpp"
        "hid_logitech_dj"
        "hid_microsoft"
        "hid_cherry"
      ];
      boot.initrd.kernelModules = [
        "i2c_qcom_geni"
        "rmi_core"
        "rmi_i2c"
        "qcom_spmi_haptics"
        "dm_mod"
      ];
    }
    (lib.mkIf cfg.buffyboard.enable {
      common.gettyAutologin = true;
    })
    (lib.mkIf cfg.adb.enable {
      boot.initrd.kernelModules = [
        "configfs"
        "libcomposite"
        "g_ffs"
      ];

      boot.specialFileSystems = {
        "/sys/kernel/config" = {
          device = "configfs";
          fsType = "configfs";
          options = [
            "nosuid"
            "noexec"
            "nodev"
          ];
        };
      };

      boot.initrd.extraUtilsCommands = ''
        copy_bin_and_libs ${hw.adbd}/bin/adbd
        cp -pv ${pkgs.glibc.out}/lib/libnss_files.so.* $out/lib
      '';

      boot.initrd.preLVMCommands = ''
        mkdir -p /sys/kernel/config/usb_gadget/g1/strings/0x409
        cd /sys/kernel/config/usb_gadget/g1
        echo 0x18D1 > idVendor
        echo 0xD001 > idProduct
        echo oneplus-enchilada > strings/0x409/product
        echo NixOS > strings/0x409/manufacturer
        echo 0123456789 > strings/0x409/serialnumber

        mkdir -p configs/c.1/strings/0x409
        echo adb > configs/c.1/strings/0x409/configuration

        mkdir -p functions/ffs.adb
        ln -s functions/ffs.adb configs/c.1/adb

        mkdir -p /dev/usb-ffs/adb
        mount -t functionfs adb /dev/usb-ffs/adb
        adbd &

        ls /sys/class/udc/ | head -n1 > UDC
        cd /
      '';

      boot.initrd.postMountCommands = ''
        pkill -x adbd
      '';

      systemd.services.adbd = {
        description = "adb daemon";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${hw.adbd}/bin/adbd";
          Restart = "always";
        };
      };
    })
  ];
}
