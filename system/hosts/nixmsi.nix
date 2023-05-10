{ lib, pkgs, ... }:
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
      availableKernelModules = [ "nvme" "xhci_pci" ];
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
      "fbcon=font:TER16x32"
      "consoleblank=60"
      # disable PSR to *hopefully* avoid random hangs
      # this one didnt help
      "amdgpu.dcdebugmask=0x10"
      # maybe this one will?
      "amdgpu.noretry=0"
    ];
    loader = {
      grub = {
        enable = true;
        enableCryptodisk = true;
        efiSupport = true;
        # nodev = disable bios support 
        device = "nodev";
        gfxmodeEfi = "1920x1080";
        gfxmodeBios = "1920x1080";
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
    enableRedistributableFirmware = true;
    opengl.driSupport32Bit = true;
    # needed for sway WLR_RENDERER=vulkan
    opengl.extraPackages = with pkgs; [ vulkan-validation-layers ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  services.tlp.enable = true;
  services.tlp.settings = {
    USB_EXCLUDE_PHONE = 1;
    START_CHARGE_THRESH_BAT0 = 75;
    STOP_CHARGE_THRESH_BAT0 = 80;
    # fix for my realtek usb ethernet adapter
    USB_DENYLIST = "0bda:8156";
  };

  # see modules/vfio.nix
  vfio.enable = true;
  vfio.pciIDs = [ "1002:73df" "1002:ab28" ];
  vfio.libvirtdGroup = [ "user" ];
  
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
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  i18n.supportedLocales = lib.mkDefault [
    "C.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
    "en_DK.UTF-8/UTF-8"
  ];
  # ISO-8601
  i18n.extraLocaleSettings.LC_TIME = "en_DK.UTF-8";

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
  #networking.networkmanager.enable = true;

  services.ratbagd.enable = true;

  services.mullvad-vpn.enable = true;
  services.mullvad-vpn.package = pkgs.mullvad-vpn;

  # System76 scheduler (not actually a scheduler, just a renice daemon) for improved responsiveness
  services.dbus.packages = [ pkgs.system76-scheduler ];
  systemd.services."system76-scheduler" = {
    description = "Automatically configure CPU scheduler for responsiveness on AC";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "dbus";
      BusName= "com.system76.Scheduler";
      ExecStart = "${pkgs.system76-scheduler}/bin/system76-scheduler daemon";
      ExecReload = "${pkgs.system76-scheduler}/bin/system76-scheduler daemon reload";
    };
  };
  environment.etc."system76-scheduler/assignments.ron".source =
    "${pkgs.system76-scheduler}/etc/system76-scheduler/assignments.ron";
  environment.etc."system76-scheduler/config.ron".source =
    "${pkgs.system76-scheduler}/etc/system76-scheduler/config.ron";
  environment.etc."system76-scheduler/exceptions.ron".source =
    "${pkgs.system76-scheduler}/etc/system76-scheduler/exceptions.ron";

  # i wanted to be able to use both x and wayland... but honestly wayland is enough for me
  services.xserver.libinput.enable = true;
  /*
  services.xserver = {
    enable = true;
    libinput.enable = true;
    desktopManager.xterm.enable = false;
    # I couldn't get lightdm to start sway, so let's just do this
    displayManager.startx.enable = true;
    windowManager.i3.enable = true;
  };
  */

  programs.sway.enable = true;
  programs.firejail.enable = true;
  # doesn't work:
  # programs.wireshark.enable = true;
  # users.groups.wireshark.members = [ "user "];
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    man-pages man-pages-posix
  ];
  services.dbus.enable = true;
  # I don't remember whether I really need this...
  security.polkit.enable = true;
  services.printing.enable = true;

  # pipewire:
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    # from nix-gaming
    lowLatency = {
      enable = true;
      # 96 is mostly fine but has some xruns
      # 128 has xruns every now and then too, but is overall fine
      quantum = 128;
      rate = 48000;
    };
  };

  # environment.pathsToLink = [ "/share/zsh" "/share/fish" ];
  programs.fish = {
    enable = true;
  };
  /*programs.zsh = {
    enable = true;
    enableBashCompletion = true;
  };*/

  programs.fuse.userAllowOther = true;

  programs.ccache.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
  };

  users.mutableUsers = false;
  users.users.user = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    # initialHashedPassword = ...set in private.nix;
  };
  # users.users.root.initialHashedPassword = ...set in private.nix;
  nix = {
    settings = {
      allowed-users = [ "user" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  systemd.services.nix-daemon.serviceConfig.LimitSTACKSoft = "infinity";

  documentation.dev.enable = true;

  # autologin once after boot
  # --skip-login means directly call login instead of first asking for username
  # (normally login asks for username too, but getty prefers to do it by itself for whatever reason)
  services.getty.extraArgs = [ "--skip-login" ];
  services.getty.loginProgram = let
    lockfile = "/tmp/login-once.lock";
  in with pkgs; writeShellScript "login-once" ''
    if [ -f '${lockfile}' ]; then
      exec ${shadow}/bin/login $@
    else
      ${coreutils}/bin/touch '${lockfile}'
      exec ${shadow}/bin/login -f user
    fi
  '';
}

