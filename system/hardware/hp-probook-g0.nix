{
  hardware,
  ...
}:

{
  imports = with hardware; [
    common-pc-hdd
    common-cpu-intel
    common-gpu-amd
    common-pc-laptop
  ];
  common.resolution = "1366x768";
  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ehci_pci"
      "ahci"
      "usb_storage"
      "sd_mod"
      "sr_mod"
      "rtsx_pci_sdmmc"
    ];
    kernelModules = [ "kvm-intel" ];
  };
  vfio.intelCpu = true;
}
