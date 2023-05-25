{ lib
, pkgs
, config
, ... }:

let
  efiPart = "/dev/disk/by-uuid/D77D-8CE0";

  encPart = "/dev/disk/by-uuid/ce6ccdf0-7b6a-43ae-bfdf-10009a55041a";
  cryptrootUuid = "f4edc0df-b50b-42f6-94ed-1c8f88d6cdbb";
  cryptroot = "/dev/disk/by-uuid/${cryptrootUuid}";

  dataPart = "/dev/disk/by-uuid/f1447692-fa7c-4bd6-9cb5-e44c13fddfe3";
  datarootUuid = "fa754b1e-ac83-4851-bf16-88efcd40b657";
  dataroot = "/dev/disk/by-uuid/${datarootUuid}";
  /*
  # for old kernel versions
  zenKernels = pkgs.callPackage "${nixpkgs}/pkgs/os-specific/linux/kernel/zen-kernels.nix";
  zenKernel = (version: sha256: (zenKernels {
    kernelPatches = [
      pkgs.linuxKernel.kernelPatches.bridge_stp_helper
      pkgs.linuxKernel.kernelPatches.request_key_helper
    ];
    argsOverride = {
      src = pkgs.fetchFromGitHub {
        owner = "zen-kernel";
        repo = "zen-kernel";
        rev = "v${version}-zen1";
        inherit sha256;
      };
      inherit version;
      modDirVersion = lib.versions.pad 3 "${version}-zen1";
    };
  }).zen);
  zenKernelPackages = version: sha256: pkgs.linuxPackagesFor (zenKernel version sha256);
  */
