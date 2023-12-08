{ hardware
, pkgs
, lib
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
    kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor pkgs.linux_latest);
    initrd.availableKernelModules = [ "nvme" "xhci_pci" ];
    kernelParams = [
      # disable PSR to *hopefully* avoid random hangs
      # this one didnt help
      "amdgpu.dcdebugmask=0x10"
      # maybe this one will?
      "amdgpu.noretry=0"
    ];
  };
  # TODO: really, really, please, I want latest firmware to work...
  nixpkgs.overlays = [
    (final: prev: {
      amd-ucode = prev.amd-ucode.override { inherit (final) linux-firmware; };
      linux-firmware = prev.stdenvNoCC.mkDerivation {
        inherit (prev.linux-firmware) pname version meta src dontFixup installFlags nativeBuildInputs;
        passthru = { inherit (prev.linux-firmware) version; };

        # revert microcode updates which break boot for me
        patches = [
          ./revert-amd-ucode-update-fam17h.patch
          ./revert-amd-ucode-update-fam19h.patch
        ];
        postPatch = ''
          cp ${final.fetchurl {
            name = "microcode_amd_fam17h.bin";
            url = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/amd-ucode/microcode_amd_fam17h.bin?id=b250b32ab1d044953af2dc5e790819a7703b7ee6";
            hash = "sha256-HnKjEb2di7BiKB09JYUjIUuZNCVgXlwRSbjijnuYBcM=";
          }} amd-ucode/microcode_amd_fam17h.bin
          cp ${final.fetchurl {
            name = "microcode_amd_fam19h.bin";
            url = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/amd-ucode/microcode_amd_fam19h.bin?id=0ab353f8d8aa96d68690911cea22ec538f3095c4";
            hash = "sha256-LlA+E4EVQpfjD3/cg6Y52BsCGW/5ZfY0J2UnCUI/3MQ";
          }} amd-ucode/microcode_amd_fam19h.bin
        '';
      };
    })
  ];
  specialisation.no_patches.configuration = {
    nixpkgs.overlays = [
      (final: prev: {
        amd-ucode = prev.amd-ucode.override { inherit (final) linux-firmware; };
        linux-firmware = prev.stdenvNoCC.mkDerivation {
          inherit (prev.linux-firmware) pname version meta src dontFixup installFlags nativeBuildInputs;
          passthru = { inherit (prev.linux-firmware) version; };
          patches = [ ];
          postPatch = "";
        };
      })
    ];
  };
}
