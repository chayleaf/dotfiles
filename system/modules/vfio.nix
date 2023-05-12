{ config
, lib
, pkgs
, ... }:

let
  cfg = config.vfio;
in {
  options.vfio = with lib; mkOption {
    type = types.submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable GPU passthrough config (probably no intel/nvidia support since I can't test it)";
        };
        libvirtdGroup = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = "Users to add to libvirtd group";
        };
        intelCpu = mkOption {
          type = types.bool;
          default = false;
          description = "Whether the CPU is Intel (untested)";
        };
        nvidiaGpu = mkOption {
          type = types.bool;
          default = false;
          description = "Whether the GPU is Nvidia (disables AMD-specific workarounds)";
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
          default = { };
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
                default = if builtins.length cfg.libvirtdGroup == 1 then [
                  { owner = builtins.head cfg.libvirtdGroup; }
                ] else [ ];
                example = [ { size = 32; owner = "user"; } ];
                description = "IVSHMEM/kvmfr config (multiple devices can be created: /dev/kvmfr0, /dev/kvmfr1, and so on)";
              };
            };
          };
          description = "Looking glass config";
        };
      };
    };
    description = "VFIO settings";
    default = { };
  };
  # compatibility so this module loads on non-amd hardware
  config = let
    enableIvshmem = cfg.lookingGlass.enable && (builtins.length cfg.lookingGlass.ivshmem) > 0;
  in lib.mkIf cfg.enable {
    # add a custom kernel param for early loading vfio drivers
    # because if we change boot.initrd options in a specialization, two initrds will be built
    # and we don't want to build two initrds
    specialisation.vfio.configuration = lib.mkIf (!cfg.passGpuAtBoot) {
      boot.kernelParams = [ "early_load_vfio" ];

      # I can't enable early KMS with VFIO, so this will have to do
      # (amdgpu resets the font upon being loaded)
      systemd.services."systemd-vconsole-setup2" = lib.mkIf (!cfg.nvidiaGpu) {
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-vconsole-setup";
        };
        wantedBy = [ "graphical.target" ];
        wants = [ "multi-user.target" ];
        after = [ "multi-user.target" ];
      };
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
        ${if cfg.nvidiaGpu then "" else ''
        else
          modprobe amdgpu''}
        fi
      '';
      initrd.kernelModules = [
        (if cfg.intelCpu then "kvm-intel" else "kvm-amd")
      ] ++ (if cfg.passGpuAtBoot then [
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
      ] else []);
      initrd.availableKernelModules = lib.mkIf (!cfg.passGpuAtBoot) [
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
      ];
      extraModulePackages =
        with config.boot.kernelPackages;
          lib.mkIf enableIvshmem [ kvmfr ];
      extraModprobeConfig = ''
          options vfio-pci ids=${builtins.concatStringsSep "," cfg.pciIDs} disable_idle_d3=1
          options kvm ignore_msrs=1
          ${if enableIvshmem then ''
          options kvmfr static_size_mb=${builtins.concatStringsSep "," (map (x: toString x.size) cfg.lookingGlass.ivshmem)}''
          else ""}
        '';
      kernelParams = [
        (if cfg.intelCpu then "intel_iommu=on" else "amd_iommu=on")
        "iommu=pt"
      ];
      kernelModules = [
        "vhost-net"
      ] ++ (if enableIvshmem then [ "kvmfr" ] else []);
    };
    services.udev.extraRules = lib.mkIf enableIvshmem
      (builtins.concatStringsSep
        ""
        (lib.imap0
          (i: ivshmem: ''
            SUBSYSTEM=="kvmfr", KERNEL=="kvmfr${toString i}", OWNER="${ivshmem.owner}", GROUP="kvm", MODE="0660"
          '')
          cfg.lookingGlass.ivshmem));
    hardware = {
      opengl.enable = true;
    } // (lib.optionalAttrs (cfg.enable && !(cfg.nvidiaGpu)) {
      # disable early KMS so GPU can be properly unbound
      # can't use mkif because the option may not even exist
      amdgpu.loadInInitrd = false;
    });
    # needed for virt-manager
    programs.dconf.enable = true;
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
      qemu = {
        package = pkgs.qemu_kvm;
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
    environment.systemPackages = with pkgs; [
      virtiofsd
    ];
  };
}
