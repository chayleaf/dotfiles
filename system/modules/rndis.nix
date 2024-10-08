{ lib
, config
, ...
}:

let
  cfg = config.phone;
in
{
  options = {
    phone.rndis.enable = lib.mkEnableOption "rndis";
  };
  config = lib.mkIf cfg.rndis.enable {
    boot.initrd.kernelModules = [ "configfs" "libcomposite" ];
    boot.initrd.availableKernelModules = [ "usb_f_rndis" "usb_f_ncm" ];

    boot.specialFileSystems = {
      "/sys/kernel/config" = {
        device = "configfs";
        fsType = "configfs";
        options = [ "nosuid" "noexec" "nodev" ];
      };
    };

    boot.initrd.preLVMCommands = ''
      if ! mountpoint /sys/kernel/config; then
        specialMount configfs /sys/kernel/config nosuid,noexec,nodev configfs
      fi
      mkdir -p /sys/kernel/config/usb_gadget/g1/strings/0x409
      cd /sys/kernel/config/usb_gadget/g1
      echo 0x18D1 > idVendor
      echo 0xD001 > idProduct
      echo nixos-device > strings/0x409/product
      echo NixOS > strings/0x409/manufacturer
      echo 0123456789 > strings/0x409/serialnumber

      mkdir -p configs/c.1/strings/0x409
      echo "USB network" > configs/c.1/strings/0x409/configuration

      mkdir -p functions/ncm.usb0 || mkdir -p functions/rndis.usb0
      ln -s functions/ncm.usb0 configs/c.1/ || ln -s functions/rndis.usb0 configs/c.1/

      ls /sys/class/udc/ | head -n1 > UDC
      cd /

      ifconfig rndis0 172.16.42.1 || ifconfig usb0 172.16.42.1 || ifconfig eth0 172.16.42.1
    '';

    boot.initrd.network.enable = true;
    boot.initrd.network.udhcpc.enable = false;
  };
}