in {
  system.stateVersion = "22.11";

  ### SECTION 1: HARDWARE/BOOT PARAMETERS ###

  boot = {
    initrd = {
      # insert crypto_keyfile into initrd so that grub can tell the kernel the
      # encryption key once I unlock the /boot partition
      secrets."/crypto_keyfile.bin" = "/boot/initrd/crypto_keyfile.bin";
      luks.devices."cryptroot" = {
        device = encPart;
        # idk whether this is needed but it works
        preLVM = true;
        # see https://asalor.blogspot.de/2011/08/trim-dm-crypt-problems.html before enabling
        allowDiscards = true;
        # improve SSD performance
        bypassWorkqueues = true;
        keyFile = "/crypto_keyfile.bin";
      };
      luks.devices."dataroot" = {
        device = dataPart;
        preLVM = true;
        allowDiscards = true;
        bypassWorkqueues = true;
        keyFile = "/crypto_keyfile.bin";
      };
    };
    resumeDevice = cryptroot;
    kernelParams = [
      "resume=/@swap/swapfile"
      # resume_offset = $(btrfs inspect-internal map-swapfile -r path/to/swapfile)
      "resume_offset=533760"
    ];
    loader = {
      grub = {
        enable = true;
        enableCryptodisk = true;
        efiSupport = true;
        # nodev = disable bios support 
        device = "nodev";
      };
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot/efi";
    };
    kernel.sysctl = {
      "vm.dirty_ratio" = 4;
      "vm.dirty_background_ratio" = 2;
      "vm.swappiness" = 40;
    };
    kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;
    /*kernelPackages = zenKernelPackages "6.1.9" "0fsmcjsawxr32fxhpp6sgwfwwj8kqymy0rc6vh4qli42fqmwdjgv";*/
  };

  # for testing different zen kernel versions:
  # specialisation = {
  #   zen619.configuration.boot.kernelPackages = zenKernelPackages "6.1.9" "0fsmcjsawxr32fxhpp6sgwfwwj8kqymy0rc6vh4qli42fqmwdjgv";
  # };

  nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "steam-original";
  hardware = {
    steam-hardware.enable = true;
    opengl.driSupport32Bit = true;
    # needed for sway WLR_RENDERER=vulkan
    opengl.extraPackages = with pkgs; [ vulkan-validation-layers ];
  };

  # services.openssh.enable = true;

  services.tlp.enable = true;
  # fix for my realtek usb ethernet adapter
  services.tlp.settings.USB_DENYLIST = "0bda:8156";

  # see modules/vfio.nix
  vfio.enable = true;
  vfio.libvirtdGroup = [ config.common.mainUsername ];
  
  # because libvirtd's nat is broken for some reason...
  networking.nat = {
    enable = true;
    internalInterfaces = [ "virbr0" ];
    externalInterface = "enp7s0f4u1c2";
  };

  fileSystems = let
    device = cryptroot;
    fsType = "btrfs";
    # max compression! my cpu is pretty good anyway
    compress = "compress=zstd:15";
    discard = "discard=async";
    neededForBoot = true;
  in {
    # mount root on tmpfs
    "/" =     { device = "none"; fsType = "tmpfs"; inherit neededForBoot;
                options = [ "defaults" "size=2G" "mode=755" ]; };
    "/persist" =
              { inherit device fsType neededForBoot;
                options = [ discard compress "subvol=@" ]; };
    "/nix" =  { inherit device fsType neededForBoot;
                options = [ discard compress "subvol=@nix" "noatime" ]; };
    "/swap" = { inherit device fsType neededForBoot;
                options = [ discard "subvol=@swap" "noatime" ]; };
    "/home" = { inherit device fsType;
                options = [ discard compress "subvol=@home" ]; };
    # why am I even bothering with creating this subvolume every time if I don't use snapshots anyway?
    "/.snapshots" =
              { inherit device fsType;
                options = [ discard compress "subvol=@snapshots" ]; };
    "/boot" = { inherit device fsType neededForBoot;
                options = [ discard compress "subvol=@boot" ]; };
    "/boot/efi" =
              { device = efiPart; fsType = "vfat"; inherit neededForBoot; };
    "/data" =
              { device = dataroot; fsType = "btrfs";
                options = [ discard compress ]; };
  };

  impermanence = {
    enable = true;
    path = /persist;
  };

  swapDevices = [ { device = "/swap/swapfile"; } ];

  # dedupe
  services.beesd = {
    # i have a lot of ram :tonystark:
    filesystems.cryptroot = {
      spec = "UUID=${cryptrootUuid}";
      hashTableSizeMB = 128;
      extraOptions = [ "--loadavg-target" "8.0" ];
    };
    filesystems.dataroot = {
      spec = "UUID=${datarootUuid}";
      hashTableSizeMB = 256;
      extraOptions = [ "--loadavg-target" "8.0" ];
    };
  };

  ### SECTION 2: SYSTEM CONFIG/ENVIRONMENT ###
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";

  networking.useDHCP = true;
  # networking.firewall.enable = false;
  networking.firewall.allowedTCPPorts = [
    27015
    25565
    7777
  ]
  # kde connect
  ++ (lib.range 1714 1764);
  networking.firewall.allowedUDPPorts = lib.range 1714 1764;

  networking.wireless.iwd.enable = true;

  services.ratbagd.enable = true;

  services.mullvad-vpn.enable = true;
  services.mullvad-vpn.package = pkgs.mullvad-vpn;

  # System76 scheduler (not actually a scheduler, just a renice daemon) for improved responsiveness
  services.system76-scheduler.enable = true;

  common.workstation = true;
  common.gettyAutologin = true;
  # programs.firejail.enable = true;
  # doesn't work:
  # programs.wireshark.enable = true;
  # users.groups.wireshark.members = [ config.common.mainUsername"];
  services.printing.enable = true;
  # from nix-gaming
  services.pipewire.lowLatency = {
    enable = true;
    # 96 is mostly fine but has some xruns
    # 128 has xruns every now and then too, but is overall fine
    quantum = 128;
    rate = 48000;
  };

  programs.ccache.enable = true;
}

