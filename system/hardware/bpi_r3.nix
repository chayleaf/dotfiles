{ pkgs
, lib
, ... }:

# WIP
{
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  # https://github.com/frank-w/BPI-Router-Linux
  boot.kernelPackages = pkgs.linuxPackagesFor ((pkgs.buildLinux ({
    version = "6.3";
    modDirVersion = "6.3.0";

    src = pkgs.fetchFromGitHub {
      owner = "frank-w";
      repo = "BPI-Router-Linux";
      rev = "6.3-main";
      hash = lib.fakeHash;
    };

    defconfig = "mt7986a_bpi-r3";
  })).overrideAttrs (old: {
    postConfigure = ''
      sed -i "$buildRoot/.config" -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
      sed -i "$buildRoot/include/config/auto.conf" -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
    '';
  }));

  hardware.deviceTree.enable = true;
  hardware.deviceTree.filter = "mt7986a-bananapi-bpi-r3*.dtb";
  hardware.enableRedistributableFirmware = true;
}
