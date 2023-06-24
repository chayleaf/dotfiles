{ config, ... }:

{
  imports = [ ./. ];
  hardware.deviceTree.overlays = [
    {
      name = "mt7986a-bananapi-bpi-r3-sd.dtbo";
      dtboFile = "${config.boot.kernelPackages.kernel}/dtbs/mediatek/mt7986a-bananapi-bpi-r3-sd.dtbo";
    }
  ];
}
