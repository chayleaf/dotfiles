{ config, lib, pkgs, ... }:
let
  cryptroot = "/dev/disk/by-uuid/f4edc0df-b50b-42f6-94ed-1c8f88d6cdbb";
  encPart = "/dev/disk/by-uuid/ce6ccdf0-7b6a-43ae-bfdf-10009a55041a";
  efiPart = "/dev/disk/by-uuid/D77D-8CE0";
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
    kernelPackages = pkgs.linuxPackages_zen;
  };
  nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "steam-original";
  hardware = {
    steam-hardware.enable = true;
    video.hidpi.enable = true;
    enableRedistributableFirmware = true;
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
  in {
    "/" =     { inherit device fsType;
                options = [ discard compress "subvol=@" ]; };
    "/nix" =  { inherit device fsType;
                options = [ discard compress "subvol=@nix" "noatime" ]; };
    "/swap" = { inherit device fsType;
                options = [ discard "subvol=@swap" "noatime" ]; };
    "/home" = { inherit device fsType;
                options = [ discard compress "subvol=@home" ]; };
    "/.snapshots" =
              { inherit device fsType;
                options = [ discard compress "subvol=@snapshots" ]; };
    "/boot/efi" =
              { device = efiPart;
                fsType = "vfat"; };
  };

  swapDevices = [ { device = "/swap/swapfile"; } ];

  ### SECTION 2: SYSTEM CONFIG/ENVIRONMENT ###
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  i18n.supportedLocales = lib.mkDefault [ "en_US.UTF-8/UTF-8" ];
  networking.useDHCP = true;
  # networking.firewall.enable = false;
  networking.firewall.allowedTCPPorts = [ 27015 25565 7777 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
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
  };

  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
  };
  nix = {
    settings.allowed-users = [ "user" ];
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  ### RANDOM PATCHES ###

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

