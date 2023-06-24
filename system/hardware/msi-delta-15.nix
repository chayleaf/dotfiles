{ hardware
, ... }:

{
  imports = with hardware; [
    common-pc-ssd # enables fstrim
    common-cpu-amd # microcode
    common-cpu-amd-pstate # amd-pstate
    common-gpu-amd # configures drivers
    common-pc-laptop # enables tlp
  ];
  common.resolution = "1920x1080";
  vfio.pciIDs = [ "1002:73df" "1002:ab28" ];
  boot = {
    initrd.availableKernelModules = [ "nvme" "xhci_pci" ];
    kernelParams = [
      # disable PSR to *hopefully* avoid random hangs
      # this one didnt help
      "amdgpu.dcdebugmask=0x10"
      # maybe this one will?
      "amdgpu.noretry=0"
    ];
  };
}
