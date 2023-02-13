{ config, lib, pkgs, ... }:
{
  options.vfio = with lib; mkOption {
    type = types.submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable AMD GPU passthrough config (no intel/nvidia support since I can't test it)";
        };
        libvirtdGroup = mkOption {
          type = with types; listOf str;
          default = ["user"];
          description = "Users to add to libvirtd group";
        };
        intelCpu = mkOption {
          type = types.bool;
          default = false;
          description = "Whether the CPU is Intel (untested)";
        };
        passGpuAtBoot = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to pass the GPU at boot (can be more stable). If false, a bootloader entry to do it will still be available.";
        };
        pciIDs = mkOption {
          type = with types; listOf str;
          default = [];
          description = "PCI passthrough IDs";
        };
        lookingGlass = mkOption {
          type = types.submodule {
            options = {
              enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Looking Glass integration";
              };
              ivshmem = mkOption {
                type = with types; listOf (submodule {
                  options = {
                    size = mkOption {
                      type = types.int;
                      default = 32;
                      description = "IVSHMEM size in MB: https://looking-glass.io/docs/B6/install/#determining-memory";
                    };
                    owner = mkOption {
                      type = types.str;
                      description = "IVSHMEM device owner";
                    };
                  };
                });
                default = [];
                example = [{ size = 32; owner = "user"; }];
                description = "IVSHMEM/kvmfr config (multiple devices can be created: /dev/kvmfr0, /dev/kvmfr1, and so on)";
              };
            };
          };
          default = {};
          description = "Looking glass config";
        };
      };
    };
    default = {};
    description = "VFIO settings";
  };
  config = lib.mkIf config.vfio.enable
  (let
    cfg = config.vfio;
    gpuIDs = lib.concatStringsSep "," cfg.pciIDs;
    enableIvshmem = config.vfio.lookingGlass.enable && (builtins.length config.vfio.lookingGlass.ivshmem) > 0;
  in {
    specialisation.vfio.configuration = lib.mkIf (!cfg.passGpuAtBoot) {
      boot.kernelParams = [ "early_load_vfio" ];
    };
    boot = {
      initrd.postDeviceCommands = lib.mkIf (!cfg.passGpuAtBoot) ''
        for o in $(cat /proc/cmdline); do
          case $o in
            early_load_vfio)
              loadVfio=1
              ;;
          esac
        done
        if [[ -n "$loadVfio" ]]; then
          modprobe vfio
          modprobe vfio_iommu_type1
          modprobe vfio_pci
        fi
      '';
      initrd.kernelModules = [
        (if cfg.intelCpu then "kvm-intel" else "kvm-amd")
      ] ++ (if cfg.passGpuAtBoot then [
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
        "vfio_virqfd"
      ] else []);
      initrd.availableKernelModules = lib.mkIf (!cfg.passGpuAtBoot) [
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
        "vfio_virqfd"
      ];
      extraModulePackages =
        with config.boot.kernelPackages;
          lib.mkIf enableIvshmem [ kvmfr ];
      extraModprobeConfig = let ivshmemConfig = if enableIvshmem then ''
          options kvmfr static_size_mb=${lib.concatStringsSep "," (map (x: toString x.size) cfg.lookingGlass.ivshmem)}
        '' else ""; in ''
          options vfio-pci ids=${gpuIDs} disable_idle_d3=1
          options kvm ignore_msrs=1
          ${ivshmemConfig}
        '';
      kernelParams = [
        (if cfg.intelCpu then "intel_iommu=on" else "amd_iommu=on")
        "iommu=pt"
      ];
      kernelModules = [
        "vhost-net"
      ] ++ (if cfg.passGpuAtBoot then [] else [ "vfio_virqfd" ])
        ++ (if enableIvshmem then [ "kvmfr" ] else []);
    };
    services.udev.extraRules = lib.mkIf enableIvshmem
      (lib.concatStringsSep
        "\n"
        (lib.imap0
          (i: ivshmem: ''
            SUBSYSTEM=="kvmfr", KERNEL=="kvmfr${toString i}", OWNER="${ivshmem.owner}", GROUP="kvm", MODE="0660"
          '')
          cfg.lookingGlass.ivshmem));
    # disable early KMS so GPU can be properly unbound
    hardware.amdgpu.loadInInitrd = false;
    hardware.opengl.enable = true;
    # needed for virt-manager
    programs.dconf.enable = true;
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
      qemu = {
        ovmf.enable = true;
        # Full is needed for TPM and secure boot emulation
        ovmf.packages = [ pkgs.OVMFFull.fd ];
        # TPM emulation
        swtpm.enable = true;
        verbatimConfig = ''
          cgroup_device_acl = [
            "/dev/kvmfr0",
            "/dev/vfio/vfio", "/dev/vfio/11", "/dev/vfio/12",
            "/dev/null", "/dev/full", "/dev/zero",
            "/dev/random", "/dev/urandom",
            "/dev/ptmx", "/dev/kvm"
          ]
        '';
        # might disable this later
        runAsRoot = true;
      };
    };
    virtualisation.spiceUSBRedirection.enable = true;
    users.groups.libvirtd.members = [ "root" ] ++ cfg.libvirtdGroup;
  });
}
