{ config, lib, pkgs, nixpkgs, ... }:
let
  efiPart = "/dev/disk/by-uuid/D77D-8CE0";

  encPart = "/dev/disk/by-uuid/ce6ccdf0-7b6a-43ae-bfdf-10009a55041a";
  cryptrootUuid = "f4edc0df-b50b-42f6-94ed-1c8f88d6cdbb";
  cryptroot = "/dev/disk/by-uuid/${cryptrootUuid}";

  dataPart = "/dev/disk/by-uuid/f1447692-fa7c-4bd6-9cb5-e44c13fddfe3";
  datarootUuid = "fa754b1e-ac83-4851-bf16-88efcd40b657";
  dataroot = "/dev/disk/by-uuid/${datarootUuid}";
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
    ];
    cleanTmpDir = true;
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
  };
  # specialisation = let
  #   zenKernels = pkgs.callPackage "${nixpkgs}/pkgs/os-specific/linux/kernel/zen-kernels.nix";
  #   zenKernel = (version: sha256: (zenKernels {
  #     kernelPatches = [
  #       pkgs.linuxKernel.kernelPatches.bridge_stp_helper
  #       pkgs.linuxKernel.kernelPatches.request_key_helper
  #     ];
  #     argsOverride = {
  #       src = pkgs.fetchFromGitHub {
  #         owner = "zen-kernel";
  #         repo = "zen-kernel";
  #         rev = "v${version}-zen1";
  #         inherit sha256;
  #       };
  #       inherit version;
  #       modDirVersion = lib.versions.pad 3 "${version}-zen1";
  #     };
  #   }).zen);
  # in {
  #   zen619.configuration.boot.kernelPackages = pkgs.linuxPackagesFor (zenKernel "6.1.9" "0fsmcjsawxr32fxhpp6sgwfwwj8kqymy0rc6vh4qli42fqmwdjgv");
  # };
  nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "steam-original";
  hardware = {
    steam-hardware.enable = true;
    video.hidpi.enable = true;
    enableRedistributableFirmware = true;
    opengl.driSupport32Bit = true;
  };

  services.tlp.settings = {
    USB_DENYLIST = "0bda:8156";
    USB_EXCLUDE_PHONE = 1;
    START_CHARGE_THRESH_BAT0 = 75;
    STOP_CHARGE_THRESH_BAT0 = 80;
  };

  # see common/vfio.nix
  vfio.enable = true;
  vfio.pciIDs = [ "1002:73df" "1002:ab28" ];
  vfio.libvirtdGroup = [ "user" ];
  vfio.lookingGlass.ivshmem = [{ owner = "user"; }];

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

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      # nixos files
      "/etc/nixos"
      "/var/lib/nixos"

      # mullvad vpn
      "/etc/mullvad-vpn"
      "/var/cache/mullvad-vpn"

      # as weird as it sounds, I won't use tmpfs for /tmp in case I'll have to put files over 2GB there
      "/tmp"

      # qemu/libvirt
      "/var/cache/libvirt"
      "/var/lib/libvirt"
      "/var/lib/swtpm-localca"

      # stored network info
      "/var/lib/iwd"
      "/var/db/dhcpcd"

      # persist this since everything here is cleaned up by systemd-tmpfiles over time anyway
      # ...or so I'd like to believe
      "/var/lib/systemd"

      "/var/db/sudo/lectured"
      "/var/log"
    ];
    files = [
      # hardware-related
      "/etc/adjtime"
      "/etc/machine-id"
    ];
  };

  swapDevices = [ { device = "/swap/swapfile"; } ];

  services.ratbagd.enable = true;

  ### SECTION 2: SYSTEM CONFIG/ENVIRONMENT ###
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  i18n.supportedLocales = lib.mkDefault [ "en_US.UTF-8/UTF-8" ];
  networking.useDHCP = true;
  # networking.firewall.enable = false;
  # KDE connect: 1714-1764
  networking.firewall.allowedTCPPorts = [ 27015 25565 7777 ] ++ (builtins.genList (x: 1714 + x) (1764 - 1714 + 1));
  networking.firewall.allowedUDPPorts = (builtins.genList (x: 1714 + x) (1764 - 1714 + 1));
  # networking.hostName = "nixmsi";
  networking.wireless.iwd.enable = true;
  #networking.networkmanager.enable = true;

  services.mullvad-vpn.enable = true;
  services.mullvad-vpn.package = pkgs.mullvad-vpn;

  services.xserver = {
    enable = true;
    libinput.enable = true;
    desktopManager.xterm.enable = false;
    # I couldn't get lightdm to start sway, so let's just do this
    displayManager.startx.enable = true;
    windowManager.i3.enable = true;
  };
  programs.sway.enable = true;
  programs.firejail.enable = true;
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    man-pages man-pages-posix
  ];
  services.dbus.enable = true;
  security.polkit.enable = true;
  services.printing.enable = true;
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
      # 96 is mostly fine but has just a little xruns
      quantum = 128;
      rate = 48000;
    };
  };

  # environment.pathsToLink = [ "/share/zsh" "/share/fish" ];
  programs.fish = {
    enable = true;
  };
  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
  };

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

  documentation.dev.enable = true;

  ### RANDOM PATCHES ###

  # I've had some weird issues with the entire system breaking after
  # suspend because of /dev/shm getting nuked, maybe this'll help
  services.logind.extraConfig = ''
    RemoveIPC=no
  '';

  # why is this not part of base NixOS?
  systemd.tmpfiles.rules = [ "d /var/lib/systemd/pstore 0755 root root 14d" ];

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
    lib.mkOptionDefault "${pkgs.system76-scheduler}/etc/system76-scheduler/assignments.ron";
  environment.etc."system76-scheduler/config.ron".source =
    lib.mkOptionDefault "${pkgs.system76-scheduler}/etc/system76-scheduler/config.ron";
  environment.etc."system76-scheduler/exceptions.ron".source =
    lib.mkOptionDefault "${pkgs.system76-scheduler}/etc/system76-scheduler/exceptions.ron";

  # I can't enable early KMS with VFIO, so this will have to do
  # (amdgpu resets the font upon being loaded)
  systemd.services."systemd-vconsole-setup2" = {
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-vconsole-setup";
    };
    wantedBy = ["graphical.target"];
    wants = ["multi-user.target"];
    after = ["multi-user.target"];
  };

  # autologin once after boot

  # --skip-login means directly call login instead of first asking for username
  # (normally login asks for username too, but getty prefers to do it by itself for whatever reason)
  services.getty.extraArgs = ["--skip-login"];
  services.getty.loginProgram = with pkgs; writeScript "login-once" ''
    #! ${bash}/bin/bash
    LOCKFILE=/tmp/login-once.lock
    if [ -f $LOCKFILE ]
    then
      exec ${shadow}/bin/login $@
    else
      ${coreutils}/bin/touch $LOCKFILE
      exec ${shadow}/bin/login -f user
    fi
  '';

  # overlays
  nixpkgs.overlays = [(self: super: with lib; with pkgs; {
    system76-scheduler = rustPlatform.buildRustPackage {
      pname = "system76-scheduler";
      version = "unstable-2022-10-05";
      src = fetchFromGitHub {
        owner = "pop-os";
        repo = "system76-scheduler";
        rev = "25a45add4300eab47ceb332b4ec07e1e74e4baaf";
        sha256 = "sha256-eB1Qm+ITlLM51nn7GG42bydO1SQ4ZKM0wgRl8q522vw=";
      };
      cargoPatches = [(pkgs.writeText "system76-scheduler-cargo.patch" ''
        diff --git i/daemon/Cargo.toml w/daemon/Cargo.toml
        index 0397788..fbd6202 100644
        --- i/daemon/Cargo.toml
        +++ w/daemon/Cargo.toml
        @@ -33,7 +33,7 @@ clap = { version = "3.1.18", features = ["cargo"] }
         # Necessary for deserialization of untagged enums in assignments.
         [dependencies.ron]
         git = "https://github.com/MomoLangenstein/ron"
        -branch = "253-untagged-enums"
        +rev = "a9c5444d74677716f4a8a00504fb1bedbde55156"

         [dependencies.tracing-subscriber]
         version = "0.3.11"
        diff --git i/Cargo.lock w/Cargo.lock
        index a782756..fe56c1f 100644
        --- i/Cargo.lock
        +++ w/Cargo.lock
        @@ -788,7 +788,7 @@ dependencies = [
         [[package]]
         name = "ron"
         version = "0.7.0"
        -source = "git+https://github.com/MomoLangenstein/ron?branch=253-untagged-enums#a9c5444d74677716f4a8a00504fb1bedbde55156"
        +source = "git+https://github.com/MomoLangenstein/ron?rev=a9c5444d74677716f4a8a00504fb1bedbde55156#a9c5444d74677716f4a8a00504fb1bedbde55156"
         dependencies = [
          "base64",
          "bitflags",
      '')];
      cargoSha256 = "sha256-EzvJEJlJzCzNEJLCE3U167LkaQHzGthPhIJ6fp0aGk8=";
      nativeBuildInputs = [ pkg-config ];
      buildInputs = [ dbus ];
      EXECSNOOP_PATH = "${bcc}/bin/execsnoop";
      postInstall = ''
        install -D -m 0644 data/com.system76.Scheduler.conf $out/etc/dbus-1/system.d/com.system76.Scheduler.conf
        mkdir -p $out/etc/system76-scheduler
        install -D -m 0644 data/*.ron $out/etc/system76-scheduler/
      '';

      meta = {
        description = "System76 Scheduler";
        homepage = "https://github.com/pop-os/system76-scheduler";
        license = licenses.mpl20;
        platforms = [ "i686-linux" "x86_64-linux" ];
      };
    };
  })];
}

